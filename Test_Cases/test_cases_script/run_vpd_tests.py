#!/usr/bin/env python3
"""Run the CS5322 Project 1 VPD test cases against the Oracle database.

Zero dependencies (stdlib only, Python 3.6+). Drives `sqlplus` as each test user.
Every case runs in its own session and is ROLLED BACK; nothing is ever committed.

  python3 run_vpd_tests.py                 # run all 54 cases
  python3 run_vpd_tests.py --only TC-013,TC-052
  python3 run_vpd_tests.py --list
  python3 run_vpd_tests.py --out results   # where results.json / results.csv go
"""
import argparse
import csv
import json
import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cases import CASES  # noqa: E402

DEFAULT_ORACLE_HOME = "/opt/oracle/product/26ai/dbhomeFree"
# ORA codes that mean "the DB refused this" (a legitimate denial).
DENY_CODES = {942, 1031, 1402, 28115, 41900}
# ORA-28110 = a policy function is INVALID / raised an error: never a legitimate denial.
POLICY_ERR_CODES = {28110, 28112, 28113}


def password_for(user):
    return user.replace("_", "")


def one_line(sql):
    return re.sub(r"\s+", " ", sql.strip().rstrip(";"))


def step_block(idx, step):
    q = "q'~" + one_line(step["sql"]) + "~'"
    err = ("exception when others then dbms_output.put_line('@@STEP|%d|ERR|'||sqlcode||'|'||"
           "replace(replace(substr(sqlerrm,1,200),chr(10),' '),'|','/')); end;" % idx)
    if step["kind"] == "select":
        body = ("declare n number; begin execute immediate 'select count(*) from (' || %s || ')' into n; "
                "dbms_output.put_line('@@STEP|%d|ROWS|'||n); " % (q, idx))
    else:
        body = ("begin execute immediate %s; "
                "dbms_output.put_line('@@STEP|%d|AFF|'||sql%%rowcount); " % (q, idx))
    return body + err + "\n/\n"


def case_script(case, args):
    user = case["user"]
    lines = [
        "set serveroutput on size unlimited",
        "set feedback off heading off pagesize 0 linesize 4000 trimspool on verify off define off echo off",
        "whenever sqlerror continue",
        "connect %s/%s@%s" % (user, password_for(user), args.dsn),
        "prompt @@CONNECTED",
        "select '@@CTX|'||sys_context('HOSPITAL_CTX','APP_ROLE') from dual;",
    ]
    for i, st in enumerate(case["steps"], 1):
        lines.append(step_block(i, st))
    lines += ["rollback;", "exit rollback", ""]
    return "\n".join(lines)


def fixture_script(cases, args):
    lines = [
        "set serveroutput on size unlimited",
        "set feedback off heading off pagesize 0 linesize 4000 trimspool on verify off define off echo off",
        "whenever sqlerror continue",
        "connect %s/%s@%s" % (args.owner, args.owner_pw, args.dsn),
        "prompt @@CONNECTED",
    ]
    for case in cases:
        for j, fx in enumerate(case["fixtures"], 1):
            q = "q'~" + one_line(fx) + "~'"
            lines.append(
                "declare n number; begin execute immediate %s into n; "
                "dbms_output.put_line('@@FIX|%s|%d|'||n); "
                "exception when others then dbms_output.put_line('@@FIX|%s|%d|ERR '||sqlcode); end;\n/"
                % (q, case["id"], j, case["id"], j))
    lines += ["exit", ""]
    return "\n".join(lines)


def run_sqlplus(script, args):
    env = dict(os.environ)
    env.setdefault("ORACLE_HOME", args.oracle_home)
    env["PATH"] = os.path.join(env["ORACLE_HOME"], "bin") + os.pathsep + env.get("PATH", "")
    p = subprocess.run(["sqlplus", "-s", "/nolog"], input=script, universal_newlines=True,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env, timeout=args.timeout)
    return p.stdout


def evaluate(step, res):
    """-> (ok: bool, observed: str)"""
    exp = step["exp"]
    if res is None:
        return False, "no result (step did not run)"
    kind, a, b = res
    if kind == "ERR":
        code = abs(int(a))
        txt = "ORA-%05d" % code
        if code in POLICY_ERR_CODES:
            return False, txt + " POLICY FUNCTION ERROR: " + b
        if code in DENY_CODES:
            return exp in ("NONE", "BLOCKED"), txt + " denied"
        return False, txt + " UNEXPECTED: " + b
    n = int(a)
    if kind == "ROWS":
        obs = "%d rows" % n
        if exp == "ROWS>0":
            return n > 0, obs
        if exp in ("ROWS=0", "NONE"):
            return n == 0, obs
    else:  # AFF
        obs = "%d affected" % n
        if exp == "OK":
            return n >= 1, obs
        if exp == "BLOCKED":
            return n == 0, obs
    return False, obs + " (bad expectation %s)" % exp


def parse_case_output(out, case):
    connected = "@@CONNECTED" in out
    ctx = None
    steps = {}
    for line in out.splitlines():
        if line.startswith("@@CTX|"):
            ctx = line.split("|", 1)[1].strip() or None
        elif line.startswith("@@STEP|"):
            p = line.split("|")
            idx = int(p[1])
            if p[2] == "ERR":
                steps[idx] = ("ERR", p[3], p[4] if len(p) > 4 else "")
            else:
                steps[idx] = (p[2], p[3], "")
    results = []
    for i, st in enumerate(case["steps"], 1):
        ok, obs = evaluate(st, steps.get(i))
        results.append({"n": i, "exp": st["exp"], "ok": ok, "observed": obs, "sql": one_line(st["sql"])})
    return connected, ctx, results


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", help="comma separated case ids, e.g. TC-013,TC-052")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--out", default="results")
    ap.add_argument("--dsn", default="localhost:1521/cs5322")
    ap.add_argument("--owner", default="proj_one")
    ap.add_argument("--owner-pw", default="group8")
    ap.add_argument("--oracle-home", default=DEFAULT_ORACLE_HOME)
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument("-v", "--verbose", action="store_true", help="show every step, not only failures")
    args = ap.parse_args()

    cases = CASES
    if args.only:
        want = {x.strip().upper() for x in args.only.split(",")}
        cases = [c for c in CASES if c["id"] in want]
    if args.list:
        for c in cases:
            print("%s  %-15s %-13s %-8s %s" % (c["id"], c["role"], c["op"], c["type"], c["req"]))
        return 0

    # 1. fixtures (as schema owner)
    fx_out = run_sqlplus(fixture_script(cases, args), args)
    if "@@CONNECTED" not in fx_out:
        print("Could not connect as owner %s:\n%s" % (args.owner, fx_out), file=sys.stderr)
        return 2
    fx = {}
    for line in fx_out.splitlines():
        if line.startswith("@@FIX|"):
            _, cid, j, val = line.split("|", 3)
            fx[(cid, int(j))] = val.strip()

    # 2. cases
    report = []
    t0 = time.time()
    for case in cases:
        out = run_sqlplus(case_script(case, args), args)
        connected, ctx, steps = parse_case_output(out, case)
        fixtures = []
        for j, sql in enumerate(case["fixtures"], 1):
            val = fx.get((case["id"], j), "?")
            fixtures.append({"sql": one_line(sql), "value": val, "ok": val.isdigit() and int(val) >= 1})
        if not connected:
            status = "ERROR"
            reason = "could not connect as %s: %s" % (case["user"], " ".join(out.split())[:160])
        elif any(not f["ok"] for f in fixtures):
            status = "BAD-FIXTURE"
            reason = "seed data missing: " + "; ".join(f["sql"] for f in fixtures if not f["ok"])
        elif all(s["ok"] for s in steps):
            status, reason = "PASS", ""
        else:
            status = "FAIL"
            reason = "; ".join("step %d (%s): expected %s, got %s" % (s["n"], s["sql"][:70], s["exp"], s["observed"])
                               for s in steps if not s["ok"])
        report.append({"id": case["id"], "role": case["role"], "user": case["user"], "op": case["op"],
                       "type": case["type"], "req": case["req"], "status": status, "reason": reason,
                       "sheet": case.get("sheet"), "ctx_role": ctx, "steps": steps,
                       "fixtures": fixtures, "note": case.get("note", "")})
        mark = {"PASS": "PASS", "FAIL": "FAIL", "ERROR": "ERR ", "BAD-FIXTURE": "FIX?"}[status]
        drift = ""
        if case.get("sheet") and case["sheet"] != status:
            drift = "   (sheet said %s)" % case["sheet"]
        print("[%s] %s  %-15s %-8s %s%s" % (mark, case["id"], case["role"], case["type"], case["req"], drift))
        if status != "PASS" or args.verbose:
            for s in steps:
                if args.verbose or not s["ok"]:
                    print("        %s step %d  exp=%-7s got=%-40s %s" %
                          ("ok  " if s["ok"] else "FAIL", s["n"], s["exp"], s["observed"][:40], s["sql"][:90]))
            if status in ("ERROR", "BAD-FIXTURE"):
                print("        " + reason)

    # 3. summary + files
    tot = len(report)
    cnt = {k: sum(1 for r in report if r["status"] == k) for k in ("PASS", "FAIL", "ERROR", "BAD-FIXTURE")}
    print("\n%d cases in %.1fs  PASS=%d FAIL=%d ERROR=%d BAD-FIXTURE=%d" %
          (tot, time.time() - t0, cnt["PASS"], cnt["FAIL"], cnt["ERROR"], cnt["BAD-FIXTURE"]))
    changed = [r for r in report if r["sheet"] and r["sheet"] != r["status"]]
    if changed:
        print("Differs from spreadsheet: " + ", ".join("%s(%s->%s)" % (r["id"], r["sheet"], r["status"]) for r in changed))

    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.out, "results.json"), "w") as f:
        json.dump(report, f, indent=2)
    with open(os.path.join(args.out, "results.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["id", "role", "user", "operation", "type", "requirement", "status", "sheet_status", "reason", "note"])
        for r in report:
            w.writerow([r["id"], r["role"], r["user"], r["op"], r["type"], r["req"], r["status"],
                        r["sheet"] or "", r["reason"], r["note"]])
    print("Wrote %s/results.json and results.csv" % args.out)
    return 0 if cnt["FAIL"] + cnt["ERROR"] + cnt["BAD-FIXTURE"] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())

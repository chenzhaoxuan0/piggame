"""
Pump zone asset production: keeps the Lux3D concurrency slots full (limit 5
in-flight tasks observed 2026-11-12) by looping submit + collect until every
asset in the zone manifest is downloaded or failed.

Usage:
  python scripts/art/zone_pump.py [--zone C0|C2|C3|C4] [--max-seconds 7200]
"""
import argparse
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PRODUCE = ROOT / 'scripts/art/produce_zone_assets.py'
SPECS = {
    'C0': 14, 'C2': 13, 'C3': 13, 'C4': 15,
}


def run(args):
    return subprocess.run([sys.executable, str(PRODUCE), *args], cwd=ROOT,
                          capture_output=True, text=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--zone', choices=list(SPECS), default=None)
    parser.add_argument('--max-seconds', type=int, default=7200)
    args = parser.parse_args()
    deadline = time.time() + args.max_seconds
    round_no = 0
    while time.time() < deadline:
        round_no += 1
        res = run(['collect'] + (['--zone', args.zone] if args.zone else []))
        tail = [l for l in res.stdout.splitlines() if 'RAW asset saved' in l or 'failed' in l.lower()]
        for line in tail:
            print(line, flush=True)
        res = run(['submit'] + (['--zone', args.zone] if args.zone else []))
        submitted = [l for l in res.stdout.splitlines() if 'Submitted ->' in l]
        for line in submitted:
            print(line, flush=True)
        status = run(['status'] + (['--zone', args.zone] if args.zone else []))
        lines = status.stdout.strip().splitlines()
        done = sum(1 for l in lines if 'status=downloaded' in l)
        failed = sum(1 for l in lines if 'status=failed' in l)
        total = SPECS[args.zone] if args.zone else sum(SPECS.values())
        print(f"[round {round_no}] {done}/{total} downloaded, {failed} failed", flush=True)
        if done + failed >= total:
            print("Pump complete.", flush=True)
            return
        time.sleep(20)
    print("Pump timed out; rerun to continue.", flush=True)


if __name__ == '__main__':
    main()

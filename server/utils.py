import os
import sys
import time
import subprocess
import random
from .constants import BLOCKLIST_PATH


def random_ip():
    return f"{random.randint(1,255)}.{random.randint(0,255)}.{random.randint(0,255)}.{random.randint(0,255)}"


def clear_file(path: str) -> None:
    try:
        with open(path, "w") as f:
            f.write("")
    except Exception:
        pass


def nginx_reload() -> None:
    try:
        subprocess.run(["nginx", "-s", "reload"], capture_output=True, timeout=5)
    except Exception:
        pass


def block_ip(ip: str) -> None:
    try:
        with open(BLOCKLIST_PATH, "a") as f:
            f.write(f"deny {ip};\n")
        nginx_reload()
    except Exception:
        pass


def is_ip_blocked(ip: str) -> bool:
    try:
        with open(BLOCKLIST_PATH, "r") as f:
            return f"deny {ip};" in f.read()
    except Exception:
        return False


def restart_attacker(scenario: str, scenarios: list) -> None:
    for s in scenarios:
        try:
            subprocess.run(["supervisorctl", "stop", f"{s}_attack"], capture_output=True, timeout=5)
        except Exception:
            pass
    try:
        subprocess.run(["supervisorctl", "start", f"{scenario}_attack"], capture_output=True, timeout=5)
    except Exception:
        pass


def kill_process(pid: int) -> bool:
    try:
        proc_cmdline = f"/proc/{pid}/cmdline"
        proc_status  = f"/proc/{pid}/status"

        if not os.path.exists(proc_status):
            print(f"[KILL] pid={pid} does not exist", file=sys.stderr, flush=True)
            return False

        try:
            with open(proc_cmdline, "rb") as f:
                cmdline = f.read().replace(b"\x00", b" ").decode(errors="replace").strip()
            print(f"[KILL] pid={pid} cmdline={cmdline!r}", file=sys.stderr, flush=True)
        except OSError:
            cmdline = "<unknown>"
            print(f"[KILL] pid={pid} cmdline unreadable", file=sys.stderr, flush=True)

        import signal
        try:
            os.kill(pid, signal.SIGKILL)
            print(f"[KILL] sent SIGKILL to {pid}", file=sys.stderr, flush=True)
        except ProcessLookupError:
            print(f"[KILL] pid={pid} already gone", file=sys.stderr, flush=True)

        r = subprocess.run(
            ["supervisorctl", "stop", "hard_attack"],
            capture_output=True, text=True, timeout=5
        )
        print(f"[KILL] supervisorctl stop: rc={r.returncode} out={r.stdout.strip()!r}", file=sys.stderr, flush=True)

        time.sleep(1.0)

        if not os.path.exists(proc_status):
            print(f"[KILL] result=True (proc gone)", file=sys.stderr, flush=True)
            return True

        try:
            with open(proc_status) as f:
                state_line = next((l for l in f if l.startswith("State:")), "")
            print(f"[KILL] state_after={state_line.strip()!r}", file=sys.stderr, flush=True)
            return "Z" in state_line
        except OSError:
            return True

    except Exception as e:
        print(f"[KILL] exception: {e}", file=sys.stderr, flush=True)
        return False


def read_logs(file_path: str) -> str:
    try:
        result = subprocess.run(
            ["tail", "-n", "50", file_path],
            capture_output=True, text=True, timeout=5
        )
        return result.stdout or "(log empty - attacker may not have fired yet)"
    except Exception:
        return "(could not read log file)"


def check_hard_attack_process() -> bool:
    try:
        result = subprocess.run(["supervisorctl", "status", "hard_attack"], capture_output=True, text=True, timeout=5)
        return "RUNNING" in result.stdout
    except Exception:
        return False

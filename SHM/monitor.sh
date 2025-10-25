'#!/usr/bin/env bash
set -euo pipefail

# ====== Config (can be overridden via env) ======
: "${CPU_WARN:=85}"
: "${RAM_WARN:=90}"
: "${NET_WARN_Mbps:=200}"
: "${SAMPLE_SECONDS:=2}"
: "${LOG_DIR:=/var/log/syshealth}"
: "${EMAIL_TO:=}"
: "${SMTP_HOST:=}"
: "${SMTP_PORT:=587}"
: "${SMTP_USER:=}"
: "${SMTP_PASS:=}"
: "${SMTP_STARTTLS:=1}"

# ====== Prep dirs ======
if [[ "$LOG_DIR" != /* ]]; then
  echo "LOG_DIR must be an absolute path. Got: $LOG_DIR" >&2
  exit 1
fi

sudo mkdir -p "$LOG_DIR" >/dev/null 2>&1 || mkdir -p "$LOG_DIR"
sudo chown "$(id -u)":"$(id -g)" "$LOG_DIR" >/dev/null 2>&1 || true

APP_DIR="${HOME}/.local/share/syshealth"
PYENV_DIR="${APP_DIR}/venv"
mkdir -p "$APP_DIR"

# ====== Write monitor.py (heredoc) ======
PY="${APP_DIR}/monitor.py"
cat > "$PY" <<'PYCODE'
#!/usr/bin/env python3
import os, time, json, csv, shutil, subprocess, socket
from datetime import datetime
from pathlib import Path

try:
    import psutil
except ImportError:
    print("psutil missing. Run monitor.sh to install it.", flush=True)
    raise

CPU_WARN = int(os.getenv("CPU_WARN", "85"))
RAM_WARN = int(os.getenv("RAM_WARN", "90"))
NET_WARN_Mbps = float(os.getenv("NET_WARN_Mbps", "200"))
SAMPLE_SECONDS = float(os.getenv("SAMPLE_SECONDS", "2"))
LOG_DIR = Path(os.getenv("LOG_DIR", "/var/log/syshealth"))
EMAIL_TO = os.getenv("EMAIL_TO", "").strip()
SMTP_HOST = os.getenv("SMTP_HOST", "").strip()
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "").strip()
SMTP_PASS = os.getenv("SMTP_PASS", "").strip()
SMTP_STARTTLS = os.getenv("SMTP_STARTTLS", "1").strip() == "1"

CSV_PATH = LOG_DIR / "metrics.csv"
JSONL_PATH = LOG_DIR / "metrics.jsonl"
HOST = socket.gethostname()

def now():
    return datetime.utcnow().replace(microsecond=0).isoformat() + "Z"

def bytes_to_mbps(byte_delta, seconds):
    return (byte_delta * 8.0 / 1_000_000.0) / seconds

def collect():
    import psutil
    cpu = psutil.cpu_percent(interval=1)
    mem = psutil.virtual_memory().percent
    n1 = psutil.net_io_counters()
    time.sleep(max(0.0, SAMPLE_SECONDS))
    n2 = psutil.net_io_counters()
    rx_delta = n2.bytes_recv - n1.bytes_recv
    tx_delta = n2.bytes_sent - n1.bytes_sent
    mbps = bytes_to_mbps(rx_delta + tx_delta, max(0.001, SAMPLE_SECONDS))
    return cpu, mem, mbps

def ensure_logs():
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    if not CSV_PATH.exists():
        import csv
        with open(CSV_PATH, "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["timestamp","host","cpu_percent","ram_percent","net_total_mbps"])
    if not JSONL_PATH.exists():
        JSONL_PATH.touch()

def append_logs(ts, cpu, mem, mbps):
    with open(CSV_PATH, "a", newline="") as f:
        w = csv.writer(f)
        w.writerow([ts, HOST, f"{cpu:.1f}", f"{mem:.1f}", f"{mbps:.3f}"])
    with open(JSONL_PATH, "a") as f:
        f.write(json.dumps({
            "timestamp": ts, "host": HOST,
            "cpu_percent": round(cpu,1),
            "ram_percent": round(mem,1),
            "net_total_mbps": round(mbps,3)
        }) + "\n")

def has_cmd(cmd):
    return shutil.which(cmd) is not None

def notify_terminal(message):
    if has_cmd("wall"):
        try:
            subprocess.run(["wall", message], check=False)
        except Exception:
            print(message, flush=True)
    else:
        print(message, flush=True)

def notify_email(subject, body):
    if not EMAIL_TO:
        return
    if has_cmd("mail"):
        try:
            p = subprocess.Popen(["/usr/bin/mail", "-s", subject, EMAIL_TO], stdin=subprocess.PIPE)
            p.communicate(input=body.encode())
            return
        except Exception:
            pass
    if SMTP_HOST:
        import smtplib
        from email.mime.text import MIMEText
        msg = MIMEText(body)
        msg["Subject"] = subject
        msg["From"] = SMTP_USER or f"syshealth@{HOST}"
        msg["To"] = EMAIL_TO
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=10) as s:
            if SMTP_STARTTLS:
                s.starttls()
            if SMTP_USER and SMTP_PASS:
                s.login(SMTP_USER, SMTP_PASS)
            s.send_message(msg)

def main():
    ensure_logs()
    cpu, mem, mbps = collect()
    ts = now()
    append_logs(ts, cpu, mem, mbps)

    alerts = []
    if cpu >= CPU_WARN:
        alerts.append(f"CPU {cpu:.1f}% ≥ {CPU_WARN}%")
    if mem >= RAM_WARN:
        alerts.append(f"RAM {mem:.1f}% ≥ {RAM_WARN}%")
    if mbps >= NET_WARN_Mbps:
        alerts.append(f"NET {mbps:.1f} Mbps ≥ {NET_WARN_Mbps} Mbps")

    if alerts:
        header = f"[System Health Alert @ {ts} on {HOST}]"
        msg = header + "\n" + "\n".join(f"- {a}" for a in alerts) + "\n" + \
              f"\nLog: {CSV_PATH}"
        notify_terminal(msg)
        notify_email("System Health Alert", msg)

    print(f"{ts} cpu={cpu:.1f}% ram={mem:.1f}% net={mbps:.3f}Mbps")

if __name__ == "__main__":
    main()
PYCODE

chmod +x "$PY"

# ====== Python venv + deps ======
if [[ ! -d "$PYENV_DIR" ]]; then
  python3 -m venv "$PYENV_DIR"
fi
# shellcheck disable=SC1090
source "$PYENV_DIR/bin/activate"
python -m pip -q install --upgrade pip >/dev/null
python -m pip -q install psutil >/dev/null

# ====== Export config & run ======
export CPU_WARN RAM_WARN NET_WARN_Mbps SAMPLE_SECONDS LOG_DIR EMAIL_TO \
       SMTP_HOST SMTP_PORT SMTP_USER SMTP_PASS SMTP_STARTTLS

exec python "$PY"

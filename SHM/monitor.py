#!/usr/bin/env python3
import os, time, json, csv, shutil, subprocess, socket
from datetime import datetime, timezone
from pathlib import Path

try:
    import psutil
except ImportError:
    print("psutil missing. Install it with: pip install psutil")
    raise

# Defaults (you can override via env)
CPU_WARN = int(os.getenv("CPU_WARN", "85"))
RAM_WARN = int(os.getenv("RAM_WARN", "90"))
NET_WARN_Mbps = float(os.getenv("NET_WARN_Mbps", "200"))
SAMPLE_SECONDS = float(os.getenv("SAMPLE_SECONDS", "2"))

# Use a user-writable default on WSL to avoid /var/log permissions
LOG_DIR = Path(os.getenv("LOG_DIR", str(Path.home() / ".local/var/syshealth")))
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
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()

def bytes_to_mbps(byte_delta, seconds):
    return (byte_delta * 8.0 / 1_000_000.0) / seconds

def collect():
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
        with open(CSV_PATH, "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["timestamp","host","cpu_percent","ram_percent","net_total_mbps"])
    if not JSONL_PATH.exists():
        JSONL_PATH.touch()

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

def main():
    ensure_logs()
    cpu, mem, mbps = collect()
    ts = now()

    alerts = []
    if cpu >= CPU_WARN:
        alerts.append(f"CPU {cpu:.1f}% ≥ {CPU_WARN}%")
    if mem >= RAM_WARN:
        alerts.append(f"RAM {mem:.1f}% ≥ {RAM_WARN}%")
    if mbps >= NET_WARN_Mbps:
        alerts.append(f"NET {mbps:.1f} Mbps ≥ {NET_WARN_Mbps} Mbps")

    append_logs(ts, cpu, mem, mbps)

    if alerts:
        header = f"[System Health Alert @ {ts} on {HOST}]"
        msg = header + "\n" + "\n".join(f"- {a}" for a in alerts) + "\n" + \
              f"\nLog: {CSV_PATH}"
        notify_terminal(msg)
        notify_email("System Health Alert", msg)

    print(f"{ts} cpu={cpu:.1f}% ram={mem:.1f}% net={mbps:.3f}Mbps")

if __name__ == "__main__":
    main()
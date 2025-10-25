cat > monitor.py <<'PY'
#!/usr/bin/env python3
import os, time, json, csv, shutil, subprocess, socket
from datetime import datetime
from pathlib import Path

try:
    import psutil
except ImportError:
    print("psutil missing. Install it with: pip install psutil")
    raise

CPU_WARN = int(os.getenv("CPU_WARN", "85"))
RAM_WARN = int(os.getenv("RAM_WARN", "90"))
NET_WARN_Mbps = float(os.getenv("NET_WARN_Mbps", "200"))
SAMPLE_SECONDS = float(os.getenv("SAMPLE_SECONDS", "2"))
LOG_DIR = Path(os.getenv("LOG_DIR", "/var/log/syshealth"))
EMAIL_TO = os.getenv("EMAIL_TO", "").strip()

CSV_PATH = LOG_DIR / "metrics.csv"
JSONL_PATH = LOG_DIR / "metrics.jsonl"
HOST = socket.gethostname()

def now():
    return datetime.utcnow().replace(microsecond=0).isoformat() + "Z"

def bytes_to_mbps(byte_delta, seconds):
    return (byte_delta * 8.0 / 1_000_000.0) / seconds

def collect():
    cpu = psutil.cpu_percent(interval=1)
    mem = psutil.virtual_memory().percent
    n1 = psutil.net_io_counters()
    time.sleep(SAMPLE_SECONDS)
    n2 = psutil.net_io_counters()
    rx_delta = n2.bytes_recv - n1.bytes_recv
    tx_delta = n2.bytes_sent - n1.bytes_sent
    mbps = bytes_to_mbps(rx_delta + tx_delta, SAMPLE_SECONDS)
    return cpu, mem, mbps

def ensure_logs():
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    if not CSV_PATH.exists():
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

def main():
    ensure_logs()
    cpu, mem, mbps = collect()
    ts = now()
    append_logs(ts, cpu, mem, mbps)
    print(f"{ts} cpu={cpu:.1f}% ram={mem:.1f}% net={mbps:.3f}Mbps")

if __name__ == "__main__":
    main()
PY

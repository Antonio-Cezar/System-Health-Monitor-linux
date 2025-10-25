#!/usr/bin/env bash
set -euo pipefail

# ===== Configuration =====
: "${CPU_WARN:=85}"
: "${RAM_WARN:=90}"
: "${NET_WARN_Mbps:=200}"
: "${SAMPLE_SECONDS:=2}"
: "${LOG_DIR:=$HOME/.local/var/syshealth}"
: "${EMAIL_TO:=}"
: "${SMTP_HOST:=}"
: "${SMTP_PORT:=587}"
: "${SMTP_USER:=}"
: "${SMTP_PASS:=}"
: "${SMTP_STARTTLS:=1}"
: "${WATCH:=0}"                 # 0 = one-shot, 1 = continuous
: "${WATCH_INTERVAL:=10}"       # seconds between updates in watch mode

mkdir -p "$LOG_DIR"

export CPU_WARN RAM_WARN NET_WARN_Mbps SAMPLE_SECONDS LOG_DIR EMAIL_TO \
       SMTP_HOST SMTP_PORT SMTP_USER SMTP_PASS SMTP_STARTTLS

run_once() {
  echo "--------------------------------------------------"
  echo "Running System Health Monitor"
  echo "--------------------------------------------------"
  echo "CPU Warn: ${CPU_WARN}% | RAM Warn: ${RAM_WARN}% | NET Warn: ${NET_WARN_Mbps} Mbps"
  echo "Sample interval: ${SAMPLE_SECONDS}s"
  echo "Logs stored in: ${LOG_DIR}"
  echo "--------------------------------------------------"

  output=$(python3 ./monitor.py 2>&1)
  echo "$output"
  echo "--------------------------------------------------"
  if echo "$output" | grep -q "Alert"; then
      echo "!!!ALERT DETECTED!!!"
  else
      echo "System within normal parameters."
  fi
  echo "Done."
  echo "--------------------------------------------------"
}

if [[ "$WATCH" == "1" ]]; then
  while true; do
    clear
    echo "System Health Monitor (watch mode) — refresh: ${WATCH_INTERVAL}s  |  sample: ${SAMPLE_SECONDS}s"
    echo
    run_once
    sleep "$WATCH_INTERVAL"
  done
else
  run_once
fi

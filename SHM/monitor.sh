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

# ===== Setup =====
mkdir -p "$LOG_DIR"

# Export config so Python can read it
export CPU_WARN RAM_WARN NET_WARN_Mbps SAMPLE_SECONDS LOG_DIR EMAIL_TO \
       SMTP_HOST SMTP_PORT SMTP_USER SMTP_PASS SMTP_STARTTLS

# ===== Run and capture output =====
echo "--------------------------------------------------"
echo " 🧩  Running System Health Monitor"
echo "--------------------------------------------------"
echo "CPU Warn: ${CPU_WARN}% | RAM Warn: ${RAM_WARN}% | NET Warn: ${NET_WARN_Mbps} Mbps"
echo "Sample interval: ${SAMPLE_SECONDS}s"
echo "Logs stored in: ${LOG_DIR}"
echo "--------------------------------------------------"

# Run the Python collector and capture its output
output=$(python3 ./monitor.py 2>&1)

# Display result from Python
echo "$output"
echo "--------------------------------------------------"

# Highlight alert conditions if they appear
if echo "$output" | grep -q "Alert"; then
    echo "🚨 ALERT DETECTED!"
else
    echo "✅ System within normal parameters."
fi

echo "Done."
echo "--------------------------------------------------"

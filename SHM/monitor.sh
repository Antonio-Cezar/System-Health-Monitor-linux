cat > monitor.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail

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

# Ensure LOG_DIR exists and is writable
if [[ "$LOG_DIR" != /* ]]; then
  echo "LOG_DIR must be an absolute path. Got: $LOG_DIR" >&2
  exit 1
fi
mkdir -p "$LOG_DIR" || true

# Python venv
APP_DIR="${HOME}/.local/share/syshealth"
PYENV_DIR="${APP_DIR}/venv"
mkdir -p "$APP_DIR"
if [[ ! -d "$PYENV_DIR" ]]; then
  python3 -m venv "$PYENV_DIR"
fi

# shellcheck disable=SC1090
source "$PYENV_DIR/bin/activate"
python -m pip -q install --upgrade pip >/dev/null
python -m pip -q install psutil >/dev/null

# Export config for Python
export CPU_WARN RAM_WARN NET_WARN_Mbps SAMPLE_SECONDS LOG_DIR EMAIL_TO \
       SMTP_HOST SMTP_PORT SMTP_USER SMTP_PASS SMTP_STARTTLS

exec python ./monitor.py
SH

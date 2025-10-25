# System Health Monitor (Linux)

A lightweight **system health monitoring tool** for Linux that combines **Bash** and **Python** to track **CPU**, **memory**, and **network usage** — with live terminal status, structured logging, and alerting capabilities.

---

## Features

- **Hybrid Bash + Python design**  
  Bash handles configuration and orchestration; Python collects and logs system metrics.  
- **CPU / RAM / Network utilization tracking**  
- **Structured logging**  
  Outputs both `.csv` and `.jsonl` for easy integration with dashboards or data tools.  
- **Alerting system**  
  - Terminal notifications via `wall`  
  - Optional email alerts via `mail` or SMTP  
- **Configurable thresholds** via environment variables  
- **Automatable** — run via `cron` or `systemd`  
- **Live dashboard mode** — real-time updates in the terminal

---

## Requirements & Installation

The project works on **Ubuntu** or **WSL (Windows Subsystem for Linux)** with standard packages.  
To ensure everything is installed and ready, run these commands:

```bash
# Install Python and required utilities
sudo apt install -y python3 python3-pip python3-psutil python3-venv

# Optional: install mail utilities for email alerts
sudo apt install -y bsd-mailx

# Ensure bash and core utilities are available (usually preinstalled)
sudo apt install -y bash coreutils
```

---
## live “dashboard” mode in the terminal

``` bash
chmod +x monitor.sh
WATCH=1 WATCH_INTERVAL=10 SAMPLE_SECONDS=5 ./monitor.sh
```

---

## Examples
![Live 1](/SHM/images/1.jpg)

---
![Live 2](/SHM/images/2.jpg)
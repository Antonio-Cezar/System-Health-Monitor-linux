# System Health Monitor (Linux)

A lightweight system health monitoring tool for Linux that combines **Bash** and **Python** to track **CPU**, **memory**, and **network usage** — with logging and alerting capabilities.

---

## Features

- **Hybrid Bash + Python design** — uses Bash for environment setup and Python for metrics collection  
- **CPU / RAM / Network utilization tracking**  
- **Structured logging** in both CSV and JSONL formats  
- **Alerting system**
  - Terminal notifications via `wall`
  - Optional email alerts via `mail` or SMTP
- **Configurable thresholds** via environment variables  
- **Runs on cron or systemd timer** for automation  

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
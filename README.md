
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

## Architecture Overview


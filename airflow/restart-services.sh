#!/usr/bin/env bash
# Restart Airflow services (api-server, scheduler, triggerer) to refresh auth tokens.
# Intended to run daily via cron before the DAG schedule.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
AIRFLOW_HOME="$REPO/airflow"
VENV="$REPO/.venv-airflow"
LOG="$AIRFLOW_HOME/logs/restart-services.log"

export AIRFLOW_HOME

log() { echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') $*" >> "$LOG"; }

log "--- restart-services start ---"

# Stop running services via PID files, fall back to kill
for svc in api-server scheduler triggerer; do
    pidfile="$AIRFLOW_HOME/airflow-${svc}.pid"
    if [[ -f "$pidfile" ]]; then
        pid=$(cat "$pidfile")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log "Sent SIGTERM to $svc (pid $pid)"
        fi
    fi
done

sleep 3

# Force-kill anything still hanging around
for svc in api-server scheduler triggerer; do
    pidfile="$AIRFLOW_HOME/airflow-${svc}.pid"
    if [[ -f "$pidfile" ]]; then
        pid=$(cat "$pidfile")
        if kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid"
            log "Sent SIGKILL to $svc (pid $pid)"
            sleep 1
        fi
        rm -f "$pidfile"
    fi
done

# Also kill any orphaned airflow processes not tracked by PID files
pkill -9 -f 'airflow (api-server|scheduler|triggerer)' 2>/dev/null || true
sleep 2

# Clean up any remaining PID files
rm -f "$AIRFLOW_HOME"/airflow-*.pid

# Start services
source "$VENV/bin/activate"
airflow api-server -D
airflow scheduler -D
airflow triggerer -D

log "Services restarted"
log "--- restart-services end ---"

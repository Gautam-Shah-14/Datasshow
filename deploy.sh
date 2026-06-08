#!/bin/bash

# =====================================================

# Datasshow Backend Deployment Script

# =====================================================

set -e

# ---------------- Configuration ----------------

APP_NAME="Datasshow"
APP_DIR="Datasshow"
BRANCH="main"

VENV_PATH="$APP_DIR/venv"

HOST="0.0.0.0"
PORT="8000"

LOG_FILE="$APP_DIR/deploy.log"
UVICORN_LOG="$APP_DIR/uvicorn.log"

# Python mail script

MAIL_SCRIPT="$APP_DIR/send_mail.py"

# ------------------------------------------------

# Create log file if it doesn't exist

mkdir -p "$APP_DIR"
touch "$LOG_FILE"

log() {
echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

send_mail() {
SUBJECT="$1"
BODY="$2"

```
if [ -f "$MAIL_SCRIPT" ]; then
    python "$MAIL_SCRIPT" "$SUBJECT" "$BODY" || true
fi
```

}

handle_error() {
FAILED_LINE=$1
FAILED_COMMAND=$2

```
log "ERROR OCCURRED"
log "Line: $FAILED_LINE"
log "Command: $FAILED_COMMAND"

send_mail \
    "❌ $APP_NAME Deployment Failed" \
    "Deployment failed.
```

Server: $(hostname)

Time: $(date)

Line: $FAILED_LINE

Command:
$FAILED_COMMAND

Recent Logs:
$(tail -50 "$LOG_FILE" 2>/dev/null)"
}

trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

# =====================================================

# Deployment Start

# =====================================================

log "====================================="
log "Starting Deployment Check"
log "====================================="

cd "$APP_DIR"

# -----------------------------------------------------

# Activate Virtual Environment

# -----------------------------------------------------

if [ ! -d "$VENV_PATH" ]; then
log "Creating virtual environment..."

```
python3.11 -m venv "$VENV_PATH"
```

fi

source "$VENV_PATH/bin/activate"

# -----------------------------------------------------

# Fetch Latest Changes

# -----------------------------------------------------

log "Fetching latest changes..."

git fetch origin "$BRANCH"

LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git rev-parse origin/"$BRANCH")

if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ]; then
log "No new changes detected."
exit 0
fi

log "New commit found."
log "Current Commit : $LOCAL_COMMIT"
log "Remote Commit  : $REMOTE_COMMIT"

PREVIOUS_COMMIT="$LOCAL_COMMIT"

# -----------------------------------------------------

# Pull Latest Code

# -----------------------------------------------------

log "Updating code..."

git reset --hard origin/"$BRANCH"

COMMIT_INFO=$(git log -1 --pretty="%h - %s (%an, %ar)")

log "Deploying:"
log "$COMMIT_INFO"

# -----------------------------------------------------

# Install Dependencies

# -----------------------------------------------------

log "Installing dependencies..."

pip install --upgrade pip
pip install -r requirements.txt

# -----------------------------------------------------

# Validate Python Files

# -----------------------------------------------------

log "Running syntax validation..."

python -m compileall .

# -----------------------------------------------------

# Stop Existing Uvicorn

# -----------------------------------------------------

log "Stopping existing Uvicorn process..."

pkill -f "uvicorn" || true

sleep 5

# -----------------------------------------------------

# Start Application

# -----------------------------------------------------

log "Starting FastAPI application..."

nohup uvicorn main:app 
--host "$HOST" 
--port "$PORT" 
> "$UVICORN_LOG" 2>&1 &

echo $! > "$APP_DIR/uvicorn.pid"

sleep 10

# -----------------------------------------------------

# Verify Uvicorn Started

# -----------------------------------------------------

if ! pgrep -f "uvicorn main:app" > /dev/null; then

```
log "Uvicorn failed to start."
log "Rolling back..."

git reset --hard "$PREVIOUS_COMMIT"

pip install -r requirements.txt

nohup uvicorn main:app \
    --host "$HOST" \
    --port "$PORT" \
    > "$UVICORN_LOG" 2>&1 &

handle_error $LINENO "Uvicorn startup failed"
exit 1
```

fi

# -----------------------------------------------------

# Health Check

# -----------------------------------------------------

log "Running health check..."

curl -f "[http://localhost:$PORT/health](http://localhost:$PORT/health)"

log "Health check successful."

# -----------------------------------------------------

# Success Mail

# -----------------------------------------------------

send_mail 
"✅ $APP_NAME Deployment Successful" 
"Deployment completed successfully.

Application: $APP_NAME

Server: $(hostname)

Time: $(date)

Branch: $BRANCH

Commit:
$COMMIT_INFO

Health Check:
PASSED

Recent Logs:
$(tail -30 "$LOG_FILE" 2>/dev/null)"

log "Deployment completed successfully."
log "====================================="

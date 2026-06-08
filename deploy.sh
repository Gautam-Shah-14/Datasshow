#!/bin/bash

# =====================================================
# Datasshow Backend Deployment Script
# =====================================================

# ---------------- Configuration ----------------

APP_NAME="Datasshow"
APP_DIR="home/azureuser/Datasshow"
BRANCH="main"

VENV_PATH="$APP_DIR/venv"

HOST="127.0.0.1"
PORT="8000"

LOG_FILE="$APP_DIR/deploy.log"

# Python mail script
MAIL_SCRIPT="$APP_DIR/send_mail.py"

# ------------------------------------------------

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

send_mail() {
    SUBJECT="$1"
    BODY="$2"

    python "$MAIL_SCRIPT" "$SUBJECT" "$BODY" || true
}

handle_error() {
    FAILED_LINE=$1
    FAILED_COMMAND=$2

    log "ERROR OCCURRED"
    log "Line: $FAILED_LINE"
    log "Command: $FAILED_COMMAND"

    send_mail \
        "❌ $APP_NAME Deployment Failed" \
        "Deployment failed.

Server: $(hostname)

Time: $(date)

Line: $FAILED_LINE

Command:
$FAILED_COMMAND

Recent Logs:
$(tail -50 $LOG_FILE)"

    exit 1
}

trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

# =====================================================
# Deployment Start
# =====================================================

log "====================================="
log "Starting Deployment Check"
log "====================================="

cd "$APP_DIR"

# Fetch latest code
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

# Store rollback commit
PREVIOUS_COMMIT="$LOCAL_COMMIT"

# Activate venv
if [ ! -d "$VENV_PATH" ]; then
    log "Creating virtual environment..."

    python3 -m venv "$VENV_PATH"
fi

source "$VENV_PATH/bin/activate"

# Stop existing Uvicorn
log "Stopping existing Uvicorn process..."

pkill -f "uvicorn" || true

sleep 3

# Pull latest code
log "Updating code..."

git reset --hard origin/"$BRANCH"

COMMIT_INFO=$(git log -1 --pretty="%h - %s (%an, %ar)")

log "Deploying:"
log "$COMMIT_INFO"

# Install dependencies
log "Installing dependencies..."

pip install --upgrade pip

pip install -r requirements.txt

# Basic syntax validation
log "Running syntax validation..."

python -m compileall .

# Start application
log "Starting FastAPI application..."

nohup uvicorn main:app \
    --host "$HOST" \
    --port "$PORT" \
    > "$APP_DIR/uvicorn.log" 2>&1 &

sleep 10

# Verify Uvicorn started
if ! pgrep -f "uvicorn" > /dev/null; then

    log "Uvicorn failed to start."

    log "Rolling back..."

    git reset --hard "$PREVIOUS_COMMIT"

    pip install -r requirements.txt

    nohup uvicorn main:app \
        --host "$HOST" \
        --port "$PORT" \
        > "$APP_DIR/uvicorn.log" 2>&1 &

    handle_error $LINENO "Uvicorn startup failed"
fi

# Health Check
log "Running health check..."

curl -f "http://localhost:$PORT/health"

log "Health check successful."

# Success Notification
send_mail \
    "✅ $APP_NAME Deployment Successful" \
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
$(tail -30 "$LOG_FILE")"

log "Deployment completed successfully."
log "====================================="

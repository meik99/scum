#!/bin/bash

cat << 'EOF'
                      _/_/_/    _/_/_/  _/    _/  _/      _/
                   _/        _/        _/    _/  _/_/  _/_/
                    _/_/    _/        _/    _/  _/  _/  _/
                       _/  _/        _/    _/  _/      _/
                _/_/_/      _/_/_/    _/_/    _/      _/

                           DEDICATED SERVER
              Based on the great https://github.com/EvilOlaf/scum
                      https://github.com/meik99/scum

EOF

# workaround to avoid breaking existing installations
# if PORT is still used in docker-compose.yml, move its value to GAMEPORT and warn user.
if [[ -n "${PORT}" ]]; then
    echo 'ATTENTION!'
    echo '"PORT" environment variable is deprecated'
    echo 'and will be removed at some point.'
    echo 'Replace with "GAMEPORT" in your docker-compose.yml.'
    echo 'ATTENTION!'
    GAMEPORT="${GAMEPORT:-$PORT}"
fi

MAX_RETRIES=5
for i in $(seq 1 ${MAX_RETRIES});
do
    # update SteamCMD and SCUM dedicated server
    echo "Update SteamCMD and SCUM dedicated server..."
    /opt/steamcmd.sh +@sSteamCmdForcePlatformType windows \
    +force_install_dir /opt/scumserver \
    +login anonymous \
    +app_update 3792580 validate \
    +quit

    steamcmd_exit_code=$?

    if [[ steamcmd_exit_code -eq 0 ]]; then
        echo "Update and validation done"
        break
    fi

    echo "Failed to update and validate, retrying ${i} / ${MAX_RETRIES}"
    sleep $(( i * 5 ))
done


# Handle shutdown signals gracefully, suppress false positive shellcheck warning
# shellcheck disable=SC2329
shutdown() {
    echo "Received shutdown signal, stopping server..."
    if [ -n "$SCUM_PID" ]; then
        echo "Sending SIGINT to SCUMServer.exe (PID $SCUM_PID)..."
        kill -INT "$SCUM_PID" 2>/dev/null || true

        # Wait up to 60 seconds for graceful shutdown
        for _ in {1..60}; do
            if ! kill -0 "$SCUM_PID" 2>/dev/null; then
                echo "Server stopped gracefully"
                exit 0
            fi
            sleep 1
        done

        echo "Server did not stop in time, forcing shutdown..."
        kill -KILL "$SCUM_PID" 2>/dev/null || true
    fi

    # Also stop the xvfb-run wrapper to clean up
    if [ -n "$WRAPPER_PID" ]; then
        kill -TERM "$WRAPPER_PID" 2>/dev/null || true
    fi

    exit 0
}

echo "Starting SCUM dedicated server..."

# Start server in background so we can handle signals
# Use 1x1x1 since no ui will be shown at all
# Disable shellcheck warning, quoting does more harm than use in this particular case
# shellcheck disable=SC2086
xvfb-run --auto-servernum --server-args="-screen 0 1x1x1" \
  wine /opt/scumserver/SCUM/Binaries/Win64/SCUMServer.exe \
    -log \
    -port=${GAMEPORT:-7777} \
    -QueryPort=${QUERYPORT:-27015} \
    -MaxPlayers=${MAXPLAYERS:-32} \
    ${ADDITIONALFLAGS} &

WRAPPER_PID=$!
echo "Server wrapper started with PID $WRAPPER_PID"

# Wait for SCUMServer.exe to appear and get its PID
echo "Waiting for SCUMServer.exe process..."
SCUM_PID=""
for _ in {1..30}; do
    SCUM_PID="$(pgrep -f "Z:.*SCUMServer.exe" | head -1)"
    if [ -n "$SCUM_PID" ]; then
        echo "SCUMServer.exe found with PID $SCUM_PID"
        break
    fi
    sleep 1
done

if [ -z "$SCUM_PID" ]; then
    echo "ERROR: SCUMServer.exe process not found after 30 seconds"
    exit 1
fi

# Now that SCUM_PID is known, set up signal handlers
trap shutdown SIGTERM SIGINT

# Crude readiness probe to not get into a restart loop
touch /tmp/healthy

# Wait for server process
wait $WRAPPER_PID
exit_code=$?
echo "Server exited with code $exit_code"
exit $exit_code

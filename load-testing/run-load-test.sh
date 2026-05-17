#!/usr/bin/env bash
set -euo pipefail

APP_URL="${APP_URL:-http://localhost:5000}"
USERS="${USERS:-50}"
SPAWN_RATE="${SPAWN_RATE:-10}"
DURATION="${DURATION:-60s}"
REPORT_DIR="$(dirname "$0")/reports"

mkdir -p "$REPORT_DIR"

echo "======================================"
echo "  Locust Load Test"
echo "  Target:      $APP_URL"
echo "  Users:       $USERS"
echo "  Spawn rate:  $SPAWN_RATE/s"
echo "  Duration:    $DURATION"
echo "======================================"

docker run --rm \
  --network host \
  -v "$(pwd)/locustfile.py:/mnt/locust/locustfile.py:ro" \
  -v "$REPORT_DIR:/mnt/locust/reports" \
  locustio/locust:2.24.0 \
    -f /mnt/locust/locustfile.py \
    --headless \
    --users "$USERS" \
    --spawn-rate "$SPAWN_RATE" \
    --run-time "$DURATION" \
    --host "$APP_URL" \
    --html /mnt/locust/reports/report.html \
    --csv /mnt/locust/reports/results

echo ""
echo "Report saved to: $REPORT_DIR/report.html"

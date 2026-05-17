#!/usr/bin/env bash
set -euo pipefail

APP_URL="${APP_URL:-http://localhost:5000}"
CONCURRENCY="${CONCURRENCY:-20}"
REQUESTS="${REQUESTS:-1000}"

echo "======================================"
echo "  Apache Benchmark Stress Test"
echo "  Target:      $APP_URL"
echo "  Concurrency: $CONCURRENCY"
echo "  Requests:    $REQUESTS"
echo "======================================"

echo ""
echo "--- GET /products ($REQUESTS requests, $CONCURRENCY concurrent) ---"
ab -n "$REQUESTS" -c "$CONCURRENCY" \
   -H "Accept: application/json" \
   "${APP_URL}/products"

echo ""
echo "--- GET /health (500 requests, 10 concurrent) ---"
ab -n 500 -c 10 "${APP_URL}/health"

echo ""
echo "--- POST /orders (200 requests, 10 concurrent) ---"
TMPFILE=$(mktemp /tmp/order.XXXXXX.json)
echo '{"product_id":1,"quantity":1}' > "$TMPFILE"
ab -n 200 -c 10 \
   -T "application/json" \
   -p "$TMPFILE" \
   "${APP_URL}/orders"
rm -f "$TMPFILE"

echo ""
echo "Done."

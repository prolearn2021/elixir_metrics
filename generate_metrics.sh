#!/bin/bash
set -euo pipefail

# ===== Config (overridable with env) =====
BASE_URL="${BASE_URL:-http://localhost:4000/api}"
STATSD_HOST="${STATSD_HOST:-localhost}"   # use 'datadog' if you run this inside the app container
STATSD_PORT="${STATSD_PORT:-8125}"
DELAY="${DELAY:-0.5}"
ITERATIONS="${ITERATIONS:-20}"

echo "🚀 Starting Metrics Generation Script (BASE_URL=$BASE_URL, STATSD=$STATSD_HOST:$STATSD_PORT)"
echo "==========================================================================================="

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'
print_status(){ echo -e "${BLUE}[INFO]${NC} $*"; }
print_success(){ echo -e "${GREEN}[SUCCESS]${NC} $*"; }
print_warning(){ echo -e "${YELLOW}[WARNING]${NC} $*"; }
print_error(){ echo -e "${RED}[ERROR]${NC} $*"; }

have_cmd(){ command -v "$1" >/dev/null 2>&1; }

# ---- Health ----
check_server(){
  print_status "Checking if server is running at $BASE_URL/health ..."
  if curl -sSf "$BASE_URL/health" >/dev/null 2>&1; then
    print_success "Server is running ✔"
  else
    print_error "Server is not responding. Start it (docker: app service) then re-run."
    exit 1
  fi
}

# ---- DogStatsD helpers (Datadog Agent) ----
send_statsd(){
  local line="$1"  # e.g. "demo.counter:1|c"
  # nc on macOS: -u (UDP), -w1 (1s timeout)
  if have_cmd nc; then
    echo -n "$line" | nc -u -w1 "$STATSD_HOST" "$STATSD_PORT" || true
  else
    print_warning "nc not found; skipping DogStatsD packet: $line"
  fi
}

burst_statsd_samples(){
  print_status "Sending a few DogStatsD samples to $STATSD_HOST:$STATSD_PORT ..."
  send_statsd "demo.counter:1|c"
  send_statsd "demo.gauge:42|g"
  send_statsd "demo.timing:120|ms"
  send_statsd "elixir_metrics.requests:1|c"
  send_statsd "elixir_metrics.latency:$(($RANDOM%200+50))|ms"
  print_success "DogStatsD samples sent"
}

# ---- HTTP metric generators (POST endpoints) ----
json_field(){
  # jq if available, otherwise print raw
  if have_cmd jq; then jq -r "$1" 2>/dev/null || true; else cat; fi
}

generate_http_metrics(){
  print_status "Generating HTTP request metrics ($ITERATIONS iterations) ..."
  for type in telemetry opentelemetry both; do
    echo "  📊 Testing $type approach..."
    for i in $(seq 1 "$ITERATIONS"); do
      if resp="$(curl -sS -X POST "$BASE_URL/metrics/test/$type")"; then
        dur="$(printf '%s' "$resp" | json_field '.duration_ms // "N/A"')"
        printf "    Request %2d: %sms  " "$i" "$dur"
      else
        printf "    Request %2d: FAILED  " "$i"
      fi
      [ $((i % 5)) -eq 0 ] && echo ""
      sleep "$DELAY"
    done
    echo ""
  done
  print_success "HTTP metrics generation completed"
}

generate_database_metrics(){
  print_status "Generating database operation metrics..."
  for type in telemetry opentelemetry both; do
    echo "  🗄️  Testing DB ops with $type..."
    for i in $(seq 1 10); do
      if resp="$(curl -sS -X POST "$BASE_URL/metrics/database/$type")"; then
        dur="$(printf '%s' "$resp" | json_field '.duration_ms // "N/A"')"
        echo "    DB Query $i: ${dur}ms"
      else
        echo "    DB Query $i: FAILED"
      fi
      sleep "$DELAY"
    done
  done
  print_success "Database metrics generation completed"
}

generate_job_metrics(){
  print_status "Generating background job metrics..."
  for type in telemetry opentelemetry both; do
    echo "  ⚡ Testing job execution with $type..."
    for i in $(seq 1 8); do
      if resp="$(curl -sS -X POST "$BASE_URL/metrics/job/$type")"; then
        status="$(printf '%s' "$resp" | json_field '.status // "N/A"')"
        dur="$(printf '%s' "$resp" | json_field '.duration_ms // "N/A"')"
        echo "    Job $i: $status (${dur}ms)"
      else
        echo "    Job $i: FAILED"
      fi
      sleep "$DELAY"
    done
  done
  print_success "Job metrics generation completed"
}

generate_mixed_workload(){
  print_status "Generating mixed workload ..."
  for i in $(seq 1 15); do
    case $((RANDOM % 4)) in
      0) curl -sS -X POST "$BASE_URL/metrics/test/both" >/dev/null && echo -n "📊 " ;;
      1) curl -sS -X POST "$BASE_URL/metrics/database/both" >/dev/null && echo -n "🗄️ " ;;
      2) curl -sS -X POST "$BASE_URL/metrics/job/both" >/dev/null && echo -n "⚡ " ;;
      3) curl -sS "$BASE_URL/health" >/dev/null && echo -n "❤️ " ;;
    esac
    # random small delay
    sleep "$(python - <<'PY' 2>/dev/null || echo "$DELAY"
import random; print(round(random.uniform(0.2, 0.8),2))
PY
)"
  done
  echo ""
  print_success "Mixed workload generation completed"
}

simulate_load_test(){
  print_status "Simulating load test (rapid POST /metrics/test/both) ..."
  for i in $(seq 1 50); do
    (curl -sS -X POST "$BASE_URL/metrics/test/both" >/dev/null) &
    if [ $((i % 10)) -eq 0 ]; then
      echo "    Sent $i requests..."
      wait
    fi
    sleep 0.1
  done
  wait
  print_success "Load test completed"
}

show_metrics_summary(){
  print_status "Fetching metrics summary..."
  if resp="$(curl -sS "$BASE_URL/metrics/summary")"; then
    if have_cmd jq; then echo "$resp" | jq . || echo "$resp"; else echo "$resp"; fi
  else
    print_error "Failed to fetch metrics summary"
  fi
}

show_links(){
  echo ""
  echo "📊 Useful links:"
  echo "  • Phoenix LiveDashboard: http://localhost:4000/dev/dashboard"
  echo "  • Health Check: $BASE_URL/health"
  echo "  • Metrics Summary: $BASE_URL/metrics/summary"
  echo "  • Datadog:"
  echo "      - Logs:        https://${DD_SITE:-datadoghq.eu}/logs/live"
  echo "      - Metrics:     https://${DD_SITE:-datadoghq.eu}/metric/summary"
  echo "      - APM Traces:  https://${DD_SITE:-datadoghq.eu}/apm/traces"
  echo ""
}

continuous_generation(){
  print_status "Starting continuous metrics generation (Ctrl+C to stop) ..."
  trap 'print_warning "Stopping continuous generation..."; exit 0' INT
  while true; do
    case $((RANDOM % 3)) in
      0) curl -sS -X POST "$BASE_URL/metrics/test/both" >/dev/null ;;
      1) curl -sS -X POST "$BASE_URL/metrics/database/both" >/dev/null ;;
      2) curl -sS -X POST "$BASE_URL/metrics/job/both" >/dev/null ;;
    esac
    sleep $((2 + RANDOM % 5))
  done
}

usage(){
  cat <<EOF
Usage: $0 [COMMAND]

Commands:
  full, all     Generate all types of metrics (default)
  http          Generate only HTTP request metrics
  database|db   Generate only database operation metrics
  jobs          Generate only job execution metrics
  mixed         Generate mixed workload metrics
  load          Simulate load testing
  statsd        Send a small DogStatsD burst to the Agent
  continuous    Generate metrics continuously (Ctrl+C to stop)
  summary       Show current metrics summary
  links         Show useful links
  check         Check if server is running
  help          Show this help message

Env overrides:
  BASE_URL (default: http://localhost:4000/api)
  STATSD_HOST (default: localhost)
  STATSD_PORT (default: 8125)
  DELAY, ITERATIONS
EOF
}

main(){
  case "${1:-full}" in
    help|-h|--help) usage ;;
    check)          check_server ;;
    http)           check_server; generate_http_metrics ;;
    database|db)    check_server; generate_database_metrics ;;
    jobs)           check_server; generate_job_metrics ;;
    mixed)          check_server; generate_mixed_workload ;;
    load)           check_server; simulate_load_test ;;
    statsd)         burst_statsd_samples ;;
    continuous|cont)check_server; continuous_generation ;;
    summary)        check_server; show_metrics_summary ;;
    links)          show_links ;;
    full|all|*)     check_server
                    generate_http_metrics
                    sleep 1
                    generate_database_metrics
                    sleep 1
                    generate_job_metrics
                    sleep 1
                    generate_mixed_workload
                    sleep 1
                    simulate_load_test
                    echo ""; show_metrics_summary; show_links
                    print_success "🎉 All metrics generation completed!"
                    ;;
  esac
}

main "${1:-full}"
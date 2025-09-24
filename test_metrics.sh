#!/bin/bash

echo "Testing Elixir Metrics Comparison"
echo "================================="

# Health check
echo -e "\n1. Health Check:"
curl -s http://localhost:4000/api/health | jq .

# Test Telemetry
echo -e "\n2. Testing Native Telemetry:"
for i in {1..5}; do
  curl -s -X POST http://localhost:4000/api/metrics/test/telemetry | jq -c .
  sleep 0.5
done

# Test OpenTelemetry
echo -e "\n3. Testing OpenTelemetry:"
for i in {1..5}; do
  curl -s -X POST http://localhost:4000/api/metrics/test/opentelemetry | jq -c .
  sleep 0.5
done

# Test Both
echo -e "\n4. Testing Both Simultaneously:"
for i in {1..5}; do
  curl -s -X POST http://localhost:4000/api/metrics/test/both | jq -c .
  sleep 0.5
done

# Database operations
echo -e "\n5. Testing Database Metrics:"
curl -s -X POST http://localhost:4000/api/metrics/database/both | jq .

# Job execution
echo -e "\n6. Testing Job Metrics:"
curl -s -X POST http://localhost:4000/api/metrics/job/both | jq .

# Summary
echo -e "\n7. Metrics Summary:"
curl -s http://localhost:4000/api/metrics/summary | jq .

echo -e "\n✅ Testing complete!"
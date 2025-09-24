# Elixir Metrics MVP

A multi-module Elixir application demonstrating metrics collection using Phoenix, Ecto, Oban, Telemetry, and OpenTelemetry with Graphite export.

## Prerequisites

- Docker and Docker Compose (for containerized setup)
- OR: Elixir 1.15+, PostgreSQL, and Graphite (for local setup)

## Quick Start with Docker

```bash
# Start all services (PostgreSQL, Graphite, and the app)
docker-compose up

# Or run in background
docker-compose up -d

# View logs
docker-compose logs -f app

# Stop services
docker-compose down
```

Access:
- Application: http://localhost:4000
- Graphite UI: http://localhost
- OpenTelemetry Collector metrics: http://localhost:8888/metrics

## Quick Start (Local)

### Step 1: Install dependencies
```bash
mix deps.get
mix deps.compile
```

### Step 2: Set up the database
```bash
# Create the database
mix ecto.create

# Run migrations (including Oban tables)
mix ecto.migrate
```

**Migration files location:** `priv/repo/migrations/`

Current migrations:
- `add_oban_jobs_table.exs` - Creates Oban job queue tables
- `create_metrics_table.exs` - Creates metrics storage table

To create a new migration:
```bash
mix ecto.gen.migration migration_name
```

### Step 3: Start the application
```bash
# Start Phoenix server
mix phx.server

# Or with interactive shell for debugging
iex -S mix phx.server
```

The API will be available at http://localhost:4000

### Troubleshooting

If you encounter database connection issues:
1. Ensure PostgreSQL is running locally
2. Check database credentials in `config/config.exs`
3. Default credentials: username: `postgres`, password: `postgres`, database: `elixir_metrics`

To reset the database:
```bash
mix ecto.drop
mix ecto.create
mix ecto.migrate
```

## Running Tests

```bash
mix test
```

## Code Quality

```bash
# Format code
mix format

# Run static analysis
mix credo

# Run type checking (first time: mix dialyzer --plt)
mix dialyzer
```

## Architecture

### Core Technologies

| Component | Purpose | Java Equivalent |
|-----------|---------|-----------------|
| **Phoenix** | Web framework - handles HTTP requests, WebSockets, APIs | Spring MVC/Boot |
| **Ecto** | Database ORM - schemas, queries, migrations | Hibernate/JPA |
| **Oban** | Background job processor - async tasks, scheduling | Spring Batch + Quartz |
| **Telemetry** | Metrics & instrumentation library | Micrometer |
| **Graphite** | Time-series metrics storage | Graphite/InfluxDB |

### How Components Work Together

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Phoenix   │────▶│    Ecto     │────▶│ PostgreSQL  │
│ (Web Layer) │     │   (ORM)     │     │ (Database)  │
└─────────────┘     └─────────────┘     └─────────────┘
       │                   ▲                    ▲
       │                   │                    │
       ▼                   │                    │
┌─────────────┐     ┌─────────────┐            │
│  Telemetry  │     │    Oban     │────────────┘
│  (Metrics)  │     │ (Job Queue) │
└─────────────┘     └─────────────┘
       │
       ▼
┌─────────────┐
│  Graphite   │
│  (Storage)  │
└─────────────┘
```

### Data Flow Example

1. **HTTP Request** → Phoenix receives metrics data
2. **Validation** → Ecto validates and saves to PostgreSQL
3. **Background Job** → Oban queues async processing
4. **Telemetry Events** → Automatic instrumentation captures performance data
5. **Export** → Metrics sent to Graphite for visualization

### Module Structure

- **ElixirMetrics** - Core business logic and domain models
- **ElixirMetricsWeb** - Phoenix web layer with API endpoints
- **ElixirMetrics.Telemetry** - Telemetry event handling and metrics collection
- **ElixirMetrics.Metrics.Graphite** - Graphite reporter for metrics export
- **ElixirMetrics.Metrics.OpenTelemetry** - OpenTelemetry integration for comparison
- **ElixirMetrics.Workers** - Oban background jobs for async processing

### Why This Stack?

- **Phoenix**: Fast, concurrent web server with excellent real-time support
- **Ecto**: Type-safe database queries with migrations
- **Oban**: Reliable background processing without additional infrastructure (uses PostgreSQL)
- **Telemetry**: Native Elixir instrumentation (no APM agent needed)
- **Single Database**: PostgreSQL serves both application data and job queue (simplifies operations)

## Configuration

### Database
Configure PostgreSQL in `config/dev.exs`:
```elixir
config :elixir_metrics, ElixirMetrics.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "elixir_metrics_dev"
```

### Graphite
Configure Graphite in `config/config.exs`:
```elixir
config :statix,
  host: "localhost",
  port: 8125,
  prefix: "elixir_metrics"
```

### Oban
Background jobs in `config/config.exs`:
```elixir
config :elixir_metrics, Oban,
  repo: ElixirMetrics.Repo,
  queues: [default: 10, metrics: 20]
```

## API Endpoints

### Health & Info
- `GET /api/health` - Health check
- `GET /api/metrics/summary` - Metrics system summary

### Test Metrics (accepts type: telemetry, opentelemetry, or both)
- `POST /api/metrics/test/:type` - Test HTTP metrics
- `POST /api/metrics/database/:type` - Test database metrics
- `POST /api/metrics/job/:type` - Test job execution metrics

## Testing Both Metrics Approaches

### 1. Native Telemetry (telemetry.execute)
```bash
# Test native Telemetry
curl -X POST http://localhost:4000/api/metrics/test/telemetry
```

### 2. OpenTelemetry
```bash
# Test OpenTelemetry
curl -X POST http://localhost:4000/api/metrics/test/opentelemetry
```

### 3. Compare Both
```bash
# Test both simultaneously
curl -X POST http://localhost:4000/api/metrics/test/both

# Or run the full test suite
./test_metrics.sh
```

### Key Differences

| Feature | Native Telemetry | OpenTelemetry |
|---------|-----------------|---------------|
| Setup | Built into Elixir | Requires additional deps |
| Performance | Very lightweight | More overhead |
| Standards | Elixir-specific | Industry standard |
| Tracing | Events only | Full distributed tracing |
| Export formats | Custom | OTLP, Jaeger, Zipkin |
| Graphite support | Direct via UDP | Via OTLP Collector |

## Metrics Collection

Collects:
- HTTP request duration and count
- Database query performance
- Background job execution time
- Custom business metrics

Exports to Graphite and OpenTelemetry for comparison.

## Manual Metrics Testing

### Check if Graphite is Working

1. **Start the Docker services:**
   ```bash
   docker-compose up -d
   ```

2. **Send test metrics manually via CLI:**
   ```bash
   # Send a gauge metric
   echo "myapp.users.active:25|g" | nc -u -w1 localhost 8125

   # Send a counter metric
   echo "myapp.api.requests:1|c" | nc -u -w1 localhost 8125

   # Send a timer metric
   echo "myapp.response.time:120|ms" | nc -u -w1 localhost 8125
   ```

3. **Wait for StatsD flush (5-10 seconds), then check Graphite:**
   ```bash
   # Check if your custom metrics appeared
   curl -s "http://localhost/metrics/find?query=stats.gauges.myapp*" | jq
   curl -s "http://localhost/metrics/find?query=stats.counters.myapp*" | jq
   curl -s "http://localhost/metrics/find?query=stats.timers.myapp*" | jq
   ```

4. **View metrics in Graphite Web UI:**
   - Open http://localhost in your browser
   - Navigate to: Metrics → stats → gauges/counters/timers → myapp

### Understanding Metric Paths

Metrics sent to StatsD appear in Graphite under these namespaces:
- **Gauges**: `stats.gauges.your.metric.name`
- **Counters**: `stats.counters.your.metric.name`
- **Timers**: `stats.timers.your.metric.name`

### Test Elixir Application Metrics

```bash
# Test the application's metrics endpoints
curl -X POST http://localhost:4000/api/metrics/test/telemetry

# Check if application metrics appeared (wait 10 seconds)
curl -s "http://localhost/metrics/find?query=stats.gauges.elixir_metrics*" | jq
```

### Troubleshooting

- **No metrics showing?** Check Docker logs: `docker logs elixir-metrics-graphite-1`
- **Port issues?** Verify StatsD is listening: `netstat -an | grep 8125`
- **Custom names not working?** Ensure you're using the correct format: `name:value|type`

## Getting Metrics Data via REST API

Once metrics are flowing, you can retrieve them using Graphite's REST API with curl:

### 1. Find Available Metrics
```bash
# Get list of all available Elixir metrics
curl -s "http://localhost/metrics/find?query=stats.gauges.elixir_metrics.*&format=json" | jq

# Browse the metric tree structure
curl -s "http://localhost/metrics/find?query=stats.gauges.elixir_metrics.elixir_metrics.http.*&format=json" | jq
```

### 2. Get Metric Values
```bash
# Get HTTP request count data (last hour)
curl -s "http://localhost/render?target=stats.gauges.elixir_metrics.elixir_metrics.http.request.count.status_200.*&format=json&from=-1hour" | jq

# Get HTTP request duration data
curl -s "http://localhost/render?target=stats.gauges.elixir_metrics.elixir_metrics.http.request.duration.*&format=json&from=-10min" | jq

# Get multiple metrics at once
curl -s "http://localhost/render?target=stats.gauges.elixir_metrics.*&format=json&from=-5min" | jq
```

### 3. Different Output Formats
```bash
# JSON format (default)
curl -s "http://localhost/render?target=stats.gauges.elixir_metrics.http.request.count&format=json&from=-10min"

# CSV format
curl -s "http://localhost/render?target=stats.gauges.elixir_metrics.http.request.count&format=csv&from=-10min"

# Raw format
curl -s "http://localhost/render?target=stats.gauges.elixir_metrics.http.request.count&format=raw&from=-10min"
```

### 4. Time Range Options
```bash
# Last 10 minutes
&from=-10min

# Last hour
&from=-1hour

# Last 24 hours
&from=-24hour

# Specific time range
&from=07:00_20250922&until=08:00_20250922
```

### 5. Data Format Explanation

Graphite returns data as arrays of `[value, timestamp]` pairs:
```json
{
  "target": "stats.gauges.elixir_metrics.http.request.count",
  "datapoints": [
    [null, 1758525480],    // No data for this timestamp
    [1.0, 1758525490],     // Value 1.0 at timestamp 1758525490
    [2.0, 1758525500]      // Value 2.0 at timestamp 1758525500
  ]
}
```

### 6. Common Metric Paths

Your Elixir application sends metrics to these paths:
- **HTTP Requests**: `stats.gauges.elixir_metrics.elixir_metrics.http.request.count.*`
- **HTTP Duration**: `stats.gauges.elixir_metrics.elixir_metrics.http.request.duration.*`
- **Custom Metrics**: `stats.gauges.elixir_metrics.your.custom.metric.name`
- **Manual Tests**: `stats.gauges.elixir_metrics.elixir.direct.*`

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Elixir metrics project. The repository is currently in its initial state with minimal structure.

## Common Development Commands

### Project Setup
```bash
# Initialize a new Mix project (if mix.exs doesn't exist)
mix new . --app elixir_metrics

# Install dependencies
mix deps.get
```

### Development Commands
```bash
# Run the application
mix run

# Start an interactive Elixir shell with the project loaded
iex -S mix

# Run tests
mix test

# Run a specific test file
mix test test/path_to_test.exs

# Run tests with coverage
mix test --cover

# Format code
mix format

# Check code formatting
mix format --check-formatted

# Run static analysis with Credo (if configured)
mix credo

# Run Dialyzer for type checking (if configured)
mix dialyzer

# Compile the project
mix compile

# Clean build artifacts
mix clean
```

## Expected Project Structure

Once fully set up, the project should follow standard Elixir/Mix conventions:

- `lib/` - Main application code
- `test/` - Test files
- `config/` - Configuration files
- `deps/` - Dependencies (auto-generated)
- `_build/` - Build artifacts (auto-generated)
- `mix.exs` - Project configuration and dependencies
- `mix.lock` - Locked dependency versions

## Architecture Notes

As a metrics library/application, consider implementing:

- Metric collectors for gathering data
- Storage adapters for different backends (in-memory, ETS, external databases)
- Reporters for exporting metrics (StatsD, Prometheus, etc.)
- Aggregation strategies for time-series data
- Configuration module for runtime settings

## Testing Approach

- Use ExUnit for unit and integration tests
- Mock external dependencies with libraries like Mox if needed
- Test metric collection accuracy and performance
- Verify reporter output formats
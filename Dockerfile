# Build stage
FROM elixir:1.15-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base git

# Set working directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV=dev

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get && mix deps.compile

# Copy source code
COPY config config
COPY lib lib
COPY priv priv

# Compile the application
RUN mix compile

# Runtime stage
FROM elixir:1.15-alpine

RUN apk add --no-cache openssl ncurses-libs

WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy the compiled application
COPY --from=build /app/_build ./_build
COPY --from=build /app/deps ./deps
COPY --from=build /app/config ./config
COPY --from=build /app/lib ./lib
COPY --from=build /app/priv ./priv
COPY --from=build /app/mix.exs ./mix.exs
COPY --from=build /app/mix.lock ./mix.lock

ENV MIX_ENV=dev

EXPOSE 4000

CMD ["mix", "phx.server"]
ARG ELIXIR_VERSION=1.19.4
ARG OTP_VERSION=28.3
ARG DEBIAN_VERSION=trixie-20251208-slim

ARG IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"

FROM ghcr.io/letsencrypt/pebble:latest AS pebble

FROM ${IMAGE}

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends inotify-tools build-essential git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=pebble /test/certs/pebble.minica.pem /usr/local/share/ca-certificates/pebble.minica.crt
RUN update-ca-certificates

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get

RUN mix deps.compile
RUN env MIX_ENV=test mix deps.compile
RUN mix dialyzer.build

COPY . ./

CMD ["mix", "test"]

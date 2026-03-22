ARG ELIXIR_VERSION=1.19.2
ARG OTP_VERSION=27.2.4
ARG DEBIAN_VERSION=bookworm-20260316-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

# --- Build stage ---
FROM ${BUILDER_IMAGE} AS builder

ENV MIX_ENV=prod

RUN apt-get update -y && \
    apt-get install -y build-essential git && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config
COPY config/config.exs config/prod.exs config/runtime.exs config/
RUN mix deps.compile

COPY lib lib
COPY priv priv

RUN mix compile
RUN mix release

# --- Runtime stage ---
FROM ${RUNNER_IMAGE}

ENV MIX_ENV=prod

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app
RUN useradd --system --create-home --shell /bin/sh app
USER app

COPY --from=builder --chown=app:app /app/_build/prod/rel/claptrap ./

EXPOSE 4000

CMD ["bin/claptrap", "start"]

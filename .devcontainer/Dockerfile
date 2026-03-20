FROM elixir:1.19.2-otp-27

RUN apt-get update && apt-get install -y \
      git \
      inotify-tools \
      postgresql-client \
    && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force && mix local.rebar --force

WORKDIR /workspace

alias Claptrap.Repo
alias Claptrap.Schemas.{Source, Sink, Subscription, Entry}

now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

# ── Sources ──────────────────────────────────────────────────────────

elixir_source =
  Repo.insert!(%Source{
    type: "rss",
    name: "Elixir Lang Blog",
    config: %{"url" => "https://elixir-lang.org/blog.xml", "poll_interval_ms" => 600_000},
    enabled: true,
    tags: ["elixir", "programming"]
  })

erlang_source =
  Repo.insert!(%Source{
    type: "rss",
    name: "Erlang/OTP News",
    config: %{"url" => "https://www.erlang.org/blog.xml", "poll_interval_ms" => 600_000},
    enabled: true,
    tags: ["erlang", "otp"]
  })

lobsters_source =
  Repo.insert!(%Source{
    type: "rss",
    name: "Lobsters – Elixir",
    config: %{"url" => "https://lobste.rs/t/elixir.rss", "poll_interval_ms" => 600_000},
    enabled: true,
    tags: ["elixir", "community"]
  })

_disabled_source =
  Repo.insert!(%Source{
    type: "rss",
    name: "Disabled Test Feed",
    config: %{"url" => "https://example.com/feed.xml", "poll_interval_ms" => 600_000},
    enabled: false,
    tags: ["test"]
  })

# ── Sinks ────────────────────────────────────────────────────────────

elixir_sink =
  Repo.insert!(%Sink{
    type: "rss_feed",
    name: "Elixir Aggregator Feed",
    config: %{
      "title" => "Claptrap – Elixir Digest",
      "link" => "http://localhost:4000/feeds/elixir",
      "description" => "Aggregated Elixir and BEAM news"
    },
    enabled: true
  })

everything_sink =
  Repo.insert!(%Sink{
    type: "rss_feed",
    name: "Everything Feed",
    config: %{
      "title" => "Claptrap – All Items",
      "link" => "http://localhost:4000/feeds/all",
      "description" => "Every entry from every source"
    },
    enabled: true
  })

_disabled_sink =
  Repo.insert!(%Sink{
    type: "rss_feed",
    name: "Disabled Sink",
    config: %{
      "title" => "Disabled",
      "link" => "http://localhost:4000/feeds/disabled",
      "description" => "Inactive sink for testing"
    },
    enabled: false
  })

# ── Subscriptions ────────────────────────────────────────────────────

Repo.insert!(%Subscription{sink_id: elixir_sink.id, tags: ["elixir"]})
Repo.insert!(%Subscription{sink_id: everything_sink.id, tags: ["elixir", "erlang", "otp", "community"]})

# ── Sample entries ───────────────────────────────────────────────────

Repo.insert!(%Entry{
  source_id: elixir_source.id,
  external_id: "seed-elixir-1",
  title: "Elixir v1.19 Released",
  summary: "The latest Elixir release brings set-theoretic types and more.",
  url: "https://elixir-lang.org/blog/2026/01/15/elixir-v1-19-released/",
  author: "Jose Valim",
  published_at: DateTime.add(now, -3, :day),
  status: "unread",
  tags: ["elixir", "programming"]
})

Repo.insert!(%Entry{
  source_id: erlang_source.id,
  external_id: "seed-erlang-1",
  title: "OTP 27 Highlights",
  summary: "A walkthrough of the major changes shipping in OTP 27.",
  url: "https://www.erlang.org/blog/otp-27-highlights/",
  author: "Erlang Team",
  published_at: DateTime.add(now, -5, :day),
  status: "read",
  tags: ["erlang", "otp"]
})

Repo.insert!(%Entry{
  source_id: lobsters_source.id,
  external_id: "seed-lobsters-1",
  title: "Building a Feed Aggregator with GenStage",
  summary: "Community post on real-time feed processing in Elixir.",
  url: "https://lobste.rs/s/abc123",
  author: "lobsters_user",
  published_at: DateTime.add(now, -1, :day),
  status: "unread",
  tags: ["elixir", "community"]
})

IO.puts("Seeds inserted: 4 sources, 3 sinks, 2 subscriptions, 3 entries")

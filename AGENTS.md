# Agent Development Guide for Claptrap

This file explains how an autonomous coding agent should work in this repository once the Elixir/Mix project skeleton exists.

## Purpose

Claptrap should be easy for an agent to explore, change, validate, and repair in short feedback loops. The guiding idea is close to Factory's "Droid" model: agents are most effective when they share the same execution environment, project context, and verification loops as human engineers, and when the repository makes those loops explicit and fast.[^1][^2][^3]

For this repository, that means the agent should be able to:

- discover the right entrypoints quickly
- run the smallest meaningful validation command first
- make one coherent change at a time
- verify locally before proposing the next step
- avoid relying on tribal knowledge or undocumented shell rituals

## Agentic development loop

Use this loop by default:

1. Read the relevant architecture or domain docs before editing code.
2. Identify the smallest safe unit of change.
3. Run the narrowest command that validates the intended change.
4. Only widen to broader checks after the narrow check passes.
5. Prefer deterministic local feedback over speculative reasoning.
6. If a command fails, fix the underlying issue before proceeding.

In practice, the loop should look like:

1. Inspect the target module and adjacent tests.
2. Edit code.
3. Run formatter.
4. Run targeted tests.
5. Run broader test suite or project checks if the change crosses subsystem boundaries.
6. Summarize what changed, how it was verified, and any remaining risk.

## Environment assumptions

An agent working in this repository should assume:

- Elixir and Erlang are installed, matching the versions in `.tool-versions` (currently Elixir 1.19.5-otp-28, Erlang 28.4.1). In Cursor Cloud VMs these are managed via [mise](https://mise.jdx.dev/) which reads `.tool-versions` automatically.
- PostgreSQL 16 is required. It runs locally with user `postgres` / password `postgres` on port 5432. In Cloud VMs it does not auto-start; run `sudo pg_ctlcluster 16 main start` before any database commands.
- The repository root is the working directory for all Mix commands.
- Commands must be non-interactive.
- The repository should expose a small number of canonical commands instead of expecting the agent to improvise.

## Canonical commands

These are the commands an agent should reach for first.

### Dependency and setup

```bash
mix deps.get
mix compile
```

The project uses Ecto, so the database must be running before setup:

```bash
mix ecto.create
mix ecto.migrate
```

Or use the combined alias (fetches deps, creates DB, migrates):

```bash
mix setup
```

For a clean rebuild during debugging:

```bash
mix deps.clean --all
mix deps.get
mix clean
mix compile
```

### Formatting

Always format before concluding a code change:

```bash
mix format
```

To format a specific file:

```bash
mix format path/to/file.ex path/to/file_test.exs
```

### Testing

Prefer the narrowest test command that can falsify the change.

Run one file:

```bash
mix test test/path/to/specific_test.exs
```

Run one line:

```bash
mix test test/path/to/specific_test.exs:123
```

Run failed tests from the last run:

```bash
mix test --failed
```

Run the full suite:

```bash
mix test
```

The test database must be set up separately from dev before running tests:

```bash
MIX_ENV=test mix ecto.setup
```

By default, tests exclude the `:integration` and `:e2e` tags. To include them:

```bash
mix test --include integration --include e2e
```

If the change touches database-backed code, ensure the database exists and migrations are current before running tests.

### Focused development commands

Compile without running the full test suite:

```bash
mix compile
```

Force recompilation if stale build artifacts are suspicious:

```bash
mix clean && mix compile
```

### Quality gates

Use strict mode for Credo in this project:

```bash
mix credo --strict
mix dialyzer
```

The project defines `mix check` as the full pre-merge gate (format, compile with warnings-as-errors, Credo strict, OpenAPI spec check, Dialyzer, and tests). Prefer it for final verification:

```bash
mix check
```

## Command selection strategy

Agents should optimize for turnaround time.

### When editing a single pure module

Use:

```bash
mix format path/to/file.ex path/to/file_test.exs
mix test test/path/to/file_test.exs
```

### When editing a GenServer, Supervisor, or worker lifecycle

Use:

```bash
mix format
mix test test/path/to/worker_test.exs
mix test test/path/to/integration_or_subsystem_test.exs
```

Then run broader tests for the affected subsystem.

### When editing schemas, migrations, or Ecto-backed flows

Use:

```bash
mix ecto.create
mix ecto.migrate
mix test test/path/to/schema_or_context_test.exs
```

### When editing HTTP endpoints or Plug pipelines

Use targeted endpoint tests first, then broader integration tests.

To run the app locally for manual verification:

```bash
mix run --no-halt      # starts server on http://localhost:4000
```

The API requires a Bearer token for all endpoints except `/health` and `/ready`. In dev mode the token is `dev-api-key`:

```bash
curl -H "Authorization: Bearer dev-api-key" http://localhost:4000/api/v1/sources
```

### When editing shared contracts or behaviours

Run the full suite or at least every directly affected subsystem suite. Shared contracts create high blast radius.

## Guidance specific to Elixir and OTP

### Prefer process boundary clarity

When changing OTP code, verify:

- who owns the state
- which process sends which messages
- what happens on crash and restart
- whether the change preserves supervision assumptions
- whether retry and timer behavior remain bounded

### Avoid hidden global state

Keep configuration explicit. Avoid introducing process dictionary usage, implicit application env reads deep in domain logic, or test-only behavior that changes production semantics.

### Keep tests deterministic

Agent-written tests should avoid unnecessary sleeps. Prefer explicit message assertions, mailbox observation, controlled timers, and dependency injection over timing guesses.

### Do not widen scope casually

If a task starts in a consumer adapter, do not refactor unrelated producer or API code unless required for correctness. Agents tend to over-rotate into cleanup; resist that unless the cleanup is directly coupled to the change.

## Failure handling for agents

If validation fails:

1. Read the exact failure.
2. Determine whether it is caused by the current change, pre-existing repo state, missing setup, or flaky infrastructure.
3. Fix the direct cause first.
4. Re-run the smallest command that demonstrates the fix.
5. Only then resume the broader loop.

Agents should not claim success based on compilation alone when behavior changed. Likewise, they should not run the entire suite first when a single targeted test would have exposed the problem faster.

### Known harmless warnings

- The `inotifywait` backend warning (`backend port not found: :inotifywait`) during tests comes from the `fs` dependency and does not affect results. It can be ignored.

### Setup notes

- `mix setup` also sets the git hooks path to `priv/hooks`. This is safe to run but not required for Cloud agents — the pre-commit hook runs format, Credo, OpenAPI check, and Dialyzer.
- The test database is independent from the dev database. Always run `MIX_ENV=test mix ecto.setup` before running `mix test` for the first time in a new environment.

## What good agent readiness looks like in this repository

This repository is agent-ready when:

- setup steps are documented and reproducible
- format and test commands are obvious
- subsystem boundaries map to directory structure
- the smallest useful validation command is easy to infer
- architecture docs explain why the code is shaped the way it is
- common failure modes are captured in docs rather than chat history

## Expectations for future repository wiring

Once the Elixir application exists, the repository should add or standardize:

- a `mix check` alias for the normal pre-merge validation path
- reproducible database setup commands
- test helpers for worker, adapter, and endpoint tests
- fast targeted tests for each subsystem
- clear documentation for any required environment variables

That work belongs in early project scaffolding because it improves both human and agent execution quality from the start.

## Factory Configuration

Refer to these Factory-specific files for additional
context:

- `.factory/memories.md` — architecture decisions
  and project history
- `.factory/rules/elixir.md` — Elixir and OTP
  conventions
- `.factory/rules/testing.md` — testing conventions
- `.factory/rules/security.md` — security
  requirements

[^1]: https://factory.ai/news/factory-is-ga

[^2]: https://factory.ai/product/ide

[^3]: https://factory.ai/news/agent-readiness

# Contributing to Claptrap

## Prerequisites

- **Elixir** ~> 1.17
- **Erlang/OTP** 28+
- **PostgreSQL** running locally on port 5432 with a `postgres` role (password `postgres`)

## Setup

```bash
mix setup
```

This fetches dependencies, creates the database, and runs migrations. See the [README](README.md) for individual commands.

## Development Workflow

1. Create a feature branch off `main`.
2. Make your changes.
3. Run `mix check` before pushing. This runs formatting, compilation (warnings-as-errors), Credo (strict), and the test suite in sequence.
4. Open a pull request.

### Useful Commands

| Command                        | Purpose                                  |
| ------------------------------ | ---------------------------------------- |
| `mix compile`                  | Compile the project                      |
| `mix format`                   | Auto-format all source files             |
| `mix format --check-formatted` | Verify formatting without changes        |
| `mix credo --strict`           | Static analysis / linting                |
| `mix test`                     | Run the full test suite                  |
| `mix test path/to/test.exs:42` | Run a single test by file and line       |
| `mix check`                    | Full pre-merge validation gate           |
| `mix ecto.migrate`             | Run pending database migrations          |
| `mix ecto.reset`               | Drop, recreate, and migrate the database |

## Project Structure

### `config/`

Compile-time and runtime configuration, split by environment. `config.exs` loads shared defaults and imports the file for the current Mix environment (`dev.exs`, `test.exs`, `prod.exs`). `runtime.exs` runs at boot and reads environment variables -- this is where production database config lives so it isn't baked in at compile time.

Add new config keys to `config.exs` and override per-environment only where necessary.

### `lib/`

All application source code. `lib/claptrap.ex` is the root module; everything else lives under `lib/claptrap/`.

- **`application.ex`** defines the supervision tree. Children start in order: Repo, Registry, PubSub, Bandit. Add new supervised processes here.
- **`repo.ex`** is the Ecto repo. All database queries go through `Claptrap.Repo`.
- **`api/router.ex`** is the Plug router for HTTP endpoints. Currently serves `/health`.

New subsystems should be added as sibling directories under `lib/claptrap/` (e.g. `lib/claptrap/consumer/`).

### `priv/`

OTP private application data -- contents are available at runtime via `:code.priv_dir(:claptrap)` and are included in releases. Currently holds Ecto migrations under `priv/repo/migrations/`. Generate new ones with `mix ecto.gen.migration <name>`. Never rename or reorder migration files after they have been merged.

Static assets, seed data, or other files needed at runtime also belong here.

### `test/`

Test files mirror the structure of `lib/` with a `_test.exs` suffix. For example, tests for `lib/claptrap/api/router.ex` go in `test/claptrap/api/router_test.exs`. `test_helper.exs` runs once before the suite to start ExUnit and any global test setup.

### `docs/`

Hand-written project documentation (architecture, glossary, domain references). This is separate from generated API docs. Update or add to this directory when making significant architectural changes.

## Code Style

- Run `mix format` before committing. The project uses a 120-character line length.
- All modules should have a `@moduledoc` tag (use `@moduledoc false` for purely internal modules).
- `mix credo --strict` enforces static analysis rules. Fix all issues before opening a PR.

## Database Changes

1. Generate a migration: `mix ecto.gen.migration <descriptive_name>`
2. Edit the generated file in `priv/repo/migrations/`.
3. Run `mix ecto.migrate` to apply it.
4. Run `mix ecto.reset` if you need a clean slate.

Never edit or rename a migration that has already been merged to `main`.

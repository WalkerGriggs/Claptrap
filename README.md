# Claptrap

A personal router for your information diet. Claptrap monitors your favorite sources, normalizes each entry into an aggregated store, and routes the content back to your preferred format.

## Quicklinks

- [CONTRIBUTING.md](CONTRIBUTING.md) for testing, formatting, linting, and the full development workflow.
- [Architecture](docs/architecture/) - Core terminology and system designs
- [Gloassary](docs/glossary.md) - Quick explanations of all the core concepts.

## Getting Started

**Prerequisites**: Elixir ~> 1.17, Erlang/OTP 28+, PostgreSQL on port 5432.

```bash
mix setup              # fetch deps, create database, run migrations
mix run --no-halt      # start the server on http://localhost:4000
```


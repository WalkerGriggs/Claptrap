# Elixir Conventions — Claptrap

## General
- Always run `mix format` before concluding a change
- Use `mix credo` and `mix dialyzer` when available
- Prefer `mix check` alias for final verification
  if defined

## Modules and Naming
- Subsystem modules live under their namespace:
  `Claptrap.Consumer.*`, `Claptrap.Producer.*`, etc.
- Adapter implementations go in
  `consumer/adapters/` or `producer/adapters/`
- Ecto schemas live in `lib/claptrap/schemas/`
- HTTP handlers live in `lib/claptrap/api/handlers/`

## OTP Patterns
- One GenServer worker per source or sink
- Prefer explicit message passing over implicit
  process dictionary state
- Keep configuration explicit; avoid deep app env
  reads in domain logic
- Verify process ownership, message flow, crash
  behavior, and supervision assumptions on every
  OTP change

## Error Handling
- Wrong state → raise and crash (supervisor restarts)
- Incomplete data → heal with defaults, continue
- Transient failures → return {:error, reason},
  retry with backoff
- Retry: 500ms * 2^attempt + jitter, max 30s,
  max 5 attempts

## Adapters
- Consumer adapters implement Consumer.Adapter
  behaviour (mode/0, fetch/1, ingest/2,
  validate_config/1)
- Producer adapters implement Producer.Adapter
  behaviour (mode/0, push/2, materialize/2,
  validate_config/1)
- Adapters own protocol-specific logic; Catalog
  owns persistence

## Database
- Use Ecto changesets for validation
- Deduplication via on_conflict: :nothing with
  [:external_id, :source_id]
- JSONB for adapter-specific config; validated by
  adapter's validate_config/1
- Credentials encrypted via Cloak.Ecto

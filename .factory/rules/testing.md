# Testing Conventions — Claptrap

## Command Selection
- Single pure module: `mix test test/path/to/file_test.exs`
- GenServer/worker changes: targeted test, then
  subsystem integration tests
- Schema/Ecto changes: ensure DB setup first, then
  `mix test test/path/to/schema_test.exs`
- Shared contracts/behaviours: run full suite
  (high blast radius)

## Test Organization
- Tests mirror lib/ structure under test/
- Prefer narrowest test that falsifies the change
- Run `mix test --failed` to re-run failures

## Test Quality
- Avoid unnecessary sleeps; prefer explicit message
  assertions and mailbox observation
- Use controlled timers and dependency injection
  over timing guesses
- Keep tests deterministic
- Mock at boundaries (external HTTP, APIs), not
  internal modules

## Database Tests
- Ensure `mix ecto.create && mix ecto.migrate`
  before running DB-backed tests
- Use Ecto sandbox for test isolation

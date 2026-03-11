# Configuration and Secrets

This document covers how Claptrap handles environment-specific configuration, bootstrap state, and encrypted credentials.

## Configuration Files

- `file 'Claptrap/config/config.exs'`: shared compile-time configuration
- `file 'Claptrap/config/dev.exs'`: development overrides
- `file 'Claptrap/config/test.exs'`: test overrides
- `file 'Claptrap/config/prod.exs'`: production overrides
- `file 'Claptrap/config/runtime.exs'`: runtime configuration loaded from environment variables

## Compile-Time vs Runtime Configuration

The critical rule in the architecture is that secrets and environment-dependent values belong in runtime configuration.

Use `runtime.exs` for:

- database URL
- encryption keys
- API secrets
- other deployment-specific credentials

Because these are read at boot rather than compile time, the same release artifact can be reused across environments simply by changing environment variables.

## Bootstrap Strategy

Initial source and sink definitions should be seeded through operational workflows, not static configuration files.

Recommended mechanisms:

- a mix task such as `mix claptrap.seed`
- the API itself

Explicitly discouraged:

- static config files that duplicate source or sink definitions

The reason is straightforward: a static file would create a split-brain source of truth between configuration files and the database.

## Credential Storage

Source and sink configurations may include API keys, OAuth tokens, and webhook secrets. These are stored encrypted at rest using **Cloak.Ecto**.

## Claptrap.Vault

`Claptrap.Vault` is a GenServer that manages encryption keys and is started early in the supervision tree.

Ecto schemas are configured to transparently encrypt and decrypt JSONB credential fields on read and write.

## Key Management

The encryption key is expected to come from an environment variable such as `CLAPTRAP_VAULT_KEY`.

In production, the document recommends storing that secret in a proper secrets manager such as:

- AWS Secrets Manager
- HashiCorp Vault
- an equivalent secret distribution mechanism

## Design Intent

The architecture is drawing a clean line:

- topology and content state live in PostgreSQL
- secret material is encrypted at rest
- deployment-specific values are injected at runtime

That is the right split for a system intended to ship as a release artifact across multiple environments.

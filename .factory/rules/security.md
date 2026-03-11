# Security Conventions — Claptrap

## Credentials
- Never log or expose credentials in plaintext
- All credentials stored encrypted at rest via
  Cloak.Ecto (Claptrap.Vault)
- Encryption key injected at runtime via
  CLAPTRAP_VAULT_KEY env var
- Production keys belong in a secrets manager
  (AWS Secrets Manager, HashiCorp Vault, etc.)

## Configuration
- Secrets and env-dependent values go in
  config/runtime.exs only
- Never commit secrets to static config files
- Same release artifact across environments;
  only env vars change

## HTTP/API
- Webhook receivers must verify/authenticate
  requests before processing
- API endpoints use API key auth
  (Claptrap.API.Auth plug)
- Return 2xx quickly from webhook receivers;
  do real work asynchronously

## Data Handling
- JSONB config validated by adapter
  validate_config/1 before storage
- Entry deduplication prevents injection of
  duplicate content

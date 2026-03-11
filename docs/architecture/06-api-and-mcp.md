# API and MCP

Claptrap exposes two external interfaces over the same underlying domain model: a conventional HTTP API and an MCP interface for AI agents.

## API: External HTTP Interface

The API subsystem provides the external HTTP interface to Claptrap.

### Plug Router + Bandit Server

The HTTP layer is implemented as a **Plug** application and served by **Bandit**.

That HTTP layer provides:

- **REST API** for CRUD operations on sources, sinks, entries, and subscriptions, all backed by the Catalog
- **Webhook receivers** for push-based source integrations such as GitHub webhooks or Zapier
- **Pull sink endpoints** that serve materialized sink representations such as RSS XML
- **MCP transport endpoints** for HTTP/SSE-based agent integration

### Why Plug + Bandit

Plug keeps the request/response boundary explicit and small. Bandit provides a modern BEAM-native HTTP server without introducing Phoenix web-layer conventions that Claptrap does not need.

This fits the overall architecture: Claptrap is an OTP system first, with HTTP as an adapter at the edge.

## REST Endpoints

```markdown
Entries:
  GET    /api/v1/entries              - List entries (paginated, filterable)
  GET    /api/v1/entries/{id}         - Get single entry
  PATCH  /api/v1/entries/{id}         - Update entry (read status, tags, etc.)

Sources:
  GET    /api/v1/sources              - List sources
  POST   /api/v1/sources              - Create source
  PATCH  /api/v1/sources/{id}         - Update source
  DELETE /api/v1/sources/{id}         - Delete source
  POST   /api/v1/sources/{id}/consume - Trigger consumption

Sinks:
  GET    /api/v1/sinks                - List sinks
  POST   /api/v1/sinks                - Create sink
  PATCH  /api/v1/sinks/{id}           - Update sink
  DELETE /api/v1/sinks/{id}           - Delete sink

Subscriptions:
  GET    /api/v1/subscriptions        - List subscriptions
  POST   /api/v1/subscriptions        - Create subscription
  DELETE /api/v1/subscriptions/{id}   - Remove subscription
```

## Webhook Receivers and Pull Sink Endpoints

Push-based sources terminate at the HTTP layer, but the HTTP layer should do minimal work:

1. verify or authenticate the request
2. identify the `source_id`
3. enqueue consumption into the corresponding `Consumer.Worker`
4. return 2xx quickly

Parsing, normalization, deduplication, persistence, and downstream event emission remain the Consumer's responsibility.

For pull sinks, the HTTP layer exposes endpoints that serve materialized artifacts, such as generated RSS feeds.

## MCP: AI Agent Interface

The MCP server bridges AI agents to Claptrap's API and domain functions.

### Claptrap.MCP.Server

`Claptrap.MCP.Server` is a GenServer that speaks the Model Context Protocol for AI agent integration.

### Transport

The chosen transport is:

- **HTTP/SSE via the Plug interface**

HTTP/SSE is preferred because it avoids requiring Claptrap to run as a subprocess of the AI client.

### Capabilities

The MCP layer can:

- query entries with structured filters
- mark entries as read or archived
- trigger consumption and run consumers
- browse catalog resources

## Single Data Path Principle

The MCP server routes requests to the same Catalog and domain functions that the REST API uses. It is not a distinct backend. It is an alternative interface to the same system.

That is an important architectural choice because it prevents feature drift between human-facing and agent-facing control planes.

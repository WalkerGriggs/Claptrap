# RSS

A self-contained RSS 2.0 library for parsing, generating, and
validating feeds. This is a general-purpose library with no
dependencies on the rest of Claptrap — it models the RSS 2.0
specification as Elixir structs and provides a clean
parse/generate/validate pipeline.

## Architecture

```
XML binary ──▶ Parser ──▶ Feed struct ──▶ Validator
                                │
                                ▼
                           Generator ──▶ XML binary
```

The facade module `Claptrap.RSS` (in `../rss.ex`) exposes the
public API: `parse/2`, `generate/2`, `validate/1`, plus bang
variants.

## Key concepts

Every RSS element is represented as a typed struct with enforced
keys matching the spec's required fields. `Feed` and `Item`
provide a builder API (`put_*/2`, `add_*/2`) for pipeline-style
construction:

```elixir
Feed.new("Title", "https://example.com", "A feed")
|> Feed.put_language("en-us")
|> Feed.add_category(Category.new("tech"))
|> Feed.add_item(Item.new(title: "Hello"))
```

No validation happens in builders — that is deferred to
generate-time or explicit `validate/1` calls.

**Parsing** uses `:xmerl` by default but accepts a pluggable XML
backend via the `:xml_backend` option. Strict mode surfaces
missing required fields and malformed dates as `ParseError`s;
lenient mode (default) silently drops them. camelCase XML tag
names are normalized to snake_case struct fields via a
compile-time map.

**Generation** builds the entire XML document as iodata (no
intermediate string concatenation) and collapses once at the end.
Wraps text in `<![CDATA[...]]>` only when it contains `<` or
`&`; falls back to entity escaping if the text itself contains
`]]>`.

**Validation** returns `:ok` or `{:error, [ValidationError.t()]}`
— reports all errors at once (not fail-fast). Checks required
fields, URL formats, numeric ranges, value enumerations, and
duplicates.

**Date handling** tries four strategies in sequence: RFC 822,
ISO 8601, full month names ("October 4, 2007"), and Unix
timestamps. All parsed dates are normalized to UTC. The date
module is pluggable via a behaviour for testing.

## Notes

- The parser converts raw bytes via `:binary.bin_to_list/1`
  (not `String.to_charlist/1`) to avoid xmerl rejecting
  codepoints above 127.
- For scalar elements, the parser uses `Map.put_new/3` so only
  the first occurrence of a duplicate element wins.
- Extensions are keyed by namespace URI (not prefix), so
  different prefixes pointing to the same namespace are treated
  identically.
- Error types: `ParseError` (reason, line, column),
  `GenerateError` (reason, path), `ValidationError` (message,
  path, rule).

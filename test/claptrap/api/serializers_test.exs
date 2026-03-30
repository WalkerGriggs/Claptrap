defmodule Claptrap.API.SerializersTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Claptrap.API.Serializers
  alias Claptrap.Catalog.{Artifact, Entry, Sink, Source, Subscription}

  @source_keys ~w(id type name config enabled tags last_consumed_at inserted_at updated_at)a
  @sink_keys ~w(id type name config enabled inserted_at updated_at)a
  @entry_keys ~w(id external_id title summary url author published_at status metadata tags source_id inserted_at updated_at)a
  @subscription_keys ~w(id sink_id tags inserted_at updated_at)a
  @artifact_keys ~w(id entry_id format content content_type byte_size extractor metadata inserted_at updated_at)a

  # -- Generators --------------------------------------------------------

  defp uuid_gen, do: constant(Ecto.UUID.generate())

  # ~2020-01-01 to ~2030-01-01 in microseconds
  @min_us DateTime.to_unix(~U[2020-01-01 00:00:00Z], :microsecond)
  @max_us DateTime.to_unix(~U[2030-01-01 00:00:00Z], :microsecond)

  defp datetime_gen do
    map(integer(@min_us..@max_us), &DateTime.from_unix!(&1, :microsecond))
  end

  defp maybe(gen), do: frequency([{1, constant(nil)}, {3, gen}])

  defp map_gen do
    gen all(
          pairs <-
            list_of(
              tuple(
                {string(:alphanumeric, min_length: 1, max_length: 50),
                 string(:alphanumeric, min_length: 1, max_length: 50)}
              ),
              max_length: 3
            )
        ) do
      Map.new(pairs)
    end
  end

  defp source_gen do
    gen all(
          id <- uuid_gen(),
          type <- string(:alphanumeric, min_length: 1, max_length: 50),
          name <- string(:alphanumeric, min_length: 1, max_length: 50),
          config <- map_gen(),
          credentials <- maybe(map_gen()),
          enabled <- boolean(),
          tags <- list_of(string(:alphanumeric, min_length: 1, max_length: 50), max_length: 5),
          last_consumed_at <- maybe(datetime_gen()),
          inserted_at <- datetime_gen(),
          updated_at <- datetime_gen()
        ) do
      %Source{
        id: id,
        type: type,
        name: name,
        config: config,
        credentials: credentials,
        enabled: enabled,
        tags: tags,
        last_consumed_at: last_consumed_at,
        inserted_at: inserted_at,
        updated_at: updated_at
      }
    end
  end

  defp sink_gen do
    gen all(
          id <- uuid_gen(),
          type <- string(:alphanumeric, min_length: 1, max_length: 50),
          name <- string(:alphanumeric, min_length: 1, max_length: 50),
          config <- map_gen(),
          credentials <- maybe(map_gen()),
          enabled <- boolean(),
          inserted_at <- datetime_gen(),
          updated_at <- datetime_gen()
        ) do
      %Sink{
        id: id,
        type: type,
        name: name,
        config: config,
        credentials: credentials,
        enabled: enabled,
        inserted_at: inserted_at,
        updated_at: updated_at
      }
    end
  end

  defp entry_gen do
    gen all(
          id <- uuid_gen(),
          external_id <- string(:alphanumeric, min_length: 1, max_length: 50),
          title <- string(:alphanumeric, min_length: 1, max_length: 50),
          summary <- maybe(string(:alphanumeric, min_length: 1, max_length: 50)),
          url <- maybe(string(:alphanumeric, min_length: 1, max_length: 50)),
          author <- maybe(string(:alphanumeric, min_length: 1, max_length: 50)),
          published_at <- maybe(datetime_gen()),
          status <- member_of(["unread", "in_progress", "read", "archived"]),
          metadata <- maybe(map_gen()),
          tags <- list_of(string(:alphanumeric, min_length: 1, max_length: 50), max_length: 5),
          source_id <- uuid_gen(),
          inserted_at <- datetime_gen(),
          updated_at <- datetime_gen()
        ) do
      %Entry{
        id: id,
        external_id: external_id,
        title: title,
        summary: summary,
        url: url,
        author: author,
        published_at: published_at,
        status: status,
        metadata: metadata,
        tags: tags,
        source_id: source_id,
        inserted_at: inserted_at,
        updated_at: updated_at
      }
    end
  end

  defp subscription_gen do
    gen all(
          id <- uuid_gen(),
          sink_id <- uuid_gen(),
          tags <- list_of(string(:alphanumeric, min_length: 1, max_length: 50), max_length: 5),
          inserted_at <- datetime_gen(),
          updated_at <- datetime_gen()
        ) do
      %Subscription{
        id: id,
        sink_id: sink_id,
        tags: tags,
        inserted_at: inserted_at,
        updated_at: updated_at
      }
    end
  end

  defp artifact_gen do
    gen all(
          id <- uuid_gen(),
          entry_id <- uuid_gen(),
          format <- member_of(["markdown", "html", "pdf"]),
          content <- maybe(string(:alphanumeric, min_length: 1, max_length: 200)),
          content_type <- maybe(string(:alphanumeric, min_length: 1, max_length: 50)),
          byte_size <- maybe(positive_integer()),
          extractor <- string(:alphanumeric, min_length: 1, max_length: 50),
          metadata <- maybe(map_gen()),
          inserted_at <- datetime_gen(),
          updated_at <- datetime_gen()
        ) do
      %Artifact{
        id: id,
        entry_id: entry_id,
        format: format,
        content: content,
        content_type: content_type,
        byte_size: byte_size,
        extractor: extractor,
        metadata: metadata,
        inserted_at: inserted_at,
        updated_at: updated_at
      }
    end
  end

  # -- Properties --------------------------------------------------------

  describe "Source serialization" do
    property "produces exactly the expected keys" do
      check all(source <- source_gen()) do
        result = Serializers.serialize(source)
        assert Map.keys(result) |> Enum.sort() == Enum.sort(@source_keys)
      end
    end

    property "preserves all field values" do
      check all(source <- source_gen()) do
        result = Serializers.serialize(source)

        for key <- @source_keys do
          assert Map.fetch!(result, key) == Map.fetch!(source, key)
        end
      end
    end

    property "never includes credentials" do
      check all(source <- source_gen()) do
        result = Serializers.serialize(source)
        refute Map.has_key?(result, :credentials)
      end
    end
  end

  describe "Sink serialization" do
    property "produces exactly the expected keys" do
      check all(sink <- sink_gen()) do
        result = Serializers.serialize(sink)
        assert Map.keys(result) |> Enum.sort() == Enum.sort(@sink_keys)
      end
    end

    property "preserves all field values" do
      check all(sink <- sink_gen()) do
        result = Serializers.serialize(sink)

        for key <- @sink_keys do
          assert Map.fetch!(result, key) == Map.fetch!(sink, key)
        end
      end
    end

    property "never includes credentials" do
      check all(sink <- sink_gen()) do
        result = Serializers.serialize(sink)
        refute Map.has_key?(result, :credentials)
      end
    end
  end

  describe "Entry serialization" do
    property "produces exactly the expected keys" do
      check all(entry <- entry_gen()) do
        result = Serializers.serialize(entry)
        assert Map.keys(result) |> Enum.sort() == Enum.sort(@entry_keys)
      end
    end

    property "preserves all field values" do
      check all(entry <- entry_gen()) do
        result = Serializers.serialize(entry)

        for key <- @entry_keys do
          assert Map.fetch!(result, key) == Map.fetch!(entry, key)
        end
      end
    end
  end

  describe "Subscription serialization" do
    property "produces exactly the expected keys" do
      check all(subscription <- subscription_gen()) do
        result = Serializers.serialize(subscription)
        assert Map.keys(result) |> Enum.sort() == Enum.sort(@subscription_keys)
      end
    end

    property "preserves all field values" do
      check all(subscription <- subscription_gen()) do
        result = Serializers.serialize(subscription)

        for key <- @subscription_keys do
          assert Map.fetch!(result, key) == Map.fetch!(subscription, key)
        end
      end
    end
  end

  describe "Artifact serialization" do
    property "produces exactly the expected keys" do
      check all(artifact <- artifact_gen()) do
        result = Serializers.serialize(artifact)
        assert Map.keys(result) |> Enum.sort() == Enum.sort(@artifact_keys)
      end
    end

    property "preserves all field values" do
      check all(artifact <- artifact_gen()) do
        result = Serializers.serialize(artifact)

        for key <- @artifact_keys do
          assert Map.fetch!(result, key) == Map.fetch!(artifact, key)
        end
      end
    end
  end
end

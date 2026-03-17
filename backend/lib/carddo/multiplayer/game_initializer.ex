defmodule Carddo.Multiplayer.GameInitializer do
  @moduledoc """
  Assembles the initial `GameState` JSON from a game's config and player decks.

  Intended caller: `GameChannel.join/3` (CAR-37) when no session checkpoint exists.
  Output JSON matches the canonical `GameState` struct from `ditto_core/src/state.rs`.
  """

  alias Carddo.Games

  @valid_visibilities ~w(Hidden OwnerOnly Public)
  @valid_stack_orders ~w(Fifo Lifo)

  @doc """
  Builds initial `GameState` JSON from a game's config and player decks.

  `players` is a list of `{player_id, deck_id}` tuples.
  Returns `{:ok, json_string}` or `{:error, reason}`.
  """
  @spec build(game_id :: integer(), players :: [{String.t(), integer()}]) ::
          {:ok, String.t()} | {:error, String.t()}
  def build(game_id, players) when is_list(players) do
    with :ok <- validate_players(players),
         {:ok, game} <- fetch_game(game_id),
         {:ok, config} <- validate_config(game.config),
         {:ok, starting_zone} <- validate_starting_zone(config),
         {:ok, decks} <- load_and_validate_decks(game_id, players) do
      game_state = assemble_state(config, starting_zone, players, decks)
      {:ok, Jason.encode!(game_state)}
    end
  end

  # ── Fetching & Validation ───────────────────────────────────────────────

  defp validate_players([]), do: {:error, "At least one player is required"}

  defp validate_players(players) do
    player_ids = Enum.map(players, fn {id, _} -> id end)

    cond do
      Enum.any?(player_ids, &(!is_binary(&1) or &1 == "")) ->
        {:error, "All player IDs must be non-empty strings"}

      length(player_ids) != length(Enum.uniq(player_ids)) ->
        {:error, "Duplicate player IDs are not allowed"}

      true ->
        :ok
    end
  end

  defp fetch_game(game_id) do
    case Games.get_game(game_id) do
      nil -> {:error, "Game not found"}
      game -> {:ok, game}
    end
  end

  defp validate_config(config) when is_map(config) do
    case config do
      %{"zones" => zones} when is_list(zones) and zones != [] ->
        with {:ok, config} <- validate_zone_defs(zones, config) do
          validate_stack_order(config)
        end

      _ ->
        {:error, "Game config must have at least one zone defined"}
    end
  end

  defp validate_config(_), do: {:error, "Game config is invalid"}

  defp validate_zone_defs(zones, config) do
    if Enum.any?(zones, &(!is_map(&1))) do
      {:error, "Each zone definition must be a map"}
    else
      names = Enum.map(zones, & &1["name"])
      visibilities = Enum.map(zones, & &1["visibility"])

      cond do
        Enum.any?(names, &(!is_binary(&1) or &1 == "")) ->
          {:error, "All zones must have a non-empty string name"}

        length(names) != length(Enum.uniq(names)) ->
          {:error, "Duplicate zone names are not allowed"}

        bad = Enum.find(visibilities, &(&1 != nil and &1 not in @valid_visibilities)) ->
          {:error,
           "Unknown visibility #{inspect(bad)}, expected one of: #{Enum.join(@valid_visibilities, ", ")}"}

        true ->
          {:ok, config}
      end
    end
  end

  defp validate_stack_order(%{"stack_order" => order} = config) when is_binary(order) do
    if order in @valid_stack_orders do
      {:ok, config}
    else
      {:error,
       "Unknown stack_order #{inspect(order)}, expected one of: #{Enum.join(@valid_stack_orders, ", ")}"}
    end
  end

  defp validate_stack_order(config), do: {:ok, config}

  defp validate_starting_zone(config) do
    starting_zone = config["starting_zone"] || "Deck"
    zone_names = Enum.map(config["zones"], & &1["name"])

    if starting_zone in zone_names do
      {:ok, starting_zone}
    else
      {:error, "No #{starting_zone} zone defined in game config"}
    end
  end

  defp load_and_validate_decks(game_id, players) do
    result =
      Enum.reduce_while(players, [], fn {player_id, deck_id}, acc ->
        case load_deck(game_id, deck_id) do
          {:ok, deck} -> {:cont, [{player_id, deck} | acc]}
          {:error, _} = err -> {:halt, err}
        end
      end)

    case result do
      {:error, _} = err -> err
      decks when is_list(decks) -> {:ok, Enum.reverse(decks)}
    end
  end

  defp load_deck(game_id, deck_id) do
    try do
      deck = Games.get_deck_with_cards(deck_id)

      cond do
        deck.game_id != game_id ->
          {:error, "Deck #{deck_id} does not belong to game #{game_id}"}

        deck.deck_cards == [] ->
          {:error, "Deck #{deck_id} has no cards"}

        true ->
          {:ok, deck}
      end
    rescue
      Ecto.NoResultsError -> {:error, "Deck #{deck_id} not found"}
    end
  end

  # ── State Assembly ──────────────────────────────────────────────────────

  defp assemble_state(config, starting_zone, players, decks) do
    {entities, zone_assignments} = build_entities(decks)
    zones = build_zones(config, players, starting_zone, zone_assignments)
    zone_names = Enum.map(config["zones"], & &1["name"])

    %{
      "entities" => entities,
      "zones" => zones,
      "event_queue" => [],
      "pending_animations" => [],
      "stack_order" => config["stack_order"] || "Fifo",
      "state_checks" => rewrite_state_checks(config["state_checks"] || [], zone_names),
      "turn_ended" => false
    }
  end

  defp build_entities(decks) do
    expanded =
      Enum.flat_map(decks, fn {player_id, deck} ->
        Enum.flat_map(deck.deck_cards, fn dc ->
          for _ <- 1..dc.quantity do
            entity_id = Ecto.UUID.generate()

            entity = %{
              "id" => entity_id,
              "owner_id" => player_id,
              "template_id" => to_string(dc.card.id),
              "properties" => normalize_properties(dc.card.properties),
              "abilities" => dc.card.abilities || []
            }

            {entity_id, entity, player_id}
          end
        end)
      end)

    entities = Map.new(expanded, fn {id, entity, _player_id} -> {id, entity} end)

    zone_assignments =
      expanded
      |> Enum.group_by(fn {_id, _entity, player_id} -> player_id end)
      |> Map.new(fn {player_id, entries} ->
        entity_ids = entries |> Enum.map(fn {id, _, _} -> id end) |> Enum.shuffle()
        {player_id, entity_ids}
      end)

    {entities, zone_assignments}
  end

  defp build_zones(config, players, starting_zone, zone_assignments) do
    zone_defs = config["zones"]

    players
    |> Enum.flat_map(fn {player_id, _deck_id} ->
      Enum.map(zone_defs, fn zone_def ->
        zone_name = zone_def["name"]
        zone_id = "#{player_id}_#{zone_name}"

        entity_ids =
          if zone_name == starting_zone do
            Map.get(zone_assignments, player_id, [])
          else
            []
          end

        visibility = map_visibility(zone_def["visibility"], length(entity_ids))

        {zone_id,
         %{
           "id" => zone_id,
           "owner_id" => player_id,
           "visibility" => visibility,
           "entities" => entity_ids
         }}
      end)
    end)
    |> Map.new()
  end

  defp rewrite_state_checks(checks, zone_names) do
    Enum.map(checks, fn check ->
      case check do
        %{"move_to_zone" => zone} when is_binary(zone) ->
          if zone in zone_names do
            Map.put(check, "move_to_zone", "$owner_#{zone}")
          else
            check
          end

        _ ->
          check
      end
    end)
  end

  defp map_visibility("Hidden", count), do: %{"Hidden" => count}
  defp map_visibility("OwnerOnly", _count), do: "OwnerOnly"
  defp map_visibility("Public", _count), do: "Public"
  defp map_visibility(nil, _count), do: "Public"

  defp normalize_properties(props) when is_map(props) do
    Map.new(props, fn {key, value} -> {to_string(key), trunc_value(value)} end)
  end

  defp normalize_properties(_), do: %{}

  defp trunc_value(v) when is_integer(v), do: v
  defp trunc_value(v) when is_float(v), do: trunc(v)
  defp trunc_value(_), do: 0
end

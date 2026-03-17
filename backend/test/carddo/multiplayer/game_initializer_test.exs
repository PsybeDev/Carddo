defmodule Carddo.Multiplayer.GameInitializerTest do
  use Carddo.DataCase, async: true

  alias Carddo.{Card, Deck, DeckCard, Game, Repo, User}
  alias Carddo.Multiplayer.GameInitializer

  @valid_config %{
    "zones" => [
      %{"name" => "Deck", "visibility" => "Hidden"},
      %{"name" => "Hand", "visibility" => "OwnerOnly"},
      %{"name" => "Board", "visibility" => "Public"},
      %{"name" => "Graveyard", "visibility" => "Public"}
    ],
    "state_checks" => [
      %{
        "watch_property" => "Health",
        "operator" => "<=",
        "threshold" => 0,
        "move_to_zone" => "Graveyard"
      }
    ]
  }

  setup do
    {:ok, user} =
      %User{}
      |> User.changeset(%{email: "init-#{System.unique_integer([:positive])}@example.com"})
      |> Repo.insert()

    {:ok, game} =
      Ecto.build_assoc(user, :games)
      |> Game.changeset(%{title: "Test Game"})
      |> Repo.insert()

    game =
      game
      |> Game.update_changeset(%{config: @valid_config})
      |> Repo.update!()

    {:ok, card_a} =
      Ecto.build_assoc(game, :cards)
      |> Card.changeset(%{
        name: "Warrior",
        card_type: "creature",
        properties: %{"Health" => 20, "Attack" => 5}
      })
      |> Repo.insert()

    {:ok, card_b} =
      Ecto.build_assoc(game, :cards)
      |> Card.changeset(%{
        name: "Spell",
        card_type: "spell",
        properties: %{"Damage" => 10}
      })
      |> Repo.insert()

    {:ok, deck} =
      Ecto.build_assoc(game, :decks)
      |> Deck.changeset(%{name: "Starter Deck"})
      |> Repo.insert()

    Repo.insert_all(DeckCard, [
      %{deck_id: deck.id, card_id: card_a.id, quantity: 3},
      %{deck_id: deck.id, card_id: card_b.id, quantity: 2}
    ])

    %{user: user, game: game, deck: deck, card_a: card_a, card_b: card_b}
  end

  describe "build/2 success" do
    test "returns {:ok, json} that decodes to valid GameState", %{game: game, deck: deck} do
      players = [{"player_1", deck.id}]
      assert {:ok, json} = GameInitializer.build(game.id, players)
      assert {:ok, state} = Jason.decode(json)

      assert is_map(state["entities"])
      assert is_map(state["zones"])
      assert state["event_queue"] == []
      assert state["pending_animations"] == []
      assert state["stack_order"] == "Fifo"
      assert state["turn_ended"] == false
    end

    test "entity count equals total cards across decks accounting for quantity", ctx do
      players = [{"player_1", ctx.deck.id}]
      {:ok, json} = GameInitializer.build(ctx.game.id, players)
      state = Jason.decode!(json)

      assert map_size(state["entities"]) == 5
    end

    test "entities have correct structure matching Rust Entity struct", ctx do
      players = [{"player_1", ctx.deck.id}]
      {:ok, json} = GameInitializer.build(ctx.game.id, players)
      state = Jason.decode!(json)

      entity = state["entities"] |> Map.values() |> hd()

      assert Map.has_key?(entity, "id")
      assert Map.has_key?(entity, "owner_id")
      assert Map.has_key?(entity, "template_id")
      assert Map.has_key?(entity, "properties")
      assert Map.has_key?(entity, "abilities")
      assert entity["owner_id"] == "player_1"
      assert is_map(entity["properties"])
      assert is_list(entity["abilities"])
    end

    test "entity properties are integers (i32-safe)", ctx do
      players = [{"player_1", ctx.deck.id}]
      {:ok, json} = GameInitializer.build(ctx.game.id, players)
      state = Jason.decode!(json)

      Enum.each(state["entities"], fn {_id, entity} ->
        Enum.each(entity["properties"], fn {_key, value} ->
          assert is_integer(value)
        end)
      end)
    end

    test "template_id maps back to the originating card", ctx do
      players = [{"player_1", ctx.deck.id}]
      {:ok, json} = GameInitializer.build(ctx.game.id, players)
      state = Jason.decode!(json)

      template_ids =
        state["entities"]
        |> Map.values()
        |> Enum.map(& &1["template_id"])
        |> Enum.uniq()
        |> Enum.sort()

      expected = Enum.sort([to_string(ctx.card_a.id), to_string(ctx.card_b.id)])
      assert template_ids == expected
    end

    test "creates per-player zones matching config", ctx do
      players = [{"player_1", ctx.deck.id}]
      {:ok, json} = GameInitializer.build(ctx.game.id, players)
      state = Jason.decode!(json)

      zone_ids = Map.keys(state["zones"]) |> Enum.sort()

      assert zone_ids ==
               Enum.sort([
                 "player_1_Deck",
                 "player_1_Hand",
                 "player_1_Board",
                 "player_1_Graveyard"
               ])
    end

    test "zones have correct structure matching Rust Zone struct", ctx do
      players = [{"player_1", ctx.deck.id}]
      {:ok, json} = GameInitializer.build(ctx.game.id, players)
      state = Jason.decode!(json)

      zone = state["zones"]["player_1_Deck"]
      assert zone["id"] == "player_1_Deck"
      assert zone["owner_id"] == "player_1"
      assert is_list(zone["entities"])
      assert Map.has_key?(zone, "visibility")
    end

    test "deck zone contains all entity IDs", ctx do
      players = [{"player_1", ctx.deck.id}]
      {:ok, json} = GameInitializer.build(ctx.game.id, players)
      state = Jason.decode!(json)

      deck_zone = state["zones"]["player_1_Deck"]
      assert length(deck_zone["entities"]) == 5

      all_entity_ids = Map.keys(state["entities"]) |> MapSet.new()
      deck_entity_ids = MapSet.new(deck_zone["entities"])
      assert MapSet.equal?(all_entity_ids, deck_entity_ids)
    end

    test "non-deck zones start empty", ctx do
      players = [{"player_1", ctx.deck.id}]
      {:ok, json} = GameInitializer.build(ctx.game.id, players)
      state = Jason.decode!(json)

      assert state["zones"]["player_1_Hand"]["entities"] == []
      assert state["zones"]["player_1_Board"]["entities"] == []
      assert state["zones"]["player_1_Graveyard"]["entities"] == []
    end

    test "visibility maps correctly per zone type", ctx do
      players = [{"player_1", ctx.deck.id}]
      {:ok, json} = GameInitializer.build(ctx.game.id, players)
      state = Jason.decode!(json)

      assert state["zones"]["player_1_Deck"]["visibility"] == %{"Hidden" => 5}
      assert state["zones"]["player_1_Hand"]["visibility"] == "OwnerOnly"
      assert state["zones"]["player_1_Board"]["visibility"] == "Public"
      assert state["zones"]["player_1_Graveyard"]["visibility"] == "Public"
    end

    test "state_checks move_to_zone is rewritten with $owner_ prefix", ctx do
      players = [{"player_1", ctx.deck.id}]
      {:ok, json} = GameInitializer.build(ctx.game.id, players)
      state = Jason.decode!(json)

      assert length(state["state_checks"]) == 1
      check = hd(state["state_checks"])
      assert check["watch_property"] == "Health"
      assert check["operator"] == "<="
      assert check["threshold"] == 0
      assert check["move_to_zone"] == "$owner_Graveyard"
    end
  end

  describe "build/2 multiplayer" do
    test "two-player game creates separate zones per player", ctx do
      {:ok, deck_2} =
        Ecto.build_assoc(ctx.game, :decks)
        |> Deck.changeset(%{name: "Player 2 Deck"})
        |> Repo.insert()

      Repo.insert_all(DeckCard, [
        %{deck_id: deck_2.id, card_id: ctx.card_a.id, quantity: 2}
      ])

      players = [{"player_1", ctx.deck.id}, {"player_2", deck_2.id}]
      {:ok, json} = GameInitializer.build(ctx.game.id, players)
      state = Jason.decode!(json)

      assert Map.has_key?(state["zones"], "player_1_Deck")
      assert Map.has_key?(state["zones"], "player_2_Deck")
      assert Map.has_key?(state["zones"], "player_1_Hand")
      assert Map.has_key?(state["zones"], "player_2_Hand")

      assert map_size(state["entities"]) == 7
    end

    test "each player's entities are shuffled independently", ctx do
      {:ok, deck_2} =
        Ecto.build_assoc(ctx.game, :decks)
        |> Deck.changeset(%{name: "Player 2 Deck"})
        |> Repo.insert()

      Repo.insert_all(DeckCard, [
        %{deck_id: deck_2.id, card_id: ctx.card_a.id, quantity: 3},
        %{deck_id: deck_2.id, card_id: ctx.card_b.id, quantity: 2}
      ])

      players = [{"player_1", ctx.deck.id}, {"player_2", deck_2.id}]
      {:ok, json} = GameInitializer.build(ctx.game.id, players)
      state = Jason.decode!(json)

      p1_entities = state["zones"]["player_1_Deck"]["entities"]
      p2_entities = state["zones"]["player_2_Deck"]["entities"]

      assert length(p1_entities) == 5
      assert length(p2_entities) == 5
      assert MapSet.disjoint?(MapSet.new(p1_entities), MapSet.new(p2_entities))
    end
  end

  describe "build/2 shuffle randomness" do
    test "two calls with same inputs produce different entity orderings", ctx do
      players = [{"player_1", ctx.deck.id}]

      orderings =
        for _ <- 1..10 do
          {:ok, json} = GameInitializer.build(ctx.game.id, players)
          state = Jason.decode!(json)
          state["zones"]["player_1_Deck"]["entities"]
        end

      unique_orderings = Enum.uniq(orderings)
      assert length(unique_orderings) > 1
    end
  end

  describe "build/2 custom starting zone" do
    test "respects starting_zone config", ctx do
      config = Map.put(@valid_config, "starting_zone", "Hand")

      ctx.game
      |> Game.update_changeset(%{config: config})
      |> Repo.update!()

      players = [{"player_1", ctx.deck.id}]
      {:ok, json} = GameInitializer.build(ctx.game.id, players)
      state = Jason.decode!(json)

      assert length(state["zones"]["player_1_Hand"]["entities"]) == 5
      assert state["zones"]["player_1_Deck"]["entities"] == []
    end

    test "respects custom stack_order", ctx do
      config = Map.put(@valid_config, "stack_order", "Lifo")

      ctx.game
      |> Game.update_changeset(%{config: config})
      |> Repo.update!()

      players = [{"player_1", ctx.deck.id}]
      {:ok, json} = GameInitializer.build(ctx.game.id, players)
      state = Jason.decode!(json)

      assert state["stack_order"] == "Lifo"
    end
  end

  describe "build/2 validation errors" do
    test "returns error for nonexistent game" do
      assert {:error, "Game not found"} = GameInitializer.build(-1, [{"p1", 1}])
    end

    test "returns error when config has no zones", ctx do
      ctx.game
      |> Game.update_changeset(%{config: %{}})
      |> Repo.update!()

      assert {:error, "Game config must have at least one zone defined"} =
               GameInitializer.build(ctx.game.id, [{"p1", ctx.deck.id}])
    end

    test "returns error when config zones is empty list", ctx do
      ctx.game
      |> Game.update_changeset(%{config: %{"zones" => []}})
      |> Repo.update!()

      assert {:error, "Game config must have at least one zone defined"} =
               GameInitializer.build(ctx.game.id, [{"p1", ctx.deck.id}])
    end

    test "returns error when Deck zone is missing from config", ctx do
      config = %{"zones" => [%{"name" => "Hand", "visibility" => "OwnerOnly"}]}

      ctx.game
      |> Game.update_changeset(%{config: config})
      |> Repo.update!()

      assert {:error, "No Deck zone defined in game config"} =
               GameInitializer.build(ctx.game.id, [{"p1", ctx.deck.id}])
    end

    test "returns error for nonexistent deck", ctx do
      assert {:error, "Deck " <> _} =
               GameInitializer.build(ctx.game.id, [{"p1", -1}])
    end

    test "returns error when deck does not belong to game", ctx do
      {:ok, other_user} =
        %User{}
        |> User.changeset(%{email: "other-#{System.unique_integer([:positive])}@example.com"})
        |> Repo.insert()

      {:ok, other_game} =
        Ecto.build_assoc(other_user, :games)
        |> Game.changeset(%{title: "Other Game"})
        |> Repo.insert()

      {:ok, other_deck} =
        Ecto.build_assoc(other_game, :decks)
        |> Deck.changeset(%{name: "Other Deck"})
        |> Repo.insert()

      assert {:error, msg} =
               GameInitializer.build(ctx.game.id, [{"p1", other_deck.id}])

      assert msg =~ "does not belong to game"
    end

    test "returns error when deck has no cards", ctx do
      {:ok, empty_deck} =
        Ecto.build_assoc(ctx.game, :decks)
        |> Deck.changeset(%{name: "Empty Deck"})
        |> Repo.insert()

      assert {:error, msg} =
               GameInitializer.build(ctx.game.id, [{"p1", empty_deck.id}])

      assert msg =~ "has no cards"
    end
  end

  describe "build/2 input validation" do
    test "returns error for empty players list", ctx do
      assert {:error, "At least one player is required"} =
               GameInitializer.build(ctx.game.id, [])
    end

    test "returns error for duplicate player_ids", ctx do
      assert {:error, "Duplicate player IDs are not allowed"} =
               GameInitializer.build(ctx.game.id, [
                 {"player_1", ctx.deck.id},
                 {"player_1", ctx.deck.id}
               ])
    end

    test "returns error for nil zone name in config", ctx do
      config = %{"zones" => [%{"name" => nil, "visibility" => "Public"}]}

      ctx.game
      |> Game.update_changeset(%{config: config})
      |> Repo.update!()

      assert {:error, "All zones must have a non-empty string name"} =
               GameInitializer.build(ctx.game.id, [{"p1", ctx.deck.id}])
    end

    test "returns error for duplicate zone names in config", ctx do
      config = %{
        "zones" => [
          %{"name" => "Deck", "visibility" => "Hidden"},
          %{"name" => "Deck", "visibility" => "Public"}
        ]
      }

      ctx.game
      |> Game.update_changeset(%{config: config})
      |> Repo.update!()

      assert {:error, "Duplicate zone names are not allowed"} =
               GameInitializer.build(ctx.game.id, [{"p1", ctx.deck.id}])
    end

    test "returns error for non-map zone definition in config", ctx do
      config = %{"zones" => ["Deck", "Hand"]}

      ctx.game
      |> Game.update_changeset(%{config: config})
      |> Repo.update!()

      assert {:error, "Each zone definition must be a map"} =
               GameInitializer.build(ctx.game.id, [{"p1", ctx.deck.id}])
    end

    test "unknown visibility value does not crash", ctx do
      config = %{
        "zones" => [
          %{"name" => "Deck", "visibility" => "SomeNewType"},
          %{"name" => "Hand", "visibility" => "OwnerOnly"}
        ]
      }

      ctx.game
      |> Game.update_changeset(%{config: config})
      |> Repo.update!()

      players = [{"player_1", ctx.deck.id}]
      {:ok, json} = GameInitializer.build(ctx.game.id, players)
      state = Jason.decode!(json)
      assert state["zones"]["player_1_Deck"]["visibility"] == "SomeNewType"
    end
  end

  describe "build/2 NIF compatibility" do
    test "output JSON is accepted by the NIF without schema errors", ctx do
      players = [{"player_1", ctx.deck.id}]
      {:ok, json} = GameInitializer.build(ctx.game.id, players)

      result = Carddo.Native.process_move(json, ~s("EndTurn"), "player_1")
      assert {:ok, _new_state, _animations} = result
    end

    test "state_check $owner_ resolution works through NIF", ctx do
      players = [{"player_1", ctx.deck.id}]
      {:ok, json} = GameInitializer.build(ctx.game.id, players)
      state = Jason.decode!(json)

      p1_deck = state["zones"]["player_1_Deck"]
      entity_id = hd(p1_deck["entities"])
      entity = state["entities"][entity_id]

      board_zone_id = "player_1_Board"
      graveyard_zone_id = "player_1_Graveyard"

      test_state =
        state
        |> put_in(["entities", entity_id, "properties", "Health"], 1)
        |> put_in(["zones", board_zone_id, "entities"], [entity_id])
        |> put_in(
          ["zones", "player_1_Deck", "entities"],
          List.delete(p1_deck["entities"], entity_id)
        )
        |> put_in(
          ["zones", "player_1_Deck", "visibility"],
          %{"Hidden" => length(p1_deck["entities"]) - 1}
        )

      test_json = Jason.encode!(test_state)

      damage_action =
        Jason.encode!(%{
          "MutateProperty" => %{
            "target_id" => entity_id,
            "property" => "Health",
            "delta" => -1
          }
        })

      {:ok, result_json, _anims} =
        Carddo.Native.process_move(test_json, damage_action, entity["owner_id"])

      result = Jason.decode!(result_json)

      assert entity_id in result["zones"][graveyard_zone_id]["entities"]
      refute entity_id in result["zones"][board_zone_id]["entities"]
    end
  end
end

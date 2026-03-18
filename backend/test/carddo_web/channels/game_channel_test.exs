defmodule CarddoWeb.GameChannelTest do
  use CarddoWeb.ChannelCase, async: false

  alias Carddo.{Accounts, Card, Deck, DeckCard, Game, GameSession, Repo}
  alias Carddo.Accounts.Guardian
  alias Carddo.Multiplayer

  @valid_config %{
    "zones" => [
      %{"name" => "Deck", "visibility" => "Hidden"},
      %{"name" => "Hand", "visibility" => "OwnerOnly"},
      %{"name" => "Board", "visibility" => "Public"}
    ]
  }

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "channel-#{System.unique_integer([:positive])}@example.com",
        password: "password123"
      })

    {:ok, token, _} = Guardian.encode_and_sign(user)

    {:ok, game} =
      Ecto.build_assoc(user, :games)
      |> Game.changeset(%{title: "Channel Test Game"})
      |> Repo.insert()

    game =
      game
      |> Game.update_changeset(%{config: @valid_config})
      |> Repo.update!()

    {:ok, card} =
      Ecto.build_assoc(game, :cards)
      |> Card.changeset(%{
        name: "Warrior",
        card_type: "creature",
        properties: %{"Health" => 20, "Attack" => 5}
      })
      |> Repo.insert()

    {:ok, deck} =
      Ecto.build_assoc(game, :decks)
      |> Deck.changeset(%{name: "Test Deck"})
      |> Repo.insert()

    Repo.insert_all(DeckCard, [
      %{deck_id: deck.id, card_id: card.id, quantity: 2}
    ])

    {:ok, socket} = connect(CarddoWeb.UserSocket, %{"token" => token})

    on_exit(fn ->
      for {_id, pid, _type, _modules} <-
            DynamicSupervisor.which_children(Carddo.Multiplayer.RoomSupervisor) do
        DynamicSupervisor.terminate_child(Carddo.Multiplayer.RoomSupervisor, pid)
      end
    end)

    %{socket: socket, user: user, game: game, deck: deck, token: token}
  end

  defp unique_room_id, do: "test_#{System.unique_integer([:positive])}"

  describe "join/3 fresh game" do
    test "returns {:ok, %{state: json}} with valid params", ctx do
      room_id = unique_room_id()

      {:ok, reply, _socket} =
        subscribe_and_join(
          ctx.socket,
          CarddoWeb.GameChannel,
          "room:#{room_id}",
          %{"game_id" => ctx.game.id, "deck_id" => ctx.deck.id}
        )

      assert %{state: state_json} = reply
      assert {:ok, state} = Jason.decode(state_json)
      assert is_map(state["entities"])
      assert is_map(state["zones"])
    end

    test "starts a GameRoom GenServer for the room", ctx do
      room_id = unique_room_id()

      {:ok, _reply, _socket} =
        subscribe_and_join(
          ctx.socket,
          CarddoWeb.GameChannel,
          "room:#{room_id}",
          %{"game_id" => ctx.game.id, "deck_id" => ctx.deck.id}
        )

      assert Multiplayer.room_exists?(room_id)
    end

    test "assigns room_id to socket", ctx do
      room_id = unique_room_id()

      {:ok, _reply, socket} =
        subscribe_and_join(
          ctx.socket,
          CarddoWeb.GameChannel,
          "room:#{room_id}",
          %{"game_id" => ctx.game.id, "deck_id" => ctx.deck.id}
        )

      assert socket.assigns.room_id == room_id
    end

    test "returns error with nonexistent game_id", ctx do
      room_id = unique_room_id()

      assert {:error, %{reason: "Game not found"}} =
               subscribe_and_join(
                 ctx.socket,
                 CarddoWeb.GameChannel,
                 "room:#{room_id}",
                 %{"game_id" => -1, "deck_id" => ctx.deck.id}
               )
    end

    test "returns error when missing required params", ctx do
      room_id = unique_room_id()

      assert {:error, %{reason: "Missing required params: game_id, deck_id"}} =
               subscribe_and_join(
                 ctx.socket,
                 CarddoWeb.GameChannel,
                 "room:#{room_id}",
                 %{}
               )
    end
  end

  describe "join/3 authorization" do
    test "rejects join when user does not own the game", ctx do
      {:ok, other_user} =
        Accounts.register_user(%{
          email: "other-#{System.unique_integer([:positive])}@example.com",
          password: "password123"
        })

      {:ok, other_token, _} = Guardian.encode_and_sign(other_user)
      {:ok, other_socket} = connect(CarddoWeb.UserSocket, %{"token" => other_token})

      room_id = unique_room_id()

      assert {:error, %{reason: "Forbidden"}} =
               subscribe_and_join(
                 other_socket,
                 CarddoWeb.GameChannel,
                 "room:#{room_id}",
                 %{"game_id" => ctx.game.id, "deck_id" => ctx.deck.id}
               )
    end

    test "owner can join their own game", ctx do
      room_id = unique_room_id()

      assert {:ok, _reply, _socket} =
               subscribe_and_join(
                 ctx.socket,
                 CarddoWeb.GameChannel,
                 "room:#{room_id}",
                 %{"game_id" => ctx.game.id, "deck_id" => ctx.deck.id}
               )
    end
  end

  describe "join/3 session resume" do
    test "resumes from stored session state instead of fresh init", ctx do
      room_id = unique_room_id()

      stored_state = %{
        "entities" => %{
          "resumed_entity" => %{
            "id" => "resumed_entity",
            "owner_id" => to_string(ctx.user.id),
            "template_id" => "t1",
            "properties" => %{"Health" => 99},
            "abilities" => []
          }
        },
        "zones" => %{},
        "event_queue" => [],
        "pending_animations" => [],
        "stack_order" => "Fifo",
        "state_checks" => [],
        "turn_ended" => false
      }

      Repo.insert!(%GameSession{
        room_id: room_id,
        game_id: ctx.game.id,
        state_json: stored_state,
        turn_number: 3
      })

      {:ok, reply, _socket} =
        subscribe_and_join(
          ctx.socket,
          CarddoWeb.GameChannel,
          "room:#{room_id}",
          %{"game_id" => ctx.game.id, "deck_id" => ctx.deck.id}
        )

      assert %{state: state_json} = reply
      state = Jason.decode!(state_json)
      assert Map.has_key?(state["entities"], "resumed_entity")
      assert state["entities"]["resumed_entity"]["properties"]["Health"] == 99
    end

    test "rejects resume when requested game_id does not match room session game_id", ctx do
      room_id = unique_room_id()

      Repo.insert!(%GameSession{
        room_id: room_id,
        game_id: ctx.game.id,
        state_json: %{
          "entities" => %{},
          "zones" => %{},
          "event_queue" => [],
          "pending_animations" => [],
          "stack_order" => "Fifo",
          "state_checks" => [],
          "turn_ended" => false
        },
        turn_number: 1
      })

      {:ok, other_user} =
        Accounts.register_user(%{
          email: "mismatch-#{System.unique_integer([:positive])}@example.com",
          password: "password123"
        })

      {:ok, other_token, _} = Guardian.encode_and_sign(other_user)
      {:ok, other_socket} = connect(CarddoWeb.UserSocket, %{"token" => other_token})

      {:ok, other_game} =
        Ecto.build_assoc(other_user, :games)
        |> Game.changeset(%{title: "Other Game"})
        |> Repo.insert()

      assert {:error, %{reason: "Room/game mismatch"}} =
               subscribe_and_join(
                 other_socket,
                 CarddoWeb.GameChannel,
                 "room:#{room_id}",
                 %{"game_id" => other_game.id, "deck_id" => ctx.deck.id}
               )
    end
  end

  describe "handle_in submit_action" do
    setup ctx do
      room_id = unique_room_id()

      {:ok, _reply, socket} =
        subscribe_and_join(
          ctx.socket,
          CarddoWeb.GameChannel,
          "room:#{room_id}",
          %{"game_id" => ctx.game.id, "deck_id" => ctx.deck.id}
        )

      %{channel_socket: socket, room_id: room_id}
    end

    test "valid action broadcasts state_resolved to all joined clients", ctx do
      ref =
        push(ctx.channel_socket, "submit_action", %{
          "client_sequence_id" => 1,
          "action" => "EndTurn"
        })

      refute_reply(ref, _status)

      assert_broadcast("state_resolved", %{state: state_json})
      assert {:ok, _} = Jason.decode(state_json)
    end

    test "invalid action pushes action_rejected to acting client only", ctx do
      ref =
        push(ctx.channel_socket, "submit_action", %{
          "client_sequence_id" => 42,
          "action" => %{
            "MutateProperty" => %{
              "target_id" => "nonexistent",
              "property" => "Health",
              "delta" => -1
            }
          }
        })

      refute_reply(ref, _status)

      assert_push("action_rejected", payload)
      assert payload.client_sequence_id == 42
      assert payload.error.type == "native_error"
      assert is_binary(payload.error.message)
    end

    test "action_rejected is not broadcast to other clients", ctx do
      push(ctx.channel_socket, "submit_action", %{
        "client_sequence_id" => 99,
        "action" => %{
          "MutateProperty" => %{
            "target_id" => "ghost",
            "property" => "Health",
            "delta" => -1
          }
        }
      })

      refute_broadcast("action_rejected", _)
    end

    test "dead GameRoom pushes action_rejected with room_unavailable", ctx do
      [{pid, _}] = Carddo.Multiplayer.GameRegistry.lookup(ctx.room_id)
      ref = Process.monitor(pid)
      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}

      push(ctx.channel_socket, "submit_action", %{
        "client_sequence_id" => 10,
        "action" => "EndTurn"
      })

      assert_push("action_rejected", payload)
      assert payload.client_sequence_id == 10
      assert payload.error.type == "room_unavailable"
    end
  end

  describe "handle_in unknown event" do
    setup ctx do
      room_id = unique_room_id()

      {:ok, _reply, socket} =
        subscribe_and_join(
          ctx.socket,
          CarddoWeb.GameChannel,
          "room:#{room_id}",
          %{"game_id" => ctx.game.id, "deck_id" => ctx.deck.id}
        )

      %{channel_socket: socket}
    end

    test "replies with error for unknown events", ctx do
      ref = push(ctx.channel_socket, "bogus_event", %{})
      assert_reply(ref, :error, %{reason: "unknown_event"})
    end
  end

  describe "authentication" do
    test "unauthenticated socket cannot connect" do
      assert :error = connect(CarddoWeb.UserSocket, %{"token" => "invalid_token"})
    end

    test "socket without token cannot connect" do
      assert :error = connect(CarddoWeb.UserSocket, %{})
    end
  end
end

defmodule Carddo.AiSimulatorTest do
  use Carddo.DataCase, async: false
  alias Carddo.Native

  @empty_state %{
    "entities" => %{},
    "zones" => %{},
    "event_queue" => [],
    "pending_animations" => [],
    "stack_order" => "Fifo",
    "state_checks" => [],
    "turn_ended" => false,
    "game_over" => nil
  }

  @weights %{"health" => 1, "power" => 1}

  defp make_state(overrides) do
    Map.merge(@empty_state, overrides) |> Jason.encode!()
  end

  describe "AI Decision Making (simulate_best_action)" do
    test "AI chooses an action that increases its own health" do
      # AI hero starts with 10 health.
      # AI has a card in hand that heals the hero by 5 when moved to the board.
      state =
        make_state(%{
          "entities" => %{
            "ai_hero" => %{
              "id" => "ai_hero",
              "owner_id" => "ai_player",
              "template_id" => "hero",
              "properties" => %{"health" => 10},
              "abilities" => []
            },
            "ai_card" => %{
              "id" => "ai_card",
              "owner_id" => "ai_player",
              "template_id" => "spell",
              "properties" => %{},
              "abilities" => [
                %{
                  "id" => "heal_ability",
                  "name" => "Heal Hero",
                  "trigger" => "on_after_move_entity:self",
                  "conditions" => [],
                  "actions" => [
                    %{
                      "MutateProperty" => %{
                        "target_id" => "ai_hero",
                        "property" => "health",
                        "delta" => 5
                      }
                    }
                  ],
                  "cancels" => false
                }
              ]
            }
          },
          "zones" => %{
            "hand" => %{
              "id" => "hand",
              "owner_id" => "ai_player",
              "visibility" => "Public",
              "entities" => ["ai_card"]
            },
            "board" => %{
              "id" => "board",
              "owner_id" => nil,
              "visibility" => "Public",
              "entities" => []
            }
          }
        })

      {:ok, action_json} = Native.simulate_best_action(state, "ai_player", @weights)
      action = Jason.decode!(action_json)

      # AI should choose to move ai_card to board to trigger the heal.
      assert action == %{
               "MoveEntity" => %{
                 "entity_id" => "ai_card",
                 "from_zone" => "hand",
                 "to_zone" => "board",
                 "index" => nil
               }
             }
    end

    test "AI chooses an action that decreases the opponent's health" do
      # Opponent hero starts with 10 health.
      # AI has a card in hand that damages the opponent hero by 5 when moved to the board.
      state =
        make_state(%{
          "entities" => %{
            "ai_hero" => %{
              "id" => "ai_hero",
              "owner_id" => "ai_player",
              "template_id" => "hero",
              "properties" => %{"health" => 10},
              "abilities" => []
            },
            "opponent_hero" => %{
              "id" => "opponent_hero",
              "owner_id" => "opponent_player",
              "template_id" => "hero",
              "properties" => %{"health" => 10},
              "abilities" => []
            },
            "ai_card" => %{
              "id" => "ai_card",
              "owner_id" => "ai_player",
              "template_id" => "spell",
              "properties" => %{},
              "abilities" => [
                %{
                  "id" => "damage_ability",
                  "name" => "Damage Opponent",
                  "trigger" => "on_after_move_entity:self",
                  "conditions" => [],
                  "actions" => [
                    %{
                      "MutateProperty" => %{
                        "target_id" => "opponent_hero",
                        "property" => "health",
                        "delta" => -5
                      }
                    }
                  ],
                  "cancels" => false
                }
              ]
            }
          },
          "zones" => %{
            "hand" => %{
              "id" => "hand",
              "owner_id" => "ai_player",
              "visibility" => "Public",
              "entities" => ["ai_card"]
            },
            "board" => %{
              "id" => "board",
              "owner_id" => nil,
              "visibility" => "Public",
              "entities" => []
            }
          }
        })

      {:ok, action_json} = Native.simulate_best_action(state, "ai_player", @weights)
      action = Jason.decode!(action_json)

      # AI should choose to move ai_card to board to trigger the damage.
      assert action == %{
               "MoveEntity" => %{
                 "entity_id" => "ai_card",
                 "from_zone" => "hand",
                 "to_zone" => "board",
                 "index" => nil
               }
             }
    end

    test "AI falls back to EndTurn when no better moves exist" do
      # AI has no cards to move, only EndTurn is available.
      state =
        make_state(%{
          "entities" => %{
            "ai_hero" => %{
              "id" => "ai_hero",
              "owner_id" => "ai_player",
              "template_id" => "hero",
              "properties" => %{"health" => 10},
              "abilities" => []
            }
          },
          "zones" => %{
            "board" => %{
              "id" => "board",
              "owner_id" => nil,
              "visibility" => "Public",
              "entities" => []
            }
          }
        })

      {:ok, action_json} = Native.simulate_best_action(state, "ai_player", @weights)
      assert action_json == ~s("EndTurn")
    end

    test "AI behavior is deterministic" do
      # Same setup as the first test.
      state =
        make_state(%{
          "entities" => %{
            "ai_hero" => %{
              "id" => "ai_hero",
              "owner_id" => "ai_player",
              "template_id" => "hero",
              "properties" => %{"health" => 10},
              "abilities" => []
            },
            "ai_card" => %{
              "id" => "ai_card",
              "owner_id" => "ai_player",
              "template_id" => "spell",
              "properties" => %{},
              "abilities" => [
                %{
                  "id" => "heal_ability",
                  "name" => "Heal Hero",
                  "trigger" => "on_after_move_entity:self",
                  "conditions" => [],
                  "actions" => [
                    %{
                      "MutateProperty" => %{
                        "target_id" => "ai_hero",
                        "property" => "health",
                        "delta" => 5
                      }
                    }
                  ],
                  "cancels" => false
                }
              ]
            }
          },
          "zones" => %{
            "hand" => %{
              "id" => "hand",
              "owner_id" => "ai_player",
              "visibility" => "Public",
              "entities" => ["ai_card"]
            },
            "board" => %{
              "id" => "board",
              "owner_id" => nil,
              "visibility" => "Public",
              "entities" => []
            }
          }
        })

      results =
        for _ <- 1..10 do
          {:ok, action_json} = Native.simulate_best_action(state, "ai_player", @weights)
          action_json
        end

      # All results should be identical.
      first_result = List.first(results)
      assert Enum.all?(results, fn r -> r == first_result end)
    end

    test "AI prefers a move that increases power over one that does nothing" do
      # AI has two cards. One increases power, one does nothing.
      state =
        make_state(%{
          "entities" => %{
            "ai_hero" => %{
              "id" => "ai_hero",
              "owner_id" => "ai_player",
              "template_id" => "hero",
              "properties" => %{"power" => 0},
              "abilities" => []
            },
            "power_card" => %{
              "id" => "power_card",
              "owner_id" => "ai_player",
              "template_id" => "spell",
              "properties" => %{},
              "abilities" => [
                %{
                  "id" => "power_ability",
                  "name" => "Gain Power",
                  "trigger" => "on_after_move_entity:self",
                  "conditions" => [],
                  "actions" => [
                    %{
                      "MutateProperty" => %{
                        "target_id" => "ai_hero",
                        "property" => "power",
                        "delta" => 2
                      }
                    }
                  ],
                  "cancels" => false
                }
              ]
            },
            "useless_card" => %{
              "id" => "useless_card",
              "owner_id" => "ai_player",
              "template_id" => "spell",
              "properties" => %{},
              "abilities" => []
            }
          },
          "zones" => %{
            "hand" => %{
              "id" => "hand",
              "owner_id" => "ai_player",
              "visibility" => "Public",
              "entities" => ["power_card", "useless_card"]
            },
            "board" => %{
              "id" => "board",
              "owner_id" => nil,
              "visibility" => "Public",
              "entities" => []
            }
          }
        })

      {:ok, action_json} = Native.simulate_best_action(state, "ai_player", @weights)
      action = Jason.decode!(action_json)

      assert action["MoveEntity"]["entity_id"] == "power_card"
    end
  end

  describe "GameRoom Integration" do
    alias Carddo.{Game, GameRoom, Repo, User}
    alias Phoenix.PubSub

    setup do
      {:ok, user} =
        %User{}
        |> User.changeset(%{email: "room-test-#{System.unique_integer([:positive])}@example.com"})
        |> Repo.insert()

      {:ok, game} =
        Ecto.build_assoc(user, :games)
        |> Game.changeset(%{title: "Integration Test Game"})
        |> Repo.insert()

      %{game: game}
    end

    test "AI takes the high-value move in a GameRoom", %{game: game} do
      ai_id = "ai_player"
      human_id = "human_player"

      state =
        make_state(%{
          "entities" => %{
            "ai_hero" => %{
              "id" => "ai_hero",
              "owner_id" => ai_id,
              "template_id" => "hero",
              "properties" => %{"health" => 10},
              "abilities" => []
            },
            "ai_card" => %{
              "id" => "ai_card",
              "owner_id" => ai_id,
              "template_id" => "spell",
              "properties" => %{},
              "abilities" => [
                %{
                  "id" => "heal_ability",
                  "name" => "Heal Hero",
                  "trigger" => "on_after_move_entity:self",
                  "conditions" => [],
                  "actions" => [
                    %{
                      "MutateProperty" => %{
                        "target_id" => "ai_hero",
                        "property" => "health",
                        "delta" => 5
                      }
                    }
                  ],
                  "cancels" => false
                }
              ]
            }
          },
          "zones" => %{
            "hand" => %{
              "id" => "hand",
              "owner_id" => ai_id,
              "visibility" => "Public",
              "entities" => ["ai_card"]
            },
            "board" => %{
              "id" => "board",
              "owner_id" => nil,
              "visibility" => "Public",
              "entities" => []
            }
          }
        })

      room_id = "ai_integration_#{System.unique_integer([:positive])}"

      opts = %{
        room_id: room_id,
        game_id: game.id,
        initial_state_json: state,
        solo_mode: true,
        ai_player_id: ai_id,
        player_order: [human_id, ai_id],
        ai_action_delay_ms: 10
      }

      {:ok, _pid} = start_supervised(Supervisor.child_spec({GameRoom, opts}, restart: :temporary))

      topic = "room:#{room_id}"
      PubSub.subscribe(Carddo.PubSub, topic)

      # Human ends turn to let AI act.
      assert GameRoom.make_move(room_id, human_id, ~s("EndTurn")) == :ok

      # First broadcast: human EndTurn (rotates to AI)
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "state_resolved",
                       payload: %{active_player_id: ^ai_id}
                     },
                     1000

      # Second broadcast: AI move (should be MoveEntity)
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "state_resolved",
                       payload: %{state: new_state_json, active_player_id: ^ai_id}
                     },
                     1000

      new_state = Jason.decode!(new_state_json)

      # Verify the AI moved the card to the board.
      assert "ai_card" in new_state["zones"]["board"]["entities"]
      # Verify the heal triggered.
      assert new_state["entities"]["ai_hero"]["properties"]["health"] == 15
    end
  end
end

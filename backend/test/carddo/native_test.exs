defmodule Carddo.NativeTest do
  use ExUnit.Case, async: true

  @empty_state ~s({"entities":{},"zones":{},"event_queue":[],"pending_animations":[],"stack_order":"Fifo","state_checks":[]})

  defp entity(id, owner, props) do
    %{
      id: id,
      owner_id: owner,
      template_id: "template_001",
      properties: props,
      abilities: []
    }
  end

  defp state_with_entity(entity) do
    Jason.encode!(%{
      entities: %{entity.id => entity},
      zones: %{
        "field" => %{
          id: "field",
          owner_id: nil,
          visibility: "Public",
          entities: [entity.id]
        }
      },
      event_queue: [],
      pending_animations: [],
      stack_order: "Fifo",
      state_checks: []
    })
  end

  describe "process_move/3" do
    test "EndTurn on empty state returns :ok tuple" do
      action = ~s("EndTurn")

      assert {:ok, new_state_json, "[]"} =
               Carddo.Native.process_move(@empty_state, action, "player_1")

      # State is valid JSON
      assert {:ok, _} = Jason.decode(new_state_json)
    end

    test "MutateProperty updates entity property and returns animation" do
      card = entity("card_1", "player_1", %{health: 10})
      state = state_with_entity(card)

      action =
        Jason.encode!(%{MutateProperty: %{target_id: "card_1", property: "health", delta: -3}})

      assert {:ok, new_state_json, animations_json} =
               Carddo.Native.process_move(state, action, "player_1")

      new_state = Jason.decode!(new_state_json)
      assert new_state["entities"]["card_1"]["properties"]["health"] == 7

      animations = Jason.decode!(animations_json)
      assert length(animations) > 0
    end

    test "invalid state JSON returns :error tuple" do
      assert {:error, reason, "[]"} =
               Carddo.Native.process_move("not json", ~s("EndTurn"), "player_1")

      assert is_binary(reason)
      assert String.contains?(reason, "invalid state")
    end

    test "invalid action JSON returns :error tuple" do
      assert {:error, reason, "[]"} =
               Carddo.Native.process_move(@empty_state, "not json", "player_1")

      assert is_binary(reason)
      assert String.contains?(reason, "invalid action")
    end

    test "action targeting nonexistent entity returns validation :error" do
      action =
        Jason.encode!(%{MutateProperty: %{target_id: "ghost", property: "health", delta: -1}})

      assert {:error, reason, "[]"} =
               Carddo.Native.process_move(@empty_state, action, "player_1")

      assert is_binary(reason)
    end
  end
end

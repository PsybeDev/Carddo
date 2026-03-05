defmodule Carddo.CardTest do
  use Carddo.DataCase

  alias Carddo.{Card, Game, Repo, User}
  import Ecto.Query

  setup do
    {:ok, user} =
      %User{}
      |> User.changeset(%{email: "test@example.com"})
      |> Repo.insert()

    {:ok, game} =
      %Game{}
      |> Game.changeset(%{title: "Test Game", owner_id: user.id})
      |> Repo.insert()

    %{game: game}
  end

  test "inserts card with nested JSON properties and round-trips correctly", %{game: game} do
    attrs = %{
      name: "Dragon",
      card_type: "creature",
      properties: %{"stats" => %{"health" => 30, "attack" => 5}},
      abilities: [%{"trigger" => "on_attack", "effect" => "deal_damage"}],
      game_id: game.id
    }

    {:ok, card} = %Card{} |> Card.changeset(attrs) |> Repo.insert()
    loaded = Repo.get!(Card, card.id)

    assert loaded.properties == %{"stats" => %{"health" => 30, "attack" => 5}}
    assert loaded.abilities == [%{"trigger" => "on_attack", "effect" => "deal_damage"}]
  end

  test "queries cards via JSONB fragment on properties", %{game: game} do
    %Card{}
    |> Card.changeset(%{
      name: "Goblin",
      card_type: "creature",
      properties: %{"card_type" => "creature"},
      game_id: game.id
    })
    |> Repo.insert!()

    result =
      Repo.one(
        from c in Card,
          where: fragment("?->>'card_type' = ?", c.properties, "creature")
      )

    assert result.name == "Goblin"
  end

  test "changeset rejects nil required fields", %{game: game} do
    changeset = Card.changeset(%Card{}, %{game_id: game.id})
    refute changeset.valid?
    assert {:name, {"can't be blank", _}} = List.keyfind(changeset.errors, :name, 0)
    assert {:card_type, {"can't be blank", _}} = List.keyfind(changeset.errors, :card_type, 0)
  end
end

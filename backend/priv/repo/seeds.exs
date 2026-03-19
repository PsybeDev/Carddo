# Ditto Demo — seed script for local development.
#
#     mix run priv/repo/seeds.exs
#
# Idempotent — safe to run multiple times without creating duplicates.

import Ecto.Changeset
alias Carddo.{Card, Deck, DeckCard, Game, Repo, User}

# ── 1. Demo User ────────────────────────────────────────────────────────

demo_email = "demo@carddo.dev"

user =
  case Repo.get_by(User, email: demo_email) do
    nil ->
      %User{}
      |> User.registration_changeset(%{email: demo_email, password: "demopassword"})
      |> put_change(:subscription_tier, "pro")
      |> Repo.insert!()

    existing ->
      if existing.subscription_tier != "pro" do
        existing
        |> User.changeset(%{})
        |> put_change(:subscription_tier, "pro")
        |> Repo.update!()
      else
        existing
      end
  end

IO.puts("✓ Demo user: #{user.email} (id: #{user.id})")

# ── 2. Demo Game with Config ────────────────────────────────────────────

game_title = "Ditto Demo"

game =
  case Repo.get_by(Game, title: game_title, owner_id: user.id) do
    nil ->
      Ecto.build_assoc(user, :games)
      |> Game.changeset(%{title: game_title})
      |> Repo.insert!()

    existing ->
      existing
  end

config = %{
  "zones" => [
    %{"name" => "Deck", "visibility" => "Hidden"},
    %{"name" => "Hand", "visibility" => "OwnerOnly"},
    %{"name" => "Battlefield", "visibility" => "Public"},
    %{"name" => "Discard", "visibility" => "Public"}
  ],
  "state_checks" => [
    %{
      "watch_property" => "Health",
      "operator" => "<=",
      "threshold" => 0,
      "move_to_zone" => "Discard"
    }
  ],
  "starting_zone" => "Deck"
}

game =
  if game.config != config do
    game
    |> Game.update_changeset(%{config: config})
    |> Repo.update!()
  else
    game
  end

IO.puts("✓ Demo game: #{game.title} (id: #{game.id})")

# ── 3. Seed Cards (10 creatures, varying Attack 1–5) ────────────────────

card_defs = [
  %{name: "Flame Imp", attack: 3, color: "#E74C3C"},
  %{name: "Ice Shard", attack: 2, color: "#3498DB"},
  %{name: "Shadow Bolt", attack: 4, color: "#8E44AD"},
  %{name: "Stone Golem", attack: 1, color: "#95A5A6"},
  %{name: "Wind Walker", attack: 3, color: "#1ABC9C"},
  %{name: "Thunder Fist", attack: 5, color: "#F39C12"},
  %{name: "Vine Creeper", attack: 2, color: "#27AE60"},
  %{name: "Iron Knight", attack: 4, color: "#2C3E50"},
  %{name: "Spark Wisp", attack: 1, color: "#E67E22"},
  %{name: "Void Stalker", attack: 5, color: "#9B59B6"}
]

cards =
  Enum.map(card_defs, fn %{name: name, attack: attack, color: color} ->
    ability_id = name |> String.downcase() |> String.replace(" ", "_")

    case Repo.get_by(Card, name: name, game_id: game.id) do
      nil ->
        Ecto.build_assoc(game, :cards)
        |> Card.changeset(%{
          name: name,
          card_type: "creature",
          background_color: color,
          properties: %{"Health" => 20, "Attack" => attack},
          abilities: [
            %{
              "id" => "strike_#{ability_id}",
              "name" => "Strike",
              "trigger" => "on_after_move_entity:self",
              "conditions" => [],
              "actions" => [
                %{
                  "MutateProperty" => %{
                    "target_id" => "$target",
                    "property" => "Health",
                    "delta" => -attack
                  }
                }
              ],
              "cancels" => false
            }
          ]
        })
        |> Repo.insert!()

      existing ->
        existing
    end
  end)

IO.puts("✓ #{length(cards)} cards seeded")

# ── 4. Seed Decks (2 × 5 cards) ────────────────────────────────────────

deck_specs = [
  {"Deck Alpha", Enum.slice(cards, 0..4)},
  {"Deck Beta", Enum.slice(cards, 5..9)}
]

Enum.each(deck_specs, fn {deck_name, deck_cards} ->
  deck =
    case Repo.get_by(Deck, name: deck_name, game_id: game.id) do
      nil ->
        Ecto.build_assoc(game, :decks)
        |> Deck.changeset(%{name: deck_name})
        |> Repo.insert!()

      existing ->
        existing
    end

  Enum.each(deck_cards, fn card ->
    Repo.insert!(
      %DeckCard{deck_id: deck.id, card_id: card.id, quantity: 1},
      on_conflict: :nothing
    )
  end)

  IO.puts("✓ #{deck_name}: #{length(deck_cards)} cards")
end)

IO.puts("\nDitto Demo seed complete!")
IO.puts("Login: demo@carddo.dev / demopassword")

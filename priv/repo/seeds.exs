# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Carddo.Repo.insert!(%Carddo.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
alias Carddo.Accounts.User
alias Carddo.Repo
alias Carddo.Accounts
alias Carddo.Games

# Clear DB
Repo.delete_all User
Repo.delete_all Games.Game
Repo.delete_all Games.Format

user = Accounts.register_user(%{
  username: "user",
  email: "user@example.com",
  password: "random_password",
  confirmed_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
})

Accounts.register_user(%{
  username: "admin",
  email: "admin@example.com",
  password: "random_password",
  confirmed_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
})

Games.create_game(%{
  name: "Super Cool TCG",
  description: "A super cool trading card game",
})

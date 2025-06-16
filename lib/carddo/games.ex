defmodule Carddo.Games do
  @moduledoc """
  The Games context.
  """

  import Ecto.Query, warn: false
  alias Carddo.Repo

  alias Carddo.Games.Game

  @doc """
  Returns the list of games.

  ## Examples

      iex> list_games()
      [%Game{}, ...]

  """
  def list_games do
    Repo.all(Game)
  end

  @doc """
  Gets a single game.

  Raises `Ecto.NoResultsError` if the Game does not exist.

  ## Examples

      iex> get_game!(123)
      %Game{}

      iex> get_game!(456)
      ** (Ecto.NoResultsError)

  """
  def get_game!(id), do: Repo.get!(Game, id)

  @doc """
  Creates a game.

  ## Examples

      iex> create_game(%{field: value})
      {:ok, %Game{}}

      iex> create_game(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_game(attrs \\ %{}) do
    %Game{}
    |> Game.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a game.

  ## Examples

      iex> update_game(game, %{field: new_value})
      {:ok, %Game{}}

      iex> update_game(game, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_game(%Game{} = game, attrs) do
    game
    |> Game.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a game.

  ## Examples

      iex> delete_game(game)
      {:ok, %Game{}}

      iex> delete_game(game)
      {:error, %Ecto.Changeset{}}

  """
  def delete_game(%Game{} = game) do
    Repo.delete(game)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking game changes.

  ## Examples

      iex> change_game(game)
      %Ecto.Changeset{data: %Game{}}

  """
  def change_game(%Game{} = game, attrs \\ %{}) do
    Game.changeset(game, attrs)
  end

  alias Carddo.Games.Format

  @doc """
  Returns the list of formats.

  ## Examples

      iex> list_formats()
      [%Format{}, ...]

  """
  def list_formats do
    Repo.all(Format)
  end

  @doc """
  Gets a single format.

  Raises `Ecto.NoResultsError` if the Format does not exist.

  ## Examples

      iex> get_format!(123)
      %Format{}

      iex> get_format!(456)
      ** (Ecto.NoResultsError)

  """
  def get_format!(id), do: Repo.get!(Format, id)

  @doc """
  Creates a format.

  ## Examples

      iex> create_format(%{field: value})
      {:ok, %Format{}}

      iex> create_format(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_format(attrs \\ %{}) do
    %Format{}
    |> Format.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a format.

  ## Examples

      iex> update_format(format, %{field: new_value})
      {:ok, %Format{}}

      iex> update_format(format, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_format(%Format{} = format, attrs) do
    format
    |> Format.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a format.

  ## Examples

      iex> delete_format(format)
      {:ok, %Format{}}

      iex> delete_format(format)
      {:error, %Ecto.Changeset{}}

  """
  def delete_format(%Format{} = format) do
    Repo.delete(format)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking format changes.

  ## Examples

      iex> change_format(format)
      %Ecto.Changeset{data: %Format{}}

  """
  def change_format(%Format{} = format, attrs \\ %{}) do
    Format.changeset(format, attrs)
  end


  @doc """
  Returns the list of game sessions.

  ## Examples

      iex> list_game_sessions()
      [%Carddo.Games.GameSession{}, ...]

  """
  def get_game_session!(id) do
    Repo.get!(Carddo.Games.GameSession, id)
  end

  @doc """
  Returns the list of game sessions.
  ## Examples

      iex> list_game_sessions()
      [%Carddo.Games.GameSession{}, ...]

  """
  def get_player_for_session(game_session, user) do
    Repo.one(
      from p in Carddo.Games.GamePlayer,
      where: p.game_session_id == ^game_session.id and p.user_id == ^user.id
    )
  end

  @doc """
  Returns the list of game sessions.
  ## Examples

      iex> list_game_sessions()
      [%Carddo.Games.GameSession{}, ...]

  """
  def list_players_for_session(game_session) do
    Repo.all(
      from p in Carddo.Games.GamePlayer,
      where: p.game_session_id == ^game_session.id,
      preload: [:user]
    )
  end

def play_card(game_session_id, user_id, card_id) do
  game_session = get_game_session!(game_session_id)

  player = Repo.one(
    from p in Carddo.Games.GamePlayer,
    where: p.game_session_id == ^game_session.id and p.user_id == ^user_id
  )

  player_hand = player.hand || []
  card_to_play = Enum.find(player_hand, fn card -> card.id == String.to_integer(card_id) end)
  if !card_to_play do
    {:error, "Card not found in hand"}
  else
    # Logic to play the card
    updated_hand = List.delete(player_hand, card_to_play)
    updated_player = %{player | hand: updated_hand, play_area: [card_to_play | player.play_area || []]}

    # Update player in the database
    Repo.update!(Carddo.Games.GamePlayer.changeset(updated_player, %{}))


    {:ok, game_session}
  end
end

def end_turn(game_session_id, user_id) do
  game_session = get_game_session!(game_session_id)

  next_player_id = Enum.find(game_session.players, fn player -> player.id != user_id end).id

  # Logic to end the turn, e.g., updating the current player
  updated_game_session = %{game_session | current_turn: game_session.current_turn + 1, curent_player_id: next_player_id}

  # Update game session in the database
  Repo.update!(Carddo.Games.GameSession.changeset(updated_game_session, %{}))

  {:ok, updated_game_session}
end

  def user_in_session?(game_session, user_id) do
    Repo.exists?(
      from p in Carddo.Games.GamePlayer,
      where: p.game_session_id == ^game_session.id and p.user_id == ^user_id
    )
  end

  def create_game_session(attrs \\ %{}) do
    %Carddo.Games.GameSession{}
    |> Carddo.Games.GameSession.changeset(attrs)
    |> Repo.insert()
  end

  def add_player_to_session(game_session, user) do
    %Carddo.Games.GamePlayer{}
    |> Carddo.Games.GamePlayer.changeset(%{user_id: user.id, game_session_id: game_session.id})
    |> Repo.insert()
    |> case do
      {:ok, player} ->
        # Update the game session with the new player
        {:ok, _updated_session} = Carddo.Games.GameSession.changeset(game_session, %{
          current_player_id: game_session.current_player_id || player.id,
          players: [player | game_session.players || []]
        })
        |> Repo.update()
        {:ok, player}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def get_current_player(game_session) do
    Repo.get!(Carddo.Games.GamePlayer, game_session.current_player_id)
    |> Repo.preload(:user)
    |> IO.inspect
  end
end

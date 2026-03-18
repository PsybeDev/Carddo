defmodule CarddoWeb.ChannelCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest

      @endpoint CarddoWeb.Endpoint
    end
  end

  setup tags do
    Carddo.DataCase.setup_sandbox(tags)
    :ok
  end
end

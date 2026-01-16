defmodule SocialNetwork.Plugs.AbsintheContext do
  @moduledoc """
  Plug that extracts demo authentication from X-User-ID header
  and adds the current user to the Absinthe context.
  """
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    context = build_context(conn)
    Absinthe.Plug.put_options(conn, context: context)
  end

  defp build_context(conn) do
    case Plug.Conn.get_req_header(conn, "x-user-id") do
      [user_id] ->
        case SocialNetwork.Repo.get(SocialNetwork.Accounts.User, user_id) do
          nil -> %{}
          user -> %{current_user: user}
        end

      _ ->
        %{}
    end
  end
end

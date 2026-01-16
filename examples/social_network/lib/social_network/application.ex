defmodule SocialNetwork.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        SocialNetwork.Repo,
        {Phoenix.PubSub, name: SocialNetwork.PubSub}
      ] ++ subscription_children() ++ http_children()

    opts = [strategy: :one_for_one, name: SocialNetwork.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp subscription_children do
    if Application.get_env(:social_network, :start_subscriptions, true) do
      [{Absinthe.Subscription, SocialNetworkWeb.GraphQL.Schema}]
    else
      []
    end
  end

  defp http_children do
    if Application.get_env(:social_network, :start_http, true) do
      [
        {Plug.Cowboy,
         scheme: :http,
         plug: SocialNetwork.Router,
         options: [
           port: 4000,
           dispatch: dispatch()
         ]}
      ]
    else
      []
    end
  end

  defp dispatch do
    [
      {:_,
       [
         {"/socket/websocket", Absinthe.Phoenix.Endpoint, {SocialNetworkWeb.GraphQL.Schema, []}},
         {:_, Plug.Cowboy.Handler, {SocialNetwork.Router, []}}
       ]}
    ]
  end
end

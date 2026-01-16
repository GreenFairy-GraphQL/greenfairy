defmodule SocialNetwork.Router do
  use Plug.Router

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
    pass: ["*/*"],
    json_decoder: Jason

  # Add demo authentication context before Absinthe
  plug SocialNetwork.Plugs.AbsintheContext

  plug :match
  plug :dispatch

  forward "/api/graphql",
    to: Absinthe.Plug,
    init_opts: [schema: SocialNetworkWeb.GraphQL.Schema]

  forward "/graphiql",
    to: Absinthe.Plug.GraphiQL,
    init_opts: [
      schema: SocialNetworkWeb.GraphQL.Schema,
      interface: :playground
    ]

  match _ do
    send_resp(conn, 404, "Not found")
  end
end

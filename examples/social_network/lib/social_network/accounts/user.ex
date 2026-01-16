defmodule SocialNetwork.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :username, :string
    field :display_name, :string
    field :bio, :string
    field :avatar_url, :string

    has_many :posts, SocialNetwork.Content.Post, foreign_key: :author_id
    has_many :comments, SocialNetwork.Content.Comment, foreign_key: :author_id
    has_many :likes, SocialNetwork.Content.Like

    # Self-referential friendships
    has_many :friendships, SocialNetwork.Accounts.Friendship, foreign_key: :user_id
    has_many :friends, through: [:friendships, :friend]

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :username, :display_name, :bio, :avatar_url])
    |> validate_required([:email, :username])
    |> unique_constraint(:email)
    |> unique_constraint(:username)
  end
end

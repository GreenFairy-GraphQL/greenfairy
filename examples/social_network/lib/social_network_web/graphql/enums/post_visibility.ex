defmodule SocialNetworkWeb.GraphQL.Enums.PostVisibility do
  use GreenFairy.Enum

  enum "PostVisibility" do
    value :public, description: "Visible to everyone"
    value :friends, description: "Visible only to friends"
    value :private, description: "Visible only to the author"
  end

  # Map GraphQL enum values to Ecto enum values
  # In this case, they're the same, but this demonstrates the mapping capability
  enum_mapping %{
    public: :public,
    friends: :friends,
    private: :private
  }

  # The serialize/1 and parse/1 functions are automatically generated!
  # Example usage:
  #   PostVisibility.serialize(:public)  # => :public
  #   PostVisibility.parse(:friends)     # => :friends
end

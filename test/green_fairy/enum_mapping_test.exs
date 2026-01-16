defmodule GreenFairy.EnumMappingTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Tests for enum mapping (GraphQL <-> Ecto enum transformations).
  """

  describe "Enum with identity mapping" do
    defmodule StatusEnum do
      use GreenFairy.Enum

      enum "Status" do
        value :active
        value :inactive
        value :pending
      end

      # Values are the same in GraphQL and Ecto
      enum_mapping %{
        active: :active,
        inactive: :inactive,
        pending: :pending
      }
    end

    test "serialize returns the Ecto value" do
      assert StatusEnum.serialize(:active) == :active
      assert StatusEnum.serialize(:inactive) == :inactive
      assert StatusEnum.serialize(:pending) == :pending
    end

    test "parse returns the GraphQL value" do
      assert StatusEnum.parse(:active) == :active
      assert StatusEnum.parse(:inactive) == :inactive
      assert StatusEnum.parse(:pending) == :pending
    end

    test "handles unknown values" do
      assert StatusEnum.serialize(:unknown) == :unknown
      assert StatusEnum.parse(:unknown) == :unknown
    end
  end

  describe "Enum with custom mapping" do
    defmodule PriorityEnum do
      use GreenFairy.Enum

      enum "Priority" do
        value :low
        value :medium
        value :high
        value :urgent
      end

      # GraphQL uses descriptive names, database uses numbers
      enum_mapping %{
        low: 1,
        medium: 5,
        high: 8,
        urgent: 10
      }
    end

    test "serialize converts GraphQL value to database value" do
      assert PriorityEnum.serialize(:low) == 1
      assert PriorityEnum.serialize(:medium) == 5
      assert PriorityEnum.serialize(:high) == 8
      assert PriorityEnum.serialize(:urgent) == 10
    end

    test "parse converts database value to GraphQL value" do
      assert PriorityEnum.parse(1) == :low
      assert PriorityEnum.parse(5) == :medium
      assert PriorityEnum.parse(8) == :high
      assert PriorityEnum.parse(10) == :urgent
    end

    test "handles unknown values" do
      assert PriorityEnum.serialize(:unknown) == :unknown
      assert PriorityEnum.parse(999) == 999
    end
  end

  describe "Enum with string mapping" do
    defmodule RoleEnum do
      use GreenFairy.Enum

      enum "UserRole" do
        value :admin
        value :moderator
        value :user
      end

      # GraphQL uses atoms, database uses strings
      enum_mapping %{
        admin: "ADMIN",
        moderator: "MODERATOR",
        user: "USER"
      }
    end

    test "serialize converts GraphQL value to database string" do
      assert RoleEnum.serialize(:admin) == "ADMIN"
      assert RoleEnum.serialize(:moderator) == "MODERATOR"
      assert RoleEnum.serialize(:user) == "USER"
    end

    test "parse converts database string to GraphQL value" do
      assert RoleEnum.parse("ADMIN") == :admin
      assert RoleEnum.parse("MODERATOR") == :moderator
      assert RoleEnum.parse("USER") == :user
    end
  end

  describe "Enum with different names" do
    defmodule VisibilityEnum do
      use GreenFairy.Enum

      enum "ContentVisibility" do
        value :everyone
        value :friends_only
        value :only_me
      end

      # GraphQL uses descriptive names, Ecto uses shorter names
      enum_mapping %{
        everyone: :public,
        friends_only: :friends,
        only_me: :private
      }
    end

    test "serialize converts GraphQL value to Ecto value" do
      assert VisibilityEnum.serialize(:everyone) == :public
      assert VisibilityEnum.serialize(:friends_only) == :friends
      assert VisibilityEnum.serialize(:only_me) == :private
    end

    test "parse converts Ecto value to GraphQL value" do
      assert VisibilityEnum.parse(:public) == :everyone
      assert VisibilityEnum.parse(:friends) == :friends_only
      assert VisibilityEnum.parse(:private) == :only_me
    end
  end

  describe "Enum without mapping" do
    defmodule ColorEnum do
      use GreenFairy.Enum

      enum "Color" do
        value :red
        value :green
        value :blue
      end

      # No enum_mapping defined
    end

    test "serialize returns value unchanged (identity function)" do
      assert ColorEnum.serialize(:red) == :red
      assert ColorEnum.serialize(:green) == :green
      assert ColorEnum.serialize(:any_value) == :any_value
    end

    test "parse returns value unchanged (identity function)" do
      assert ColorEnum.parse(:red) == :red
      assert ColorEnum.parse(:blue) == :blue
      assert ColorEnum.parse(:any_value) == :any_value
    end
  end

  describe "Bidirectional transformation" do
    defmodule PaymentStatusEnum do
      use GreenFairy.Enum

      enum "PaymentStatus" do
        value :pending_payment
        value :paid
        value :refunded
        value :failed
      end

      enum_mapping %{
        pending_payment: "PENDING",
        paid: "COMPLETED",
        refunded: "REFUNDED",
        failed: "FAILED"
      }
    end

    test "round-trip transformation preserves values" do
      # GraphQL -> DB -> GraphQL
      assert :pending_payment
             |> PaymentStatusEnum.serialize()
             |> PaymentStatusEnum.parse() == :pending_payment

      assert :paid
             |> PaymentStatusEnum.serialize()
             |> PaymentStatusEnum.parse() == :paid

      # DB -> GraphQL -> DB
      assert "PENDING"
             |> PaymentStatusEnum.parse()
             |> PaymentStatusEnum.serialize() == "PENDING"

      assert "COMPLETED"
             |> PaymentStatusEnum.parse()
             |> PaymentStatusEnum.serialize() == "COMPLETED"
    end
  end
end

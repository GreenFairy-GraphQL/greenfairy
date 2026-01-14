defmodule Absinthe.Object.Relay.GlobalId do
  @moduledoc """
  Global ID encoding and decoding for Relay Object Identification.

  Relay uses globally unique IDs that encode both the type and the local ID
  of an object. This module provides functions to encode and decode these IDs.

  ## Format

  Global IDs are Base64-encoded strings in the format: `"TypeName:localId"`

  ## Usage

      # Encoding
      GlobalId.encode("User", 123)
      #=> "VXNlcjoxMjM="

      GlobalId.encode(:user, "abc-def")
      #=> "VXNlcjphYmMtZGVm"

      # Decoding
      GlobalId.decode("VXNlcjoxMjM=")
      #=> {:ok, {"User", "123"}}

      GlobalId.decode!("VXNlcjoxMjM=")
      #=> {"User", "123"}

  ## In Types

  Use the `global_id` field helper to automatically encode IDs:

      type "User", struct: MyApp.User do
        implements Absinthe.Object.BuiltIns.Node

        global_id :id  # Uses the type name and struct's :id field
        field :email, :string
      end

  """

  @doc """
  Encodes a type name and local ID into a global ID.

  The type name can be an atom or string. Atoms are converted to
  PascalCase (e.g., `:user_profile` becomes `"UserProfile"`).

  ## Examples

      iex> GlobalId.encode("User", 123)
      "VXNlcjoxMjM="

      iex> GlobalId.encode(:user, "abc")
      "VXNlcjphYmM="

      iex> GlobalId.encode(:user_profile, 42)
      "VXNlclByb2ZpbGU6NDI="

  """
  @spec encode(atom() | String.t(), term()) :: String.t()
  def encode(type_name, local_id) when is_atom(type_name) do
    encode(atom_to_type_name(type_name), local_id)
  end

  def encode(type_name, local_id) when is_binary(type_name) do
    "#{type_name}:#{local_id}"
    |> Base.encode64()
  end

  @doc """
  Decodes a global ID into its type name and local ID.

  Returns `{:ok, {type_name, local_id}}` on success, or `{:error, reason}` on failure.

  ## Examples

      iex> GlobalId.decode("VXNlcjoxMjM=")
      {:ok, {"User", "123"}}

      iex> GlobalId.decode("invalid")
      {:error, :invalid_global_id}

  """
  @spec decode(String.t()) :: {:ok, {String.t(), String.t()}} | {:error, atom()}
  def decode(global_id) when is_binary(global_id) do
    with {:ok, decoded} <- Base.decode64(global_id),
         [type_name, local_id] <- String.split(decoded, ":", parts: 2) do
      {:ok, {type_name, local_id}}
    else
      :error -> {:error, :invalid_global_id}
      _ -> {:error, :invalid_global_id}
    end
  end

  def decode(_), do: {:error, :invalid_global_id}

  @doc """
  Decodes a global ID, raising on error.

  ## Examples

      iex> GlobalId.decode!("VXNlcjoxMjM=")
      {"User", "123"}

  """
  @spec decode!(String.t()) :: {String.t(), String.t()}
  def decode!(global_id) do
    case decode(global_id) do
      {:ok, result} -> result
      {:error, reason} -> raise ArgumentError, "Invalid global ID: #{reason}"
    end
  end

  @doc """
  Extracts just the type name from a global ID.

  ## Examples

      iex> GlobalId.type("VXNlcjoxMjM=")
      {:ok, "User"}

  """
  @spec type(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def type(global_id) do
    case decode(global_id) do
      {:ok, {type_name, _}} -> {:ok, type_name}
      error -> error
    end
  end

  @doc """
  Extracts just the local ID from a global ID.

  ## Examples

      iex> GlobalId.local_id("VXNlcjoxMjM=")
      {:ok, "123"}

  """
  @spec local_id(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def local_id(global_id) do
    case decode(global_id) do
      {:ok, {_, local_id}} -> {:ok, local_id}
      error -> error
    end
  end

  @doc """
  Converts a global ID's local ID to an integer if possible.

  ## Examples

      iex> GlobalId.decode_id("VXNlcjoxMjM=")
      {:ok, {"User", 123}}

      iex> GlobalId.decode_id("VXNlcjphYmM=")
      {:ok, {"User", "abc"}}

  """
  @spec decode_id(String.t()) :: {:ok, {String.t(), integer() | String.t()}} | {:error, atom()}
  def decode_id(global_id) do
    case decode(global_id) do
      {:ok, {type_name, local_id}} ->
        parsed_id =
          case Integer.parse(local_id) do
            {int, ""} -> int
            _ -> local_id
          end

        {:ok, {type_name, parsed_id}}

      error ->
        error
    end
  end

  # Converts an atom like :user_profile to "UserProfile"
  defp atom_to_type_name(atom) do
    atom
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join()
  end
end

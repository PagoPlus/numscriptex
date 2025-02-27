defmodule Numscriptex.Posting do
  @moduledoc """
  `Numscriptex.Postings` represents a financial transaction made with [Numscript](https://docs.formance.com/numscript/)
  """

  alias Numscriptex.Utilities

  @derive JSON.Encoder
  defstruct amount: nil,
            decimal_amount: nil,
            asset: nil,
            destination: nil,
            source: nil

  @typedoc """
  Type that represents `Numscriptex.Posting` struct.

  ## Fields
  * `:source` account whose the money came from
  * `:asset` the asset were the transaction was made
  * `:destination` account whose the money will go to
  * `:amount` amount of money transferred (integer)
  * `:decimal_amount` amount of money transferred, but as float
  """
  @type t() :: %__MODULE__{
          amount: pos_integer(),
          decimal_amount: float(),
          asset: bitstring(),
          destination: bitstring(),
          source: bitstring()
        }

  @spec from_list(list(map())) :: list(__MODULE__.t())
  def from_list(postings) do
    Enum.map(postings, &from_map/1)
  end

  @spec from_map(map()) :: __MODULE__.t()
  def from_map(posting) do
    put_decimal_amount(posting)
  end

  defp put_decimal_amount(posting) when not is_struct(posting) do
    posting
    |> Map.put(:decimal_amount, 0)
    |> then(fn elem -> struct(%__MODULE__{}, elem) end)
    |> put_decimal_amount()
  end

  defp put_decimal_amount(posting) do
    decimal_places = Utilities.decimal_places_from_asset(posting.asset)
    decimal_amount = Utilities.integer_to_decimal(posting.amount, decimal_places)

    %{posting | decimal_amount: decimal_amount}
  end
end

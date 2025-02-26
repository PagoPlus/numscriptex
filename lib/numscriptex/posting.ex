defmodule Numscriptex.Posting do
  @moduledoc """
  `Numscriptex.Postings` represents a financial transaction made with [Numscript](https://docs.formance.com/numscript/)
  """

  @derive JSON.Encoder
  defstruct amount: nil,
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
  """
  @type t() :: %__MODULE__{
          amount: pos_integer(),
          asset: bitstring(),
          destination: bitstring(),
          source: bitstring()
        }

  @spec from_list(map()) :: list(__MODULE__.t())
  def from_list(postings) do
    Enum.map(postings, &from_map/1)
  end

  @spec from_list(map()) :: __MODULE__.t()
  def from_map(map) do
    struct(%__MODULE__{}, map)
  end
end

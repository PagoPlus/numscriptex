defmodule UtilitiesTest do
  use ExUnit.Case
  doctest Utilities

  describe "normalize_keys/2" do
    test "string keys to atom keys" do
      map = %{
        "foo" => %{
          "bar" => [
            %{"baz" => 100},
            %{"fiz" => 100},
            %{"buz" => 100}
          ]
        }
      }

      atom_keys_map = Utilities.normalize_keys(map, :atom)

      assert atom_keys_map === %{
        foo: %{
          bar: [
            %{baz: 100},
            %{fiz: 100},
            %{buz: 100}
            ]
        }
      }
    end

    test "atom keys to string keys" do
      map = %{
        foo: %{
          bar: [
            %{baz: 100},
            %{fiz: 100},
            %{buz: 100}
            ]
        }
      }
      string_keys_map = Utilities.normalize_keys(map, :string)

      assert string_keys_map === %{
        "foo" => %{
          "bar" => [
            %{"baz" => 100},
            %{"fiz" => 100},
            %{"buz" => 100}
          ]
        }
      }
    end
  end
end

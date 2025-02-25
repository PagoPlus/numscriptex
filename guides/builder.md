# Builder
This is a feature that makes possible to build numscripts dynamically within your application.

## Usage
You just need to call `Numscriptex.Builder.build/1` with the metadata necessary to build your numscript.

### Metadata
Metadata is the sole argument you need to use the `build/1` function, wich have the following fields:

Required fields:
- splits: a list of metadata needed to build numscripts (explained below)

Optional fields:
- percent_asset: monetary asset (BRL, USD, EUR, and etc.) to use when build numscripts using percentage values.
- remaining_to¹: where the rest of the money will go after the transaction
  - Only needed if you want to designate an specific destination, the default is `remaining kept` wich makes the remainder go back to the source.

About the "list of metadata" mentioned on the `split` field above:
Required fields:
- account: account whose the money will go to
- amount: amount of money transferred (accepts both integer and float)
- type: the amount type, accepts two values:
  - fixed: treats the `amount` field as a number
  - percent: treats the `amount` field as a percentage value

Optional fields:
Also accepts `aplits` and `remaining_to` fields, and a `asset` field:

- splits: in this case, this field is only neccessary if you want to build [nested destinations](https://docs.formance.com/numscript/reference/destinations#nested-destinations), and therefore it is only valid if the `type` field value is `:percent`
- asset: also the monetary asset, but in this case is only needed on `:fixed` types

The `remaining_to` field continues with the same behaviour as above.

### Example
With the metadata type above in mind, let's build a simple numscript.
```elixir
# metadata:
%{
  splits: [
    %{
      type: :percent,
      amount: 20,
      account: "some:destination"
    }
  ]
  remaining_to: "another:destination",
  percent_asset: "USD/2"
}
```
Wich will generate the following numscript:
```
send [USD/2 *] (
  source = @user
  destination = {
    20% to @some:destination
    remaining to @another:destination
  }
)
```
If the `:remaining_to` field were not defined, the remaining would be kept:
```
send [USD/2 *] (
  source = @user
  destination = {
    20% to @some:destination
    remaining kept
  }
)
```

P.S.: The percent amount types will always be executed first, so we can assure that
all of the percentage is based off of the initial value. This feature is still in
development as we speak, but soon we will have more flexibility in those regards.

## Examples
### Example 1
Both fixed and percent types:
```elixir
%{
  splits: [
    %{
      type: :fixed,
      amount: 5,
      asset: "USD/2",
      account: "some:destination:a"
    },
    %{
      type: :percent,
      amount: 20,
      account: "some:destination:b"
    }
  ],
  remaining_to: "some:destination:c",
  percent_asset: "USD/2"
}
```
Will build:
```
send [USD/2 *] (
  source = @user
  destination = {
    20% to @some:destination:b
    remaining kept
  }
)

send [USD/2 500] (
  source = @user
  destination = @some:destination:a
)
```

### Example 2
Nested percent type plus fixed
```elixir
%{
  splits: [
    %{
      type: :fixed,
      amount: 12.5,
      asset: "USD/2",
      account: "some:destination:a"
    },
    %{
      type: :percent,
      amount: 30,
      remaining_to: "remaining:destination:b",
      splits: [
        %{
          type: :percent,
          amount: 40,
          account: "some:destination:c"
        },
        %{
          type: :percent,
          amount: 20,
          account: "some:destination:b"
        }
      ]
    }
  ],
  remaining_to: "remaining:destination:a",
  percent_asset: "USD/2"
}
```
Will build:
```
send [USD/2 *] (
  source = @user
  destination = {
    30% to {
      40% to @some:destination:c
      20% to @some:destination:b
      remaining to remaining:destination:b
    }
    remaining to remaining:destination:a
  }
)

send [USD/2 1250] (
  source = @user
  destination = @some:destination:a
)
```
Note that the `asset` field inside of nested destinations will be ignored, given that
they all go under the same `send` scope.

### Example 3
Nested percent type plus fixed, and with fixed inside nests
```elixir
%{
  splits: [
    %{
      type: :fixed,
      amount: 10.5,
      asset: "EUR/2",
      account: "some:destination:a"
    },
    %{
      type: :percent,
      amount: 20,
      account: "some:destination:b"
    },
    %{
      type: :percent,
      amount: 30,
      remaining_to: "remaining:destination:b",
      splits: [
        %{
          type: :fixed,
          amount: 12.5,
          asset: "USD/2",
          account: "some:destination:c"
        },
        %{
          type: :percent,
          amount: 15,
          account: "some:destination:e"
        },
        %{
          type: :percent,
          amount: 20,
          account: "some:destination:d"
        },
        %{
          type: :percent,
          amount: 50,
          remaining_to: "remaining:destination:c",
          splits: [
            %{
              type: :fixed,
              amount: 5,
              asset: "BRL/2",
              account: "some:destination:b"
            },
            %{
              type: :percent,
              amount: 20,
              account: "some:destination:a"
            },
            %{
              type: :percent,
              amount: 27,
              account: "some:destination:a"
            }
          ]
        }
      ]
    }
  ],
  remaining_to: "remaining:destination:a",
  percent_asset: "EUR/2"
}
```
Will build:
```
send [EUR/2 *] (
  source = @user
  destination = {
    20% to @some:destination:b
    30% to {
      15% to @some:destination:e
      20% to @some:destination:d
      50% to {
        20% to @some:destination:a
        27% to @some:destination:a
        remaining to @remaining:destination:c
      }
      remaining to @remaining:destination:b
    }
    remaining to @remaining:destination:a
  }
)

send [USD/2 1250] (
  source = @user
  destination = @some:destination:c
)

send [BRL/2 500] (
  source = @user
  destination = @some:destination:b
)

send [EUR/2 1050] (
  source = @user
  destination = @some:destination:a
)
```
Note that the `fixed` types inside nests will be popped out and still be build after
the `percent` types.

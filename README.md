# Loe

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.md)
[![Hex.pm](https://img.shields.io/hexpm/v/loe.svg)](https://hex.pm/packages/loe)
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/loe/)

**Loe** is a tiny Elixir library for working with values that may be raw (`val`), wrapped as `{:ok, val}`, or wrapped as `{:error, reason}`.

It provides simple, composable tools to normalize, transform, and chain values using functions or infix macros — making it ideal for expressive, railway-style flows.

## Terminology

Throughout this library and documentation:

- **Raw value** — A plain value not wrapped in a tuple (e.g., `42`)
- **Success value** — A two-element tuple in the form `{:ok, value}`
- **Error value** — A two-element tuple in the form `{:error, reason}`

Tuples like `{:ok, a, b}` or `{:error, a, b}` are not supported — they’ll be treated as raw values.

## Core Functions & Macros

### [`lift/2`](`Loe.lift/2`) or [`~>>`](`Loe.~>>/2`)

Transforms a raw or success value using a function.

- Automatically wraps raw inputs as `{:ok, val}`
- Skips transformation if the input is an error
- Wraps raw results as `{:ok, val}` if the function returns a plain value

```elixir
4 ~>> (fn x -> x * 2 end).()        # => {:ok, 8}
{:ok, 3} ~>> (fn x -> {:ok, x + 1} end).()   # => {:ok, 4}
{:error, :fail} ~>> (fn _ -> :skip end).()   # => {:error, :fail}
```

### [`tfil/2`](`Loe.tfil/2`) or [`<~>`](`Loe.<~>/2`)

Transforms an error value using a function.

- Only applies when the input is an error
- Returns a new `{:error, transformed}` tuple
- Passes through success and raw values unchanged

```elixir
{:error, :bad} <~> fn e -> "Reason: #{e}" end
# => {:error, "Reason: bad"}
```

### [`unwrap!/1`](`Loe.unwrap!/1`)

Unwraps a success value or raises on error.

```elixir
Loe.unwrap!({:ok, 42})     # => 42
Loe.unwrap!({:error, :fail}) # => ** (RuntimeError) Loe.unwrap!/1 encountered error: :fail
```

## Installation

Add `:loe` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:loe, "~> 0.1.2"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Usage

Let’s say you have some simple input validation logic:

```elixir
defmodule Validation do
  def integer(v) when is_integer(v), do: {:ok, v}
  def integer(_), do: {:error, :not_integer}

  def positive(v) when v > 0, do: {:ok, v}
  def positive(_), do: {:error, :not_positive}
end

defmodule Data do
  def double(v), do: 2 * v
end

defmodule Error do
  def transform(reason), do: %{message: "Validation failed: #{reason}"}
end
```

Now import Loe to enable its macros:

```elixir
import Loe
```

And chain validations like this:

```elixir
4
~>> Validation.integer()
~>> Validation.positive()
# => {:ok, 4}

-4
~>> Validation.integer()
~>> Validation.positive()
# => {:error, :not_positive}

3.4
~>> Validation.integer()
~>> Validation.positive()
<~> Error.transform()
# => {:error, %{message: "Validation failed: not_integer"}}
```

Example `Validation` functions return wrapped results, while `Data.double/1` returns a raw value.
Thanks to [`lift/2`](`Loe.lift/2`), Loe handles both seamlessly — so you can chain functions without worrying about return formats:

```elixir
4
~>> Validation.integer()
~>> Validation.positive()
~>> Data.double()
<~> Error.transform()
# => {:ok, 8}
```

### Anonymous functions work too

```elixir
2
~>> (fn x -> x * 3 end).()
~>> (fn x -> {:ok, x + 1} end).()
<~> (fn e -> {:error, {:wrapped, e}} end).()
# => {:ok, 7}
```

### Works with error values directly

```elixir
{:error, :oops}
<~> (fn e -> "Got: #{e}" end).()
# => {:error, "Got: oops"}
```

### Unwrapping

```elixir
{:ok, 42} |> Loe.unwrap!()
# => 42

{:error, :fail} |> Loe.unwrap!()
# => ** (RuntimeError) Loe.unwrap!/1 encountered error: :fail
```

### Accepts raw or success values

```elixir
# Both forms produce the same result:
4
~>> Validation.integer()
~>> Validation.positive()

{:ok, 4}
~>> Validation.integer()
~>> Validation.positive()
```

## Documentation

Full API docs available on [HexDocs](https://hexdocs.pm/loe).

## Contributing

Contributions are welcome via issues or pull requests.
Created and maintained by [Centib](https://github.com/Centib).

## License

Released under the [MIT License](LICENSE.md).

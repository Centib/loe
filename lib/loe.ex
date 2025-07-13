defmodule Loe do
  @moduledoc """
  Loe is a tiny Elixir library for chaining `{:ok, _}`/`{:error, _}` results and raw values with elegant macros and helpers.

  It helps normalize, transform, and chain computations while handling both successful and error results in a consistent way.

  ### Functions

  - `lift/2` — Applies a function to a value if it is raw or `{:ok, _}`. Leaves `{:error, _}` or `:error` unchanged. Always returns `{:ok, _}` or `{:error, _}`.
  - `tfil/2` — The inverse of `lift/2`. Applies a function **only** if the input is `:error` or `{:error, _}`. Leaves successful values unchanged.
  - `unwrap!/1` — Extracts the value from `{:ok, value}`. Raises if the value is `:error` or `{:error, _}`.

  ### Operators

  - `~>>` — Infix form of `lift/2`, for chaining operations on success.
  - `<~>` — Infix form of `tfil/2`, for transforming errors.

  ### Example

  ```
  value
  ~>> validate()
  ~>> normalize()
  <~> wrap_error()
  ```
  """

  @typedoc "Input may be a raw value, `{:ok, value}`, `{:error, error}`, or `:error`."
  @type input(a, e) :: a | {:ok, a} | {:error, e} | :error

  @typedoc "Normalized result value: either `{:ok, value}` or `{:error, error}`."
  @type result(b, e) :: {:ok, b} | {:error, e}

  @doc """
  Applies a function to a raw or boxed input and returns a normalized result.

  ## Accepted input:
    - A raw value `a`
    - A tuple `{:ok, a}`
    - An error tuple `{:error, e}`
    - A bare `:error`

  ## Function `fun` may return:
    - A raw value `b`
    - A tuple `{:ok, b}`
    - A tuple `{:error, e}`
    - A bare `:error`

  ## Result:
    Always returns either `{:ok, b}` or `{:error, e}`.

  ## Examples

      iex> Loe.lift(2, fn x -> x * 2 end)
      {:ok, 4}

      iex> Loe.lift({:ok, 2}, fn x -> {:ok, x * 3} end)
      {:ok, 6}

      iex> Loe.lift({:ok, 2}, fn x -> x * 2 end)
      {:ok, 4}

      iex> Loe.lift(2, fn _x -> :error end)
      {:error, :error}

      iex> Loe.lift(2, fn _x -> {:error, :bad} end)
      {:error, :bad}

      iex> Loe.lift(:error, fn _ -> 123 end)
      {:error, :error}

      iex> Loe.lift({:error, :bad}, fn _ -> 123 end)
      {:error, :bad}

  """
  @spec lift(input(a, e), (a -> b | result(b, e))) :: result(b, e)
        when a: any, b: any, e: any
  def lift({:error, reason}, _fun), do: {:error, reason}
  def lift(:error, _fun), do: {:error, :error}
  def lift({:ok, val}, fun), do: do_lift(fun, val)
  def lift(val, fun), do: do_lift(fun, val)

  defp do_lift(fun, val) do
    case fun.(val) do
      {:ok, _} = ok -> ok
      {:error, _} = err -> err
      :error -> {:error, :error}
      other -> {:ok, other}
    end
  end

  @doc """
  Unwraps a result value or raises an error.

  - If given `{:ok, value}`, returns `value`.
  - If given `{:error, reason}`, raises `RuntimeError` with the reason.
  - If given anything else, raises `ArgumentError`.

  ## Examples

      iex> Loe.unwrap!({:ok, 42})
      42

      iex> Loe.unwrap!({:error, :fail})
      ** (RuntimeError) Loe.unwrap!/1 encountered error: :fail

      iex> Loe.unwrap!(123)
      ** (ArgumentError) Loe.unwrap!/1 expected {:ok, _} or {:error, _}, got: 123

  """
  @spec unwrap!(any) :: any | no_return()
  def unwrap!({:ok, val}), do: val

  def unwrap!({:error, exception}) when is_exception(exception) do
    raise exception
  end

  def unwrap!({:error, reason}) do
    raise RuntimeError, "Loe.unwrap!/1 encountered error: #{inspect(reason)}"
  end

  def unwrap!(other) do
    raise ArgumentError,
          "Loe.unwrap!/1 expected {:ok, _} or {:error, _}, got: #{inspect(other)}"
  end

  @doc """
  Infix `lift`.

  Allows chaining like `value ~>> fun()`.

  ## Examples

      iex> import Loe
      ...> 5 ~>> (fn x -> x + 2 end).()
      {:ok, 7}

      iex> import Loe
      ...> {:ok, 10} ~>> (fn x -> {:ok, x * 2} end).()
      {:ok, 20}

      iex> import Loe
      ...> :error ~>> (fn x -> x + 1 end).()
      {:error, :error}
  """
  defmacro left ~>> {call, line, args} do
    value = quote do: value

    args = [value | args || []]

    quote do
      Loe.lift(
        unquote(left),
        fn unquote(value) -> unquote({call, line, args}) end
      )
    end
  end

  @doc """
  Applies a function to a raw or boxed error input and returns a normalized result.

  ## Accepted input:
    - A raw value `a`
    - A tuple `{:ok, a}`
    - An error tuple `{:error, e}`
    - A bare `:error`

  ## Function `fun` may return:
    - A raw value `b`
    - A tuple `{:ok, b}`
    - A tuple `{:error, e}`
    - A bare `:error`

  ## Result:
    Always returns either `{:ok, b}` or `{:error, e}`.

  ## Examples

      iex> Loe.tfil(2, fn _x -> :ignore_and_wrap end)
      {:ok, 2}

      iex> Loe.tfil({:ok, 2}, fn _x -> :ignore end)
      {:ok, 2}

      iex> Loe.tfil(:error, fn x -> %{a: x, b: 300} end)
      {:error, %{a: :error, b: 300}}

      iex> Loe.tfil({:error, :bad}, fn x -> %{a: x, b: 300} end)
      {:error, %{a: :bad, b: 300}}

      iex> Loe.tfil(:error, fn _x -> {:error, :reason} end)
      {:error, :reason}

      iex> Loe.tfil({:error, :bad}, fn _x -> {:error, :too_bad} end)
      {:error, :too_bad}

  """
  @spec tfil(input(a, e), (e -> f | result(a, f))) :: result(a, f)
        when a: any, e: any, f: any
  def tfil({:error, reason}, fun), do: do_tfil(fun, reason)
  def tfil(:error, fun), do: do_tfil(fun, :error)
  def tfil({:ok, val}, _fun), do: {:ok, val}
  def tfil(val, _fun), do: {:ok, val}

  defp do_tfil(fun, val) do
    case fun.(val) do
      {:ok, _} = ok -> ok
      {:error, _} = err -> err
      :error -> {:error, :error}
      other -> {:error, other}
    end
  end

  @doc """
  Infix `tfil`.

  Allows chaining like `value <~> fun()`.

  ## Examples

      iex> import Loe
      ...> 5 <~> (fn x -> x + 2 end).()
      {:ok, 5}

      iex> import Loe
      ...> {:error, 10} <~> (fn x -> x * 2 end).()
      {:error, 20}

      iex> import Loe
      ...> {:error, 10} <~> (fn x -> {:ok, x * 2} end).()
      {:ok, 20}

      iex> import Loe
      ...> :error <~> (fn _x -> {:error, :nice} end).()
      {:error, :nice}
  """
  defmacro left <~> {call, line, args} do
    value = quote do: value

    args = [value | args || []]

    quote do
      Loe.tfil(
        unquote(left),
        fn unquote(value) -> unquote({call, line, args}) end
      )
    end
  end
end

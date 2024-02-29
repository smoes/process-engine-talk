defmodule ProcessEngineTalk.ProcessModel.Conditions do
  @moduledoc """
  This module contains conditions for edge transitions of the workflow engine.
  """

  alias __MODULE__

  defmodule And do
    @moduledoc """
    Logical And
    """
    alias ProcessEngineTalk.ProcessModel.Conditions
    use TypedStruct

    typedstruct do
      field(:a, Conditions.inner_t())
      field(:b, Conditions.inner_t())
    end
  end

  defmodule Or do
    @moduledoc """
    Logical or
    """
    alias ProcessEngineTalk.ProcessModel.Conditions
    use TypedStruct

    typedstruct do
      field(:a, Conditions.inner_t())
      field(:b, Conditions.inner_t())
    end
  end

  defmodule Equals do
    @moduledoc """
    Checks equality
    """
    alias ProcessEngineTalk.ProcessModel.Conditions
    use TypedStruct

    typedstruct do
      field(:a, Conditions.inner_t())
      field(:b, Conditions.inner_t())
    end
  end

  defmodule IsType do
    @moduledoc """
    Checks if a given struct has a specific type
    """
    alias ProcessEngineTalk.ProcessModel.Conditions.Value
    use TypedStruct

    typedstruct do
      field(:type, Value.t())
    end
  end

  defmodule Field do
    @moduledoc """
    Fetches a field from a given event
    """
    alias ProcessEngineTalk.ProcessModel.Conditions.Value
    use TypedStruct

    typedstruct do
      field(:name, Value.t())
    end
  end

  defmodule Value do
    @moduledoc """
    Wraps a value
    """

    use TypedStruct

    typedstruct do
      field(:x, any())
    end
  end

  defmodule AndThen do
    @moduledoc """
    Appends conditions to be evaluated one after the other
    """

    use TypedStruct
    alias ProcessEngineTalk.ProcessModel.Conditions

    typedstruct do
      field(:a, Conditions.t())
      field(:b, Conditions.t())
    end
  end

  @type inner_t :: And.t() | Or.t() | Equals.t() | IsType.t() | Field.t() | Value.t()
  @type t :: inner_t | AndThen.t()

  defmacro value_true() do
    quote do
      %Value{x: true}
    end
  end

  @doc """
  Creates an and-condition.

     iex> import ProcessEngineTalk.ProcessModel.Conditions
     iex> alias ProcessEngineTalk.ProcessModel.Conditions
     iex> cand(value(1), value(2))
     %Conditions.And{a: %Conditions.Value{x: 1}, b: %Conditions.Value{x: 2}}
  """
  @spec cand(inner_t(), inner_t()) :: And.t()
  def cand(value_true(), value_true()), do: value_true()
  def cand(value_true(), b), do: b
  def cand(a, value_true()), do: a
  def cand(a, b), do: %And{a: a, b: b}

  @doc """
  Creates an or-condition.

     iex> import ProcessEngineTalk.ProcessModel.Conditions
     iex> alias ProcessEngineTalk.ProcessModel.Conditions
     iex> cor(value(1), value(2))
     %Conditions.Or{a: %Conditions.Value{x: 1}, b: %Conditions.Value{x: 2}}
  """
  @spec cor(inner_t(), inner_t()) :: Or.t()
  def cor(value_true(), _), do: value_true()
  def cor(_, value_true()), do: value_true()
  def cor(a, b), do: %Or{a: a, b: b}

  @doc """
  Creates an equals-condition.

     iex> import ProcessEngineTalk.ProcessModel.Conditions
     iex> alias ProcessEngineTalk.ProcessModel.Conditions
     iex> equals(value(1), value(2))
     %Conditions.Equals{a: %Conditions.Value{x: 1}, b: %Conditions.Value{x: 2}}
  """
  @spec equals(inner_t(), inner_t()) :: Equals.t()
  def equals(a, b), do: %Equals{a: a, b: b}

  @doc """
  Creates an is_type-condition.

     iex> import ProcessEngineTalk.ProcessModel.Conditions
     iex> alias ProcessEngineTalk.ProcessModel.Conditions
     iex> is_type(AEvent)
     %Conditions.IsType{type: %Conditions.Value{x: AEvent}}
  """
  @spec is_type(atom()) :: IsType.t()
  def is_type(t), do: %IsType{type: value(t)}

  @doc """
  Creates a field-condition.

     iex> import ProcessEngineTalk.ProcessModel.Conditions
     iex> alias ProcessEngineTalk.ProcessModel.Conditions
     iex> field(:hello)
     %Conditions.Field{name: %Conditions.Value{x: :hello}}
  """
  @spec field(atom()) :: Field.t()
  def field(field), do: %Field{name: value(field)}

  @doc """
  Creates a value-condition.

     iex> import ProcessEngineTalk.ProcessModel.Conditions
     iex> alias ProcessEngineTalk.ProcessModel.Conditions
     iex> value(123)
     %Conditions.Value{x: 123}
  """
  @spec value(any()) :: Value.t()
  def value(x), do: %Value{x: x}

  @doc """
  Creates a true value

     iex> import ProcessEngineTalk.ProcessModel.Conditions
     iex> alias ProcessEngineTalk.ProcessModel.Conditions
     iex> ctrue()
     %Conditions.Value{x: true}
  """
  @spec ctrue() :: Value.t()
  def ctrue(), do: %Value{x: true}

  @doc """
  Creates a false value

     iex> import ProcessEngineTalk.ProcessModel.Conditions
     iex> alias ProcessEngineTalk.ProcessModel.Conditions
     iex> cfalse()
     %Conditions.Value{x: false}
  """
  @spec cfalse() :: Value.t()
  def cfalse(), do: %Value{x: false}

  @spec event_field_equals(atom(), atom(), any()) :: Conditions.t()
  def event_field_equals(event_type, field_name, x) do
    cand(is_type(event_type), equals(field(field_name), value(x)))
  end

  @doc """
  Creates an and then condition. This means, that the second condition
  is only tried to being evaluated after the first already was.

     iex> import ProcessEngineTalk.ProcessModel.Conditions
     iex> alias ProcessEngineTalk.ProcessModel.Conditions
     iex> and_then(cfalse(), cfalse())
     %Conditions.AndThen{a: cfalse(), b: cfalse()}
  """
  @spec and_then(inner_t(), inner_t()) :: AndThen.t()
  def and_then(value_true(), b), do: b
  def and_then(a, value_true()), do: a
  def and_then(a, b), do: %AndThen{a: a, b: b}

  @doc """
  Evaluates a condition under a given value.
  """
  @spec eval(t(), struct()) :: :done | {:rest, t()}
  def eval(condition, value), do: eval_toplevel(condition, value)

  @spec eval_toplevel(t(), struct()) :: :done | {:rest, t()}
  defp eval_toplevel(%AndThen{a: a, b: b} = condition, value) do
    if(eval_helper(a, value)) do
      if eval_helper(b, value) do
        :done
      else
        {:rest, b}
      end
    else
      {:rest, condition}
    end
  end

  defp eval_toplevel(condition, value) do
    if eval_helper(condition, value) do
      :done
    else
      {:rest, condition}
    end
  end

  @spec eval_helper(inner_t(), struct()) :: any()
  defp eval_helper(condition, value) do
    case condition do
      %And{a: a, b: b} -> eval_helper(a, value) && eval_helper(b, value)
      %Or{a: a, b: b} -> eval_helper(a, value) || eval_helper(b, value)
      %Equals{a: a, b: b} -> eval_helper(a, value) == eval_helper(b, value)
      %IsType{type: t} -> value && value.__struct__ == eval_helper(t, value)
      %Field{name: field} -> Map.get(value, eval_helper(field, value))
      %Value{x: x} -> x
    end
  end
end

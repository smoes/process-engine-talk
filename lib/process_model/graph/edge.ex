defmodule ProcessEngineTalk.ProcessModel.Graph.Edge do
  @moduledoc """
  An edge representation for a graph.

  An edge consists of

  - a node id, the edge is originating from
  - a node id, the edge is leading to
  - a condition for the edge traversal
  """

  alias ProcessEngineTalk.ProcessModel.Graph.Node
  alias ProcessEngineTalk.ProcessModel.Conditions

  alias __MODULE__

  use TypedStruct

  typedstruct do
    field(:from, Node.id_t())
    field(:to, Node.id_t())
    field(:condition, Conditions.t())
  end

  @spec make(Node.id_t(), Node.id_t(), Conditions.t()) :: Edge.t()
  def make(from, to, condition), do: %Edge{from: from, to: to, condition: condition}

  @spec map(Edge.t(), (Conditions.t() -> Conditions.t())) :: Edge.t()
  def map(%Edge{condition: condition} = edge, foo) do
    %Edge{edge | condition: foo.(condition)}
  end
end

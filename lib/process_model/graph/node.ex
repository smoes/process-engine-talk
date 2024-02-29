defmodule ProcessEngineTalk.ProcessModel.Graph.Node do
  @moduledoc """
  A node representation for a graph.

  A node consists of

  - an id
  - data that carries further information about the node
  """

  alias __MODULE__

  use TypedStruct

  @type id_t :: any()
  @type data_t :: any()

  typedstruct do
    field(:id, id_t())
    field(:data, data_t())
  end

  @spec make(id_t(), data_t()) :: Node.t()
  def make(id, data), do: %Node{id: id, data: data}

  @spec map(Node.t(), (data_t() -> data_t())) :: Node.t()
  def map(%Node{data: data} = node, foo) do
    %Node{node | data: foo.(data)}
  end
end

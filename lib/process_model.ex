defmodule ProcessEngineTalk.ProcessModel do
  @moduledoc """
  This module contains functionality that is needed to model workflows.

  A workflow consists of the following:
  - a graph representing the workflow

  A workflow is a special graph that always has exactly one start-node and
  one end-node. This propery is used to define special combinators:

  - `&append/2` appends two workflows 
  - `&one_of/2` connects to workflows in parallel so that only one is executed
  - `&both/2` connects to workflows in parallel so that both are executed
  - `&loop/2` takes a workflow and adds a transition from the end to the start
  - `&with_exit/3` adds a special exit node that, when entered, terminates the
     workflows evaluation

  ProcessModels must only be created using these combinators since the evaluation
  relies on the resulting structural properties.
  """
  alias ProcessEngineTalk.ProcessModel.Data.Start
  alias ProcessEngineTalk.ProcessModel.Data.End
  alias ProcessEngineTalk.ProcessModel.Data.Or
  alias ProcessEngineTalk.ProcessModel.Data.And
  alias ProcessEngineTalk.ProcessModel.Data.Join
  alias ProcessEngineTalk.ProcessModel.Graph
  alias ProcessEngineTalk.ProcessModel.Activity
  alias ProcessEngineTalk.ProcessModel.Conditions
  alias __MODULE__

  @start_id :start
  @end_id :end

  @type data_t :: Or.t() | And.t() | Join.t() | End.t() | Start.t() | Activity.t()

  use TypedStruct

  typedstruct do
    field(:graph, Graph.t())
  end

  @doc """
  Takes a node id and data and returns a valid workflow graph by
  adding start and end to the newly created node.
  """
  @spec make(data_t()) :: ProcessModel.t()
  def make(data) do
    node = Graph.Node.make(data.id, data)
    edge_1 = Graph.Edge.make(@start_id, node.id, constantly_true())
    edge_2 = Graph.Edge.make(node.id, @end_id, constantly_true())

    Graph.empty()
    |> Graph.add_node!(make_start_node())
    |> Graph.add_node!(make_end_node())
    |> Graph.add_node!(node)
    |> Graph.add_edge!(edge_1)
    |> Graph.add_edge!(edge_2)
    |> from_graph()
  end

  @doc """
  The neutral workflow under the append/2 operation.
  """
  @spec neutral() :: ProcessModel.t()
  def neutral() do
    edge = Graph.Edge.make(@start_id, @end_id, constantly_true())

    Graph.empty()
    |> Graph.add_node!(make_start_node())
    |> Graph.add_node!(make_end_node())
    |> Graph.add_edge!(edge)
    |> from_graph()
  end

  @doc """
  Appends two workflows by appending the nodes in front of end of
  the first to the nodes succeeding start of the second.

  Example:

  g1:   start -> :a -> end
  g2:   start -> :b -> end
  appended: start -> :a -> :b -> end

  If there are transition conditions that need to be merged, they are combined
  using `Combinators.and_then/2`.

  If multiple edges point to end or originate in start, all pairs of edges
  are inserted when appending.

  Returns a new workflow.

  Together with `neutral/0` this defines a monoid for workflows.
  """
  @spec append(ProcessModel.t(), ProcessModel.t()) :: ProcessModel.t()
  def append(%ProcessModel{graph: graph_1}, %ProcessModel{graph: graph_2}) do
    # these edges get deleted when deleting start and end nodes.
    end_edges = Graph.incomming_edges(graph_1, @end_id)
    start_edges = Graph.outgoing_edges(graph_2, @start_id)

    graph_1 = Graph.remove_node(graph_1, @end_id)
    graph_2 = Graph.remove_node(graph_2, @start_id)

    # we build all edge combination here
    edges =
      for end_edge <- end_edges, start_edge <- start_edges do
        condition = end_edge.condition |> Conditions.and_then(start_edge.condition)
        Graph.Edge.make(end_edge.from, start_edge.to, condition)
      end

    {:ok, g} = merge_graphs(graph_1, graph_2)
    {:ok, g} = Graph.add_edges(g, edges)
    from_graph(g)
  end

  @doc """
  Merges two workflows parallely by merging their start and
  end nodes correspondingly. For the resulting workflow only
  one of the branches is executed. This is decided at the or
  node, once one transition is taken.

  Example:

  g1:   start -> :a -> end
  g2:   start -> :b -> end
  both: start -- or --> :a -- join -> end
                  `---> :b ----'

  Returns a new workflow.

  Be aware that `neutral/2` is not neutral for this operation.
  """
  @spec one_of(ProcessModel.t(), ProcessModel.t()) :: ProcessModel.t()
  def one_of(%ProcessModel{} = wf_1, %ProcessModel{} = wf_2) do
    parallel_wf = parallel(wf_1, wf_2)

    or_node_id = Ecto.UUID.generate()
    join_node_id = Ecto.UUID.generate()

    or_node = Or.make(or_node_id, join_node_id)
    join_node = Join.make(join_node_id, or_node_id)

    or_wf = make(or_node)
    join_wf = make(join_node)

    or_wf
    |> append(parallel_wf)
    |> append(join_wf)
  end

  @doc """
  Merges two workflows parallely by merging their start and
  end nodes correspondingly. For the resulting workflow both
  branches need to be executed to pass the join-node.

  Example:

  g1:   start -> :a -> end
  g2:   start -> :b -> end
  both: start -- and --> :a -- join -> end
                  `---> :b ----'

  Returns a new workflow.

  `neutral/2` is kind of the neutral element for this operation,
  not structurally but in execution.
  """
  @spec both(ProcessModel.t(), ProcessModel.t()) :: ProcessModel.t()
  def both(%ProcessModel{} = wf_1, %ProcessModel{} = wf_2) do
    parallel_wf = parallel(wf_1, wf_2)

    and_node_id = Ecto.UUID.generate()
    join_node_id = Ecto.UUID.generate()

    and_node = And.make(and_node_id, join_node_id)
    join_node = Join.make(join_node_id, and_node_id)

    and_wf = make(and_node)
    join_wf = make(join_node)

    and_wf
    |> append(parallel_wf)
    |> append(join_wf)
  end

  @doc """
  Loops a workflow based on a condition.
  A new back edge is added:

  g1:   start -> :a -> end
  loop: start -- join --> :a -- or -> end
                  ^             |
                  `-------------'
  """
  @spec loop(ProcessModel.t(), Conditions.t()) :: ProcessModel.t()
  def loop(%ProcessModel{} = wf, condition) do
    or_node_id = Ecto.UUID.generate()
    join_node_id = Ecto.UUID.generate()

    or_node = Or.make(or_node_id, join_node_id)
    join_node = Join.make(join_node_id, or_node_id)

    or_wf = make(or_node)
    join_wf = make(join_node)

    join_wf
    |> append(wf)
    |> append(or_wf)
    |> unsafe_add_edge!(or_node_id, join_node_id, condition)
  end

  @doc """
  Overrides the conditions on all transitions pointing to end. 
  """
  @spec with_end_condition(ProcessModel.t(), Conditions.t()) :: ProcessModel.t()
  def with_end_condition(%ProcessModel{graph: graph}, condition) do
    end_edges = Graph.incomming_edges(graph, @end_id)
    graph = Graph.remove_edges(graph, Enum.map(end_edges, fn edge -> {edge.from, edge.to} end))
    new_edges = Enum.map(end_edges, fn edge -> %Graph.Edge{edge | condition: condition} end)
    Graph.add_edges!(graph, new_edges) |> from_graph()
  end

  @doc """
  Overrides the conditions on all transitions leaving start. 
  """
  @spec with_start_condition(ProcessModel.t(), Conditions.t()) :: ProcessModel.t()
  def with_start_condition(%ProcessModel{graph: graph}, condition) do
    start_edges = Graph.outgoing_edges(graph, @start_id)

    graph = Graph.remove_edges(graph, Enum.map(start_edges, fn edge -> {edge.from, edge.to} end))

    new_edges = Enum.map(start_edges, fn edge -> %Graph.Edge{edge | condition: condition} end)
    Graph.add_edges!(graph, new_edges) |> from_graph()
  end

  @doc """
  Returns all conditions of a node as a tuple with transitions target nodes.
  """
  @spec conditions_with_targets(ProcessModel.t(), Graph.Node.id_t()) ::
          list({Conditions.t(), Graph.Node.id_t()})
  def conditions_with_targets(%ProcessModel{graph: graph}, node) do
    Graph.outgoing_edges(graph, node)
    |> Enum.map(fn edge -> {edge.condition, edge.to} end)
  end

  @doc """
  Returns the data of a node.
  Raises if the node doesn't exist
  """
  @spec data(ProcessModel.t(), Graph.Node.id_t()) :: Graph.Node.data_t()
  def data(%ProcessModel{graph: graph}, node) do
    Graph.get_node(graph, node).data
  end

  @spec paths(ProcessModel.t(), Graph.Node.id_t(), Graph.Node.id_t()) ::
          {:ok, list(list(Node.t()))} | {:error, :node_does_not_exist}
  def paths(%ProcessModel{graph: graph}, from, to), do: Graph.paths(graph, from, to)

  @doc """
  Returns the start node id.
  """
  @spec start_node_id() :: any()
  def start_node_id(), do: @start_id

  @doc """
  Returns the end node id.
  """
  @spec end_node_id() :: any()
  def end_node_id(), do: @end_id

  @spec unsafe_add_edge!(ProcessModel.t(), Graph.Node.id_t(), Graph.Node.id_t(), Conditions.t()) ::
          ProcessModel.t()
  defp unsafe_add_edge!(%ProcessModel{graph: graph} = wf, from, to, condition) do
    edge = %Graph.Edge{from: from, to: to, condition: condition}
    graph = Graph.add_edge!(graph, edge)
    with_graph(wf, graph)
  end

  @spec parallel(ProcessModel.t(), ProcessModel.t()) :: ProcessModel.t()
  defp parallel(%ProcessModel{graph: graph_1}, %ProcessModel{graph: graph_2}) do
    start_edges =
      Graph.outgoing_edges(graph_1, @start_id)
      |> Enum.map(fn edge -> %Graph.Edge{edge | from: @start_id} end)

    end_edges =
      Graph.incomming_edges(graph_1, @end_id)
      |> Enum.map(fn edge -> %Graph.Edge{edge | to: @end_id} end)

    graph_1 = Graph.remove_node(graph_1, @end_id) |> Graph.remove_node(@start_id)

    edges = (start_edges ++ end_edges) |> Enum.uniq()

    {:ok, g} = merge_graphs(graph_1, graph_2)
    {:ok, g} = Graph.add_edges(g, edges)
    from_graph(g)
  end

  @spec from_graph(Graph.t()) :: ProcessModel.t()
  defp from_graph(%Graph{} = graph), do: %ProcessModel{graph: graph}

  @spec with_graph(ProcessModel.t(), Graph.t()) :: ProcessModel.t()
  defp with_graph(workflow_graph, graph), do: %ProcessModel{workflow_graph | graph: graph}

  @spec make_start_node() :: Graph.Node.t()
  defp make_start_node(), do: Graph.Node.make(@start_id, Start.make())

  @spec make_end_node() :: Graph.Node.t()
  defp make_end_node(), do: Graph.Node.make(@end_id, End.make())

  @spec merge_graphs(Graph.t(), Graph.t()) ::
          {:ok, Graph.t()} | {:error, atom()}
  defp merge_graphs(%Graph{} = graph_1, %Graph{} = graph_2) do
    nodes = Graph.nodes(graph_2)
    edges = Graph.edges(graph_2)

    with {:ok, g} <- Graph.add_nodes(graph_1, nodes) do
      Graph.add_edges(g, edges)
    end
  end

  defp constantly_true(), do: Conditions.ctrue()
end

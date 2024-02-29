defmodule ProcessEngineTalk.ProcessModel.Graph do
  @moduledoc """
  A directed graph structure for processes.
  This structure is quite generic and doesn't implement process
  related semantics.
  """
  use TypedStruct

  alias ProcessEngineTalk.ProcessModel.Conditions
  alias ProcessEngineTalk.ProcessModel.Graph.Edge
  alias ProcessEngineTalk.ProcessModel.Graph.Errors.EdgeAlreadyExistsError
  alias ProcessEngineTalk.ProcessModel.Graph.Errors.FromNodeDoesNotExistError
  alias ProcessEngineTalk.ProcessModel.Graph.Errors.NodeAlreadyExistsError
  alias ProcessEngineTalk.ProcessModel.Graph.Errors.ToNodeDoesNotExistError
  alias ProcessEngineTalk.ProcessModel.Graph.Node
  alias __MODULE__

  typedstruct do
    field(:nodes, %{Node.id_t() => Node.t()})
    # FIXME: this should be mapset
    field(:edges, list(Edge.t()))
  end

  @doc """
  Makes a graph
  """
  @spec make(list(Node.t()), list(Edge.t())) :: Graph.t()
  def make(nodes, edges) do
    %Graph{nodes: to_nodes_map(nodes), edges: edges}
  end

  @doc """
  Returns an empty graph
  """
  @spec empty() :: Graph.t()
  def empty(), do: Graph.make([], [])

  @doc """
  Returns all edges of the graph
  """
  @spec edges(Graph.t()) :: list(Edge.t())
  def edges(%Graph{edges: edges}), do: edges

  @doc """
  Returns all nodes of the graph
  """
  @spec nodes(Graph.t()) :: list(Node.t())
  def nodes(%Graph{nodes: nodes}), do: nodes |> Map.values()

  @doc """
  Adds a node to a graph.
  Returns ok and the graph or an error, when a node with the given ID already exists.
  """
  @spec add_node(Graph.t(), Node.t()) :: {:ok, Graph.t()} | {:error, :node_already_exists}
  def add_node(%Graph{nodes: nodes} = graph, %Node{id: id} = node) do
    if has_node?(graph, id) do
      {:error, :node_already_exists}
    else
      new_nodes = Map.put(nodes, id, node)
      {:ok, with_nodes(graph, new_nodes)}
    end
  end

  @doc """
  Adds a node to a graph.
  Returns a new graph. Raises if the node already exists.
  """
  @spec add_node!(Graph.t(), Node.t()) :: Graph.t()
  def add_node!(graph, node) do
    case add_node(graph, node) do
      {:error, :node_already_exists} -> raise NodeAlreadyExistsError
      {:ok, graph} -> graph
    end
  end

  @doc """
  Adds multiple nodes to a graph.
  Returns ok and the graph or an error, when a node with the given ID already exists.
  """
  @spec add_nodes(Graph.t(), list(Node.t())) :: {:ok, Graph.t()} | {:error, :node_already_exists}
  def add_nodes(%Graph{} = graph, nodes) do
    Enum.reduce(nodes, {:ok, graph}, fn
      node, {:ok, graph} -> add_node(graph, node)
      _, err -> err
    end)
  end

  @doc """
  Same as `add_nodes/2`, but raises instead of returning errors.
  """
  @spec add_nodes!(Graph.t(), list(Node.t())) :: Graph.t()
  def add_nodes!(%Graph{} = graph, nodes) do
    Enum.reduce(nodes, graph, fn node, graph -> add_node!(graph, node) end)
  end

  @doc """
  Returns true if the graph contains a node with the given id, else false.
  """
  @spec has_node?(Graph.t(), Node.id_t()) :: boolean()
  def has_node?(%Graph{nodes: nodes}, id), do: Map.has_key?(nodes, id)

  @doc """
  Returns true if the graph contains an edge between the given node, else false.
  """
  @spec has_edge?(Graph.t(), Node.id_t(), Node.id_t()) :: boolean()
  def has_edge?(%Graph{edges: edges}, from, to) do
    !!Enum.find(edges, fn %Edge{from: other_from, to: other_to} ->
      from == other_from && to == other_to
    end)
  end

  @type add_edge_error_t ::
          {:error, :from_node_does_not_exist | :to_node_does_not_exist | :edge_already_exists}

  @doc """
  Adds an edge to the graph. Returns `{:ok, new_graph}` if successful,
  returns errors in case of:

  - the from-node does not exist
  - the to-node does not exist
  - the edge already exists
  """
  @spec add_edge(Graph.t(), Edge.t()) :: {:ok, Graph.t()} | add_edge_error_t()
  def add_edge(%Graph{edges: edges} = graph, %Edge{from: from, to: to} = edge) do
    cond do
      !Graph.has_node?(graph, from) -> {:error, :from_node_does_not_exist}
      !Graph.has_node?(graph, to) -> {:error, :to_node_does_not_exist}
      has_edge?(graph, from, to) -> {:error, :edge_already_exists}
      true -> {:ok, with_edges(graph, [edge | edges] |> Enum.sort())}
    end
  end

  @doc """
  Same as `add_edge/2`, but raises instead of returning errors.
  """
  @spec add_edge!(Graph.t(), Edge.t()) :: Graph.t()
  def add_edge!(graph, edge) do
    case add_edge(graph, edge) do
      {:error, :from_node_does_not_exist} -> raise FromNodeDoesNotExistError
      {:error, :to_node_does_not_exist} -> raise ToNodeDoesNotExistError
      {:error, :edge_already_exists} -> raise EdgeAlreadyExistsError
      {:ok, graph} -> graph
    end
  end

  @doc """
  Adds multiple edges to the graph. Returns `{:ok, new_graph}` if successful,
  returns errors in case of:

  - the from-node does not exist
  - the to-node does not exist
  - the edge already exists
  """
  @spec add_edges(Graph.t(), list(Edge.t())) ::
          {:ok, Graph.t()} | add_edge_error_t()
  def add_edges(%Graph{} = graph, edges) do
    Enum.reduce(edges, {:ok, graph}, fn
      edge, {:ok, graph} -> Graph.add_edge(graph, edge)
      _, err -> err
    end)
  end

  @doc """
  Same as `add_edges/2`, but raises instead of returning errors.
  """
  @spec add_edges!(Graph.t(), list(Edge.t())) :: Graph.t()
  def add_edges!(%Graph{} = graph, edges) do
    Enum.reduce(edges, graph, fn edge, graph -> Graph.add_edge!(graph, edge) end)
  end

  @doc """
  Returns the node with the given id if exists, else nil
  """
  @spec get_node(Graph.t(), Node.id_t()) :: Node.t() | nil
  def get_node(%Graph{nodes: nodes}, id),
    do: Map.get(nodes, id)

  @doc """
  Returns the edge between the given nodes if exsits, else nil
  """
  @spec get_edge(Graph.t(), Node.id_t(), Node.id_t()) :: Edge.t() | nil
  def get_edge(%Graph{edges: edges}, from, to) do
    Enum.find(edges, fn edge -> edge.from == from && edge.to == to end)
  end

  @doc """
  Maps the conditions in each edge using the given function.
  """
  @spec map_edges(Graph.t(), (Conditions.t() -> Conditions.t())) :: Graph.t()
  def map_edges(%Graph{edges: edges} = graph, foo) do
    new_edges = Enum.map(edges, fn edge -> Edge.map(edge, foo) end)
    with_edges(graph, new_edges)
  end

  @doc """
  Maps the data in each node using the given function.
  """
  @spec map_nodes(Graph.t(), (any() -> any())) :: Graph.t()
  def map_nodes(%Graph{nodes: nodes} = graph, foo) do
    nodes = Map.values(nodes)
    new_nodes = Enum.map(nodes, fn node -> Node.map(node, foo) end) |> to_nodes_map()
    with_nodes(graph, new_nodes)
  end

  @doc """
  Returns a filtered list of nodes using the passed predicate.
  """
  @spec filter_nodes(Graph.t(), (Node.t() -> boolean())) :: list(Node.t())
  def filter_nodes(%Graph{nodes: nodes}, foo), do: nodes |> Map.values() |> Enum.filter(foo)

  @doc """
  Returns a filtered list of edges using the passed predicate.
  """
  @spec filter_edges(Graph.t(), (Edge.t() -> boolean())) :: list(Edge.t())
  def filter_edges(%Graph{edges: edges}, foo), do: Enum.filter(edges, foo)

  @doc """
  Returns a list of direct successors for a given node.
  Returns empty list if there are none or the node doesn't exist.
  """
  @spec successors(Graph.t(), Node.id_t()) :: list(Node.t())
  def successors(%Graph{} = graph, node) do
    outgoing_edges(graph, node)
    |> Enum.map(fn edge -> edge.to end)
    |> Enum.map(fn node -> Graph.get_node(graph, node) end)
  end

  @doc """
  Returns a list of direct predecessors for a given node.
  Returns empty list if there are none or the node doesn't exist.
  """
  @spec predecessors(Graph.t(), Node.id_t()) :: list(Node.t())
  def predecessors(%Graph{} = graph, node) do
    incomming_edges(graph, node)
    |> Enum.map(fn edge -> edge.from end)
    |> Enum.map(fn node -> Graph.get_node(graph, node) end)
  end

  @doc """
  Returns a list of outgoing edges for a given node.
  Returns empty list if there are none or the node doesn't exist.
  """
  @spec outgoing_edges(Graph.t(), Node.id_t()) :: list(Edge.t())
  def outgoing_edges(%Graph{} = graph, node),
    do: filter_edges(graph, fn edge -> edge.from == node end)

  @doc """
  Returns a list of incomming edges for a given node.
  Returns empty list if there are none or the node doesn't exist.
  """
  @spec incomming_edges(Graph.t(), Node.id_t()) :: list(Edge.t())
  def incomming_edges(%Graph{} = graph, node),
    do: filter_edges(graph, fn edge -> edge.to == node end)

  @doc """
  Removes a node from the graph. It also removes all affected edges.
  Does nothing if the node does not exist.
  """
  @spec remove_node(Graph.t(), Node.id_t()) :: Graph.t()
  def remove_node(%Graph{nodes: nodes, edges: edges} = graph, node) do
    node_edges = outgoing_edges(graph, node) ++ incomming_edges(graph, node)
    new_nodes = Map.delete(nodes, node)
    new_edges = Enum.reject(edges, fn edge -> edge in node_edges end)
    graph |> with_edges(new_edges) |> with_nodes(new_nodes)
  end

  @doc """
  Removes an edge from the graph. It also removes all affected edges.
  Does nothing if the node does not exist.
  """
  @spec remove_edge(Graph.t(), Node.id_t(), Node.id_t()) :: Graph.t()
  def remove_edge(%Graph{edges: edges} = graph, from, to) do
    new_edges = Enum.reject(edges, fn edge -> edge.to == to && edge.from == from end)
    with_edges(graph, new_edges)
  end

  @doc """
  Removes multiple edges from the graph. It also removes all affected edges.
  Does nothing for an edge if a node does not exist.
  """
  @spec remove_edges(Graph.t(), list({Node.id_t(), Node.id_t()})) :: Graph.t()
  def remove_edges(%Graph{} = graph, edges) do
    Enum.reduce(edges, graph, fn {from, to}, graph ->
      remove_edge(graph, from, to)
    end)
  end

  @doc """
  Find all paths between two given nodes. Returns an error if nodes to not exist.

  Caution: Can have exponential complexity if there are loop involved.
  For loops there a simple upper bound for termination. That said, loops
  can be present multiple times in paths.
  """
  @spec paths(Graph.t(), Node.id_t(), Node.id_t()) ::
          {:ok, list(list(Node.t()))} | {:error, :node_does_not_exist}
  def paths(%Graph{} = graph, from, to) do
    from_node = get_node(graph, from)
    to_node = get_node(graph, to)

    if from_node && to_node do
      {:ok, paths_helper(graph, from_node, to_node, [[from_node]])}
    else
      {:error, :node_does_not_exist}
    end
  end

  @spec paths_helper(Graph.t(), Node.t(), Node.t(), list(list(Node.t()))) :: list(list(Node.t()))
  defp paths_helper(%Graph{} = graph, current_node, to_node, paths) do
    if current_node == to_node do
      paths
    else
      successors(graph, current_node.id)
      |> Enum.map(fn successor ->
        new_paths =
          Enum.map(paths, fn path -> path ++ [successor] end)
          # We are using a simple upper bound to handle loops:
          # If there are more than 3n vertices in a path we terminate recursion.
          # https://stackoverflow.com/questions/41288503/identifying-paths-between-nodes-on-a-graph-whilst-finding-potential-loops
          |> Enum.reject(fn path -> (nodes(graph) |> Enum.count()) * 3 < Enum.count(path) end)

        unless Enum.empty?(new_paths) do
          paths_helper(graph, successor, to_node, new_paths)
        end
      end)
      # we need to "flatten once" 
      |> Enum.filter(fn x -> x end)
      |> Enum.reduce([], fn paths, acc ->
        Enum.reduce(paths, acc, fn path, inner_acc -> [path | inner_acc] end)
      end)
    end
  end

  @spec with_edges(Graph.t(), list(Edge.t())) :: Graph.t()
  defp with_edges(%Graph{} = graph, edges),
    do: %Graph{graph | edges: edges}

  @spec with_nodes(Graph.t(), %{Node.id_t() => Node.t()}) :: Graph.t()
  defp with_nodes(%Graph{} = graph, nodes),
    do: %Graph{graph | nodes: nodes}

  @spec to_nodes_map(list(Node.t())) :: %{Node.id_t() => Node.t()}
  defp to_nodes_map(nodes),
    do: Enum.map(nodes, fn node -> {node.id, node} end) |> Map.new()
end

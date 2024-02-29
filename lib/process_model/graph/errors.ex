defmodule ProcessEngineTalk.ProcessModel.Graph.Errors do
  @moduledoc """
  Contains errors for graph operations
  """

  defmodule NodeAlreadyExistsError do
    defexception message: "Node already exists"
  end

  defmodule FromNodeDoesNotExistError do
    defexception message: "From-node in edge does not exist"
  end

  defmodule ToNodeDoesNotExistError do
    defexception message: "To-node in edge does not exist"
  end

  defmodule EdgeAlreadyExistsError do
    defexception message: "Edge already exists"
  end
end

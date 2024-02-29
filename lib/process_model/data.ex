defmodule ProcessEngineTalk.ProcessModel.Data do
  @moduledoc """
  This modules contains data definitions of process parts.
  """

  defmodule Start do
    @moduledoc """
    A start node meant to be stored in node data.
    """

    alias __MODULE__

    use TypedStruct

    typedstruct do
    end

    @spec make() :: Start.t()
    def make(), do: %Start{}
  end

  defmodule End do
    @moduledoc """
    An end node meant to be stored in node data.
    """

    alias __MODULE__

    use TypedStruct

    typedstruct do
    end

    @spec make() :: End.t()
    def make(), do: %End{}
  end

  defmodule And do
    @moduledoc """
    Data definition of an and-node.

    It consists of the following:

    - An id
    - An id of the corresponding join node
    """
    alias __MODULE__

    use TypedStruct

    typedstruct do
      field(:id, any())
      field(:join_node_id, any())
    end

    @spec make(any(), any()) :: And.t()
    def make(id, join_node_id), do: %And{id: id, join_node_id: join_node_id}
  end

  defmodule Or do
    @moduledoc """
    Data definition of an or-node.

    It consists of the following:

    - An id
    - An id of the corresponding join node
    """
    alias __MODULE__

    use TypedStruct

    typedstruct do
      field(:id, any())
      field(:join_node_id, any())
    end

    @spec make(any(), any()) :: Or.t()
    def make(id, join_node_id), do: %Or{id: id, join_node_id: join_node_id}
  end

  defmodule Join do
    @moduledoc """
    Data definition of a join-node.

    It consists of the following:

    - An id
    - An id of the corresponding and- or or-node
    """

    alias __MODULE__

    use TypedStruct

    typedstruct do
      field(:id, any())
      field(:for_node_id, any())
    end

    @spec make(any(), any()) :: Join.t()
    def make(id, for_node_id), do: %Join{id: id, for_node_id: for_node_id}
  end
end

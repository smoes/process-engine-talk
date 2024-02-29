defmodule ProcessEngineTalk.Events do
  defmodule EventA do
    use TypedStruct

    typedstruct do
      field(:a, any())
      field(:bike_id, String.t())
      field(:bike_id_short, String.t())
    end
  end

  defmodule EventB do
    use TypedStruct

    typedstruct do
      field(:b, any())
      field(:bike_id, String.t())
      field(:bike_id_short, String.t())
    end
  end

  defmodule EventC do
    use TypedStruct

    typedstruct do
      field(:c, any())
      field(:bike_id, String.t())
      field(:bike_id_short, String.t())
    end
  end

  defmodule EventD do
    use TypedStruct

    typedstruct do
      field(:c, any())
      field(:spare_part_id, String.t())
    end
  end

  defmodule Noop do
    use TypedStruct

    typedstruct do
    end
  end
end

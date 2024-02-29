defmodule ProcessEngineTalk.ProcessModel.Activity do
  @moduledoc """
  An activity is a workflow step that starts an internal process. 

  An activity consists of the following:

  - an id
  - a version
  - a list of events that are expected to already happened when the activity is started
  - a list of events that the activity writes which are of interest for the workflow
  - the module with the implemented DB.ProcessManagement.Activities.ActivityBehavior
  """
  alias __MODULE__

  use TypedStruct

  typedstruct enforce: true do
    field(:id, any())
    field(:version, atom() | String.t())
    field(:required_events, list(module()))
    field(:output_events, list(module()))
    field(:module, DB.ProcessManagement.Activities.ActivityBehaviour.t())
  end

  @spec make(
          any(),
          atom() | String.t(),
          list(module()),
          list(module()),
          module()
        ) :: Activity.t()
  def make(id, version, required_events, output_events, module),
    do: %Activity{
      id: id,
      version: version,
      required_events: required_events,
      output_events: output_events,
      module: module
    }
end

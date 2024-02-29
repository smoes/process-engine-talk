defmodule ProcessEngineTalk.ProcessInstance do
  @moduledoc """
  This module contains a process' instance and related functionality.

  A process instance consists of the following:
  - a id of the process
  - a process model that doesn't change
  - a list of current steps that determine the currently active nodes in the
    process as well as a list of conditions to be fullfilled to transition
    to the next node.
  - a list of events that have been passed to the process.
  """

  alias ProcessEngineTalk.ProcessInstance.ProcessStep
  alias ProcessEngineTalk.ProcessInstance.Stepping
  alias ProcessEngineTalk.ProcessModel
  alias ProcessEngineTalk.ProcessModel.Activity
  alias ProcessEngineTalk.ProcessModel.Data.End

  use TypedStruct

  alias __MODULE__

  @type events_t() :: list(struct())

  typedstruct do
    field(:id, binary())
    field(:process_model, ProcessModel.t())
    field(:current_steps, list(ProcessStep.t()))
    field(:events, events_t())
  end

  @doc """
  Creates an instance from a process model.
  """
  @spec make(ProcessModel.t()) :: ProcessInstance.t()
  def make(process_model), do: make_with_id(process_model, Ecto.UUID.generate())

  @doc """
  Creates an instance from a process model and an id
  """
  @spec make_with_id(ProcessModel.t(), binary()) :: ProcessInstance.t()
  def make_with_id(process_model, id) do
    %ProcessInstance{
      id: id,
      process_model: process_model,
      current_steps: ProcessStep.make(process_model, ProcessModel.start_node_id()),
      events: []
    }
    |> Stepping.step()
  end

  @doc """
  Returns true if the process instance is done. That is, it reached an end-node.
  It returns false if not done or in an exit-node.
  """
  @spec done?(ProcessInstance.t()) :: boolean()
  def done?(%ProcessInstance{} = state) do
    case currently_active(state) do
      [%End{}] -> true
      _ -> false
    end
  end

  @doc """
  Steps a given instance using the passed event.
  The process instance is stepped until no further transition can be taken.
  """
  @spec step(ProcessInstance.t(), struct()) :: ProcessInstance.t()
  def step(%ProcessInstance{} = state, event),
    do: append_event(state, event) |> Stepping.step()

  @doc """
  Returns the current process instance's steps.
  """
  @spec current_steps(ProcessInstance.t()) :: list(ProcessStep.t())
  def current_steps(%ProcessInstance{current_steps: steps}), do: steps

  @doc """
  Returns the currently active node data, e.g. activities, ...
  """
  @spec currently_active(ProcessInstance.t()) :: list(ProcessModel.data_t())
  def currently_active(%ProcessInstance{current_steps: steps}) do
    Enum.map(steps, fn step -> step.node_data end) |> List.flatten()
  end

  @doc """
  Returns the activities the process has current steps for. 
  """
  @spec currently_active_activities(ProcessInstance.t()) :: list(Activity.t())
  def currently_active_activities(%ProcessInstance{current_steps: current_steps}) do
    current_steps |> Enum.map(fn
      %ProcessStep{node_data: %Activity{} = a} -> a
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end


  @spec append_event(ProcessInstance.t(), struct()) :: ProcessInstance.t()
  defp append_event(%ProcessInstance{events: events} = state,  event) do
    events = events ++ [event]
    %ProcessInstance{state | events: events}
  end
end

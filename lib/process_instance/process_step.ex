defmodule ProcessEngineTalk.ProcessInstance.ProcessStep do
  @moduledoc """
  This module contains data logic related to step a single step of
  an instance state.

  A process step consists of the following

  - a original condition
  - a rest of the original conditions that is left to be evaluated
  - a target node id
  - a current node id 
  - the current nodes data
  """
  alias ProcessEngineTalk.ProcessModel
  alias ProcessEngineTalk.ProcessModel.Graph.Node
  use TypedStruct

  alias __MODULE__

  alias ProcessEngineTalk.ProcessModel.Conditions

  typedstruct do
    field(:condition, Conditions.t())
    field(:rest_condition, Conditions.t())
    field(:target, any())
    field(:node_id, any())
    field(:node_data, any())
  end

  @spec make(ProcessModel.t(), any()) :: [ProcessStep.t()]
  def make(process_model, node_id) do
    data = ProcessModel.data(process_model, node_id)

    case data do
      %ProcessModel.Data.End{} ->
        %ProcessStep{
          condition: Conditions.cfalse(),
          rest_condition: Conditions.cfalse(),
          target: nil,
          node_id: node_id,
          node_data: data
        }
        |> List.wrap()

      _ ->
        ProcessModel.conditions_with_targets(process_model, node_id)
        |> Enum.map(fn {condition, target} ->
          %ProcessStep{
            condition: condition,
            rest_condition: condition,
            target: target,
            node_id: node_id,
            node_data: data
          }
        end)
    end
  end

  @type event_t :: struct()
  @type step_return_t :: {:transition, Node.id_t()} | {:no_transition, ProcessStep.t()}

  @doc """
  Steps a process step for a given list of events.
  Returns

  - `{:no_transition, new_process_step}` with a new process step containing only
     the rest condition
  - `{:transition, target}` with the target node's id
  """
  def step(%ProcessStep{rest_condition: rest_condition} = wfs, events) do
    event = List.last(events)
    case rest_condition |> Conditions.eval(event) do
      {:rest, rest} -> {:no_transition, with_rest_condition(wfs, rest)}
      :done -> {:transition, wfs.target}
    end
  end

  @spec with_rest_condition(ProcessStep.t(), Conditions.t()) :: ProcessStep.t()
  defp with_rest_condition(%ProcessStep{} = wfs, rest_condition),
    do: %ProcessStep{wfs | rest_condition: rest_condition}
end

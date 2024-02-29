defmodule ProcessEngineTalk.ProcessInstance.Stepping do
  @moduledoc """
  This module contains logic related to the stepping algorithm.

  The stepping algorithm takes an instance state that contains the
  process model and the latest event. It assumes that the last event is new
  and uses it as the input.

  The algorithm then checks all process steps (which represent the
  state of all currently possible transitions) for possible transitions.

  If a transition was found, it determines the new process steps and
  restarts the process. As long as the steps change, the algorithm will
  go on. If the result stabilizes, the algorithm terminates.
  """

  alias ProcessEngineTalk.ProcessInstance
  alias ProcessEngineTalk.ProcessInstance.ProcessStep
  alias ProcessEngineTalk.ProcessModel
  alias ProcessEngineTalk.ProcessModel.Data.And
  alias ProcessEngineTalk.ProcessModel.Data.Join
  alias ProcessEngineTalk.ProcessModel.Data.Or

  @type step_return_t() :: ProcessStep.step_return_t()
  @type event_t() :: struct()
  @type events_t() :: list(event_t())
  @type process_steps_t() :: list(ProcessStep.t())

  @spec step(ProcessInstance.t()) :: ProcessInstance.t()
  def step(%ProcessInstance{current_steps: previous_steps, events: events} = state) do
    new_state =
      Enum.reduce(previous_steps, clear_steps(state), fn %ProcessStep{node_data: data} = step, acc_state ->
          case data do
            %Or{} -> step_or(step, acc_state.current_steps, previous_steps, events)
            %Join{} -> step_join(step, state.process_model, previous_steps, events)
            _ -> ProcessStep.step(step, events)
          end
          |> case do
            {:no_transition, rest} ->
              push_step(acc_state, rest)

            {:transition, next_node} ->
              new_steps = ProcessStep.make(acc_state.process_model, next_node)
              push_steps(acc_state, new_steps)

            :drop ->
              acc_state
          end
        end
      )

    if new_state == state do
      new_state
    else
      step(new_state)
    end
  end

  @spec step_or(ProcessStep.t(), process_steps_t(), process_steps_t(), list(event_t())) ::
          :drop | step_return_t()
  defp step_or(step, current_steps, all_steps, events) do
    if or_decided?(step, current_steps, all_steps) do
      :drop
    else
      ProcessStep.step(step, events)
    end
  end

  @spec step_join(ProcessStep.t(), ProcessModel.t(), process_steps_t(), list(event_t())) ::
          step_return_t()
  defp step_join(step, process_model, previous_steps, events) do
    data = step.node_data

    if join_for_and?(process_model, data) && !and_done?(process_model, previous_steps, data) do
      {:no_transition, step}
    else
      ProcessStep.step(step, events)
    end
  end

  @doc !"""
       Checks if the or related to a given process-step is already decided.
       This is if it is the only one left in the all-steps-list or if
       it is the second step for the corresponding or in the all-steps-list and the
       only step for the or left in the current list.
       """
  @spec or_decided?(ProcessStep.t(), list(ProcessStep.t()), list(ProcessStep.t())) ::
          boolean()
  defp or_decided?(current_step, current_steps, all_steps) do
    only_left_or?(current_step, all_steps) ||
      (second_or?(current_step, all_steps) &&
         only_left_or?(current_step, current_steps))
  end

  @spec only_left_or?(ProcessStep.t(), list(ProcessStep.t())) :: boolean()
  defp only_left_or?(current_step, other_steps) do
    Enum.filter(other_steps, fn step ->
      step.node_id == current_step.node_id && step != current_step
    end)
    |> Enum.empty?()
  end

  @spec second_or?(ProcessStep.t(), list(ProcessStep.t())) :: boolean()
  defp second_or?(current_step, steps) do
    [_, second] =
      Enum.filter(steps, fn step ->
        step.node_id == current_step.node_id
      end)

    second == current_step
  end

  @spec join_for_and?(ProcessModel.t(), any()) :: boolean()
  defp join_for_and?(process_model, %Join{for_node_id: node_id}) do
    case ProcessModel.data(process_model, node_id) do
      %And{} -> true
      _ -> false
    end
  end

  @spec and_done?(ProcessModel.t(), list(ProcessStep.t()), Join.t()) :: boolean()
  defp and_done?(process_model, steps, join) do
    steps_ids = Enum.map(steps, fn step -> step.node_id end)
    {:ok, paths} = ProcessModel.paths(process_model, join.for_node_id, join.id)
    # the idea is, to find all nodes on the paths between and and join
    # and check if any of the nodes is present in the list of steps.
    # If so, we are not finished with the end.
    paths
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.map(fn node -> node.id end)
    |> Enum.reject(fn id -> id == join.id end)
    |> Enum.filter(fn id -> id in steps_ids end)
    |> Enum.empty?()
  end

  @spec push_step(ProcessInstance.t(), ProcessStep.t()) :: ProcessInstance.t()
  defp push_step(%ProcessInstance{current_steps: steps} = wf, step) do
    with_steps(wf, [step | steps])
  end

  @spec push_steps(ProcessInstance.t(), list(ProcessStep.t())) :: ProcessInstance.t()
  defp push_steps(%ProcessInstance{} = state, steps),
    do: Enum.reduce(steps, state, fn step, state -> push_step(state, step) end)

  @spec clear_steps(ProcessInstance.t()) :: ProcessInstance.t()
  defp clear_steps(%ProcessInstance{} = state), do: with_steps(state, [])

  @spec with_steps(ProcessInstance.t(), list(ProcessStep.t())) :: ProcessInstance.t()
  defp with_steps(%ProcessInstance{} = state, steps),
    do: %ProcessInstance{state | current_steps: steps |> Enum.uniq() |> Enum.sort()}
end

defmodule ProcessEngineTalk.ProcessInstanceTest do
  use ExUnit.Case


  alias ProcessEngineTalk.Events.EventA
  alias ProcessEngineTalk.Events.EventB
  alias ProcessEngineTalk.Events.EventC
  alias ProcessEngineTalk.ProcessInstance
  alias ProcessEngineTalk.ProcessModel
  alias ProcessEngineTalk.ProcessModel.Activity
  alias ProcessEngineTalk.ProcessModel.Conditions
  alias ProcessEngineTalk.ProcessModel.Data.And
  alias ProcessEngineTalk.ProcessModel.Data.Or


  def example_activity(id, output_events \\ []),
    do: Activity.make(id, :v2,  B, [], output_events)

  def example_p(id, output_events \\ []),
    do: id |> example_activity(output_events) |> ProcessModel.make()

  def condition_a(), do: Conditions.is_type(EventA)
  def condition_b(), do: Conditions.is_type(EventB)
  def condition_c(), do: Conditions.is_type(EventC)

  def empty_event_a(), do: %EventA{}
  def empty_event_b(), do: %EventB{}
  def empty_event_c(), do: %EventC{}


  def step(state, data) do
    state |> ProcessInstance.step(data)
  end

  def assert_activity_active(state, %Activity{} = a),
    do: assert(Enum.member?(ProcessInstance.currently_active_activities(state), a))

  def assert_activity_active(state, id) do
    assert(
      !!Enum.find(ProcessInstance.currently_active_activities(state), fn %Activity{id: a_id} -> a_id == id end)
    )

    state
  end

  def refute_activity_active(state, id),
    do:
      assert(
        !Enum.find(ProcessInstance.currently_active_activities(state), fn %Activity{id: a_id} -> a_id == id end)
      )

  def make(process_model) do
    process_model
    |> ProcessInstance.make()
  end

  describe "step/2" do
    test "steps a simple process model until the end" do
      p_1 = example_p("1", [EventA]) |> make() |> step(%EventA{a: 3})
      assert ProcessInstance.done?(p_1)
    end

    test "steps a simple process model with conditions until the end" do
      p_1 = example_p("1", [EventA]) |> ProcessModel.with_end_condition(condition_a())
      p_2 = example_p("2", [EventB]) |> ProcessModel.with_end_condition(condition_b())

      p = ProcessModel.append(p_1, p_2)

      state = p |> make() |> step(empty_event_b())
      assert_activity_active(state, "1")

      state = step(state, empty_event_a())
      assert_activity_active(state, "2")

      state = step(state, empty_event_b())

      assert ProcessInstance.done?(state)
    end

    test "steps a condition and an activity at once" do
      state =
        example_p("1", [EventA])
        |> ProcessModel.with_end_condition(condition_a())
        |> make()
        |> assert_activity_active("1")
        |> step(empty_event_a())

      assert ProcessInstance.done?(state)
    end

    test "steps a simple process model with and_then-condition until the end" do
      p_1 = example_p("1", [EventA]) |> ProcessModel.with_end_condition(condition_a())
      p_2 = example_p("2", [EventB]) |> ProcessModel.with_start_condition(condition_b())

      p = ProcessModel.append(p_1, p_2)

      # step nothing
      state = make(p) |> step(empty_event_b())
      assert_activity_active(state, "1")

      # steps
      state = step(state, empty_event_a())

      # steps
      state = step(state, empty_event_b())
      assert ProcessInstance.done?(state)
    end

    test "steps an one-of-connected process model properly" do
      p_1 = example_p("1", [EventB]) |> ProcessModel.with_start_condition(condition_a())
      p_2 = example_p("2", [EventB])
      p_1_2 = p_1 |> ProcessModel.append(p_2)

      p_3 = example_p("3", [EventA]) |> ProcessModel.with_start_condition(condition_b())
      p_4 = example_p("4", [EventA])
      p_3_4 = p_3 |> ProcessModel.append(p_4)

      p = ProcessModel.one_of(p_1_2, p_3_4)

      state = make(p) |> step(empty_event_c())

      [step_1, step_2] = ProcessInstance.current_steps(state)

      assert %Or{} = step_1.node_data
      assert %Or{} = step_2.node_data

      state = step(state, empty_event_a())
      assert ProcessInstance.done?(state)
    end

    test "steps a both-connected process model properly" do
      p_1 = example_p("1", [EventB]) |> ProcessModel.with_start_condition(condition_a())
      p_2 = example_p("2", [EventB])
      p_1_2 = p_1 |> ProcessModel.append(p_2)

      p_3 = example_p("3", [EventA]) |> ProcessModel.with_start_condition(condition_b())
      p_4 = example_p("4", [EventA])
      p_3_4 = p_3 |> ProcessModel.append(p_4)

      p = ProcessModel.both(p_1_2, p_3_4)

      state = make(p) |> step(empty_event_c())

      [step_1, step_2] = ProcessInstance.currently_active(state)

      assert %And{} = step_1
      assert %And{} = step_2

      state = state |> step(empty_event_a())

      assert [_, _] = ProcessInstance.currently_active(state)

      state = step(state, empty_event_b())

      assert ProcessInstance.done?(state)
    end

    test "steps a both-of process model within a one-of process model properly" do
      p_1 = example_p("1", [EventB])
      p_2 = example_p("2", [EventB])
      p_3 = example_p("3", [EventC]) |> ProcessModel.with_start_condition(condition_c())

      both_1 =
        ProcessModel.both(p_1, p_2) |> ProcessModel.with_start_condition(condition_a())

      p = ProcessModel.one_of(both_1, p_3)

      state = make(p)

      assert ProcessInstance.current_steps(state) |> Enum.count() == 2
      refute ProcessInstance.done?(state)

      state = step(state, empty_event_a())
      assert ProcessInstance.done?(state)
    end

    test "steps a one-of process model within a both-of process model properly" do
      p_1 =
        example_p("1", [EventA, EventB, EventC])
        |> ProcessModel.with_start_condition(condition_a())

      p_2 =
        example_p("2", [EventA, EventB, EventC])
        |> ProcessModel.with_start_condition(condition_b())

      p_3 = example_p("3", [EventC])

      one_of = ProcessModel.one_of(p_1, p_2)
      state = ProcessModel.both(one_of, p_3) |> make()

      # we have a step waiting at 3 and two steps for the one_of
      assert ProcessInstance.current_steps(state) |> Enum.count() == 3

      state = step(state, empty_event_a())
      assert ProcessInstance.done?(state)
    end

    test "steps a one-of process model within a one-of process model properly" do
      p_1 =
        example_p("1", [EventA, EventB, EventC])
        |> ProcessModel.with_start_condition(condition_a())

      p_2 =
        example_p("2", [EventA, EventB, EventC])
        |> ProcessModel.with_start_condition(condition_b())

      p_3 =
        example_p("3", [EventA, EventB, EventC])
        |> ProcessModel.with_start_condition(condition_c())

      state =
        ProcessModel.one_of(p_1, p_2)
        |> ProcessModel.with_start_condition(condition_a())
        |> ProcessModel.one_of(p_3)
        |> make()

      # we have two steps waiting at the first both of
      assert ProcessInstance.current_steps(state) |> Enum.count() == 2
      state = step(state, empty_event_a()) |> step(empty_event_a())
      assert ProcessInstance.done?(state)
    end

    test "steps a loop process model" do
      p =
        example_p("1", [EventA])
        |> ProcessModel.with_start_condition(condition_a())
        |> ProcessModel.loop(condition_b())
        |> ProcessModel.with_end_condition(condition_c())

      state = make(p)

      state = step(state, empty_event_a()) |> step(empty_event_b())
      refute ProcessInstance.done?(state)

      state = step(state, empty_event_a()) |> step(empty_event_c())
      assert ProcessInstance.done?(state)
    end

  end

  describe "done?/1" do
    test "returns true if a process instance is done" do
      assert ProcessModel.neutral()
             |> make()
             |> ProcessInstance.done?()
    end

    test "returns false if a process instance isn't done" do
      refute ProcessModel.neutral()
             |> ProcessModel.with_end_condition(condition_a())
             |> make()
             |> ProcessInstance.done?()
    end
  end
  
end

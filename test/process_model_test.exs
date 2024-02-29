defmodule ProcessEngineTalk.ProcessModelTest do
  use ExUnit.Case

  alias ProcessEngineTalk.ProcessModel
  alias ProcessEngineTalk.ProcessModel.Activity
  alias ProcessEngineTalk.ProcessModel.Conditions

  def example_activity(id \\ "123"), do: Activity.make(id, :v2, B, [], [])

  def example_p(id \\ "123"),
    do: id |> example_activity() |> ProcessModel.make()


  describe "make/2" do
    test "creates process models as expected" do
      activity = Activity.make("123", :v2, B, [], [])
      p = ProcessModel.make(activity)
      reread_activity = ProcessModel.data(p, "123")
      assert reread_activity == activity
    end
  end

  describe "with_end_condition/2" do
    test "puts end-conditions as expected" do
      p = example_p() |> ProcessModel.with_end_condition(Conditions.cfalse())
      [{condition, _target}] = ProcessModel.conditions_with_targets(p, "123")
      assert ^condition = Conditions.cfalse()
    end
  end

  describe "with_start_condition/2" do
    test "puts start-conditions as expected" do
      p = example_p() |> ProcessModel.with_start_condition(Conditions.cfalse())

      [{condition, _target}] =
        ProcessModel.conditions_with_targets(p, ProcessModel.start_node_id())

      assert ^condition = Conditions.cfalse()
    end
  end

  describe "one_of/2" do
    test "combines two process models without failing" do
      p_1 = example_p("1")
      p_2 = example_p("2")
      assert ProcessModel.one_of(p_1, p_2)
    end

    test "fails if two process models contain the same activity ids" do
      p_1 = example_p("1")
      p_2 = example_p("1")
      assert_raise MatchError, fn -> ProcessModel.one_of(p_1, p_2) end
    end
  end

  describe "both/2" do
    test "combines two process models without failing" do
      p_1 = example_p("1")
      p_2 = example_p("2")
      assert ProcessModel.both(p_1, p_2)
    end

    test "fails if two process models contain the same activity ids" do
      p_1 = example_p("1")
      p_2 = example_p("1")
      assert_raise MatchError, fn -> ProcessModel.both(p_1, p_2) end
    end
  end

  describe "append/2" do
    test "combines two process models without failing" do
      p_1 = example_p("1")
      p_2 = example_p("2")
      assert ProcessModel.append(p_1, p_2)
    end

    test "fails if two process models contain the same activity ids" do
      p_1 = example_p("1")
      p_2 = example_p("1")
      assert_raise MatchError, fn -> ProcessModel.append(p_1, p_2) end
    end

    test "appends two neutral process models properly" do
      p_empty = ProcessModel.neutral()
      p = ProcessModel.append(p_empty, p_empty)
      assert p == p_empty
    end

    test "appending with neutral does nothing" do
      p_1 = example_p("1")
      p_empty = ProcessModel.neutral()
      assert p_1 == ProcessModel.append(p_1, p_empty)
      assert p_1 == ProcessModel.append(p_empty, p_1)
    end

    test "is associative" do
      p_1 = example_p("1")
      p_2 = example_p("2")
      p_3 = example_p("3")

      assert ProcessModel.append(p_1, ProcessModel.append(p_2, p_3)) ==
               ProcessModel.append(ProcessModel.append(p_1, p_2), p_3)
    end
  end
end

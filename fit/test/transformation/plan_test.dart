import 'package:fit/core/dev/demo_transformation.dart';
import 'package:fit/features/transformation/data/plan_codec.dart';
import 'package:fit/features/transformation/domain/entities/transformation_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2026-10-05 is a Monday.
  final monday = DateTime(2026, 10, 5);
  final plan = DemoTransformation.plan(monday);

  test('day numbers, range and weekly calorie step', () {
    expect(plan.totalDays, 84);
    expect(plan.dayNumber(monday), 1);
    expect(plan.contains(monday.subtract(const Duration(days: 1))), isFalse);
    expect(plan.contains(plan.end), isTrue);
    expect(plan.isFinished(plan.end.add(const Duration(days: 1))), isTrue);
    expect(plan.kcalOn(monday), 2050);
    final ramp = plan.copyWith(weeklyKcalStep: 50);
    expect(ramp.kcalOn(monday.add(const Duration(days: 6))), 2050);
    expect(ramp.kcalOn(monday.add(const Duration(days: 7))), 2100);
    expect(ramp.kcalOn(monday.add(const Duration(days: 20))), 2150);
  });

  test('checklist follows weekdays, includes sleep, skin only when selected', () {
    final mon = plan.itemsFor(monday).map((i) => i.id).toList();
    expect(mon.first, 'sleep');
    expect(mon, containsAll(['w_push', 'h_hair', 'skin_morning', 'm_breakfast']));
    expect(mon, isNot(contains('w_pull')));
    final sunday = monday.add(const Duration(days: 6));
    expect(plan.isRestDay(sunday), isTrue);
    expect(plan.itemsFor(sunday).map((i) => i.id), isNot(contains('h_hair')));
    // Ordered by time.
    final times = plan.itemsFor(monday).skip(1).map((i) => i.sortTime).toList();
    expect(times, orderedEquals([...times]..sort()));

    final bodyOnly = plan.copyWith(areas: {GoalArea.body});
    expect(bodyOnly.itemsFor(monday).any((i) => i.kind == PlanItemKind.skincare), isFalse);
    expect(plan.plannedIntake(monday).kcal, 620 + 640 + 300 + 490);
  });

  test('planned weight is a straight line from start to goal', () {
    expect(plan.plannedWeightOn(monday), 74);
    expect(plan.plannedWeightOn(plan.end), closeTo(69, 1e-9));
    expect(
      plan.plannedWeightOn(monday.add(Duration(days: (plan.totalDays - 1) ~/ 2 + 0))),
      closeTo(71.5, 0.05),
    );
  });

  test('validation per body goal', () {
    expect(plan.validate(), isEmpty);
    final fatLoss = TransformationPlan(
      id: 'x',
      name: 'Cut',
      start: monday,
      end: monday.add(const Duration(days: 30)),
      areas: const {GoalArea.body},
      bodyGoal: BodyGoal.fatLoss,
      startWeightKg: 90,
      goalWeightKg: 80,
      macros: const MacroGoals(kcal: 2000, protein: 150, carbs: 200, fat: 60),
    );
    expect(fatLoss.validate(), contains('Enter your starting body-fat %.'));
    expect(fatLoss.copyWith(startBodyFatPct: 30).validate(), isEmpty);
    expect(
      fatLoss.copyWith(startBodyFatPct: 30, goalWeightKg: 95).validate(),
      contains('For fat loss the goal weight must be below the starting weight.'),
    );
    // Weight gain needs no body fat.
    expect(fatLoss.copyWith(bodyGoal: BodyGoal.weightGain, goalWeightKg: 95).validate(), isEmpty);
    // Skin-only plans need no body numbers or calories.
    final skin = TransformationPlan(
      id: 's',
      name: 'Skin',
      start: monday,
      end: monday.add(const Duration(days: 30)),
      areas: const {GoalArea.skin},
      macros: const MacroGoals(kcal: 0, protein: 0, carbs: 0, fat: 0),
    );
    expect(skin.validate(), isEmpty);
  });

  test('JSON codec round-trips and rejects foreign files', () {
    final json = PlanCodec.encode(plan.copyWith(weeklyKcalStep: 50));
    expect(json, contains('"format": "fit-plan"'));
    expect(json, contains('"time": "07:00"'));
    final back = PlanCodec.decode(json);
    expect(back, plan.copyWith(weeklyKcalStep: 50));
    expect(() => PlanCodec.decode('not json'), throwsFormatException);
    expect(() => PlanCodec.decode('{"hello": 1}'), throwsFormatException);
  });
}

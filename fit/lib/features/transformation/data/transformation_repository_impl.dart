import 'dart:async';

import 'package:hive_ce/hive.dart';

import '../../../core/storage/hive_store.dart';
import '../../../core/storage/settings_store.dart';
import '../domain/entities/transformation_plan.dart';
import '../domain/repositories/transformation_repository.dart';
import 'plan_codec.dart';

/// Hive-backed [TransformationRepository].
///
/// * plans: box `fit_transformation`, one record per plan (JSON map).
/// * check-ins: box `fit_plan_checks`, key `yyyy-MM-dd#itemId` → time ticked.
/// * mode and active plan id: [SettingsStore].
class TransformationRepositoryImpl implements TransformationRepository {
  TransformationRepositoryImpl(this._plans, this._checks, this._settings);

  final HiveStore<TransformationPlan> _plans;
  final Box<dynamic> _checks;
  final SettingsStore _settings;
  final _modeChanges = StreamController<void>.broadcast();

  @override
  List<TransformationPlan> plans() => _plans.getAll()..sort((a, b) => b.start.compareTo(a.start));

  @override
  TransformationPlan? activePlan() {
    final id = _settings.read<String>(SettingsStore.kActivePlan);
    return id == null ? null : _plans.get(id);
  }

  @override
  Future<void> savePlan(TransformationPlan plan) async {
    await _plans.put(plan.id, plan);
    await _settings.write(SettingsStore.kActivePlan, plan.id);
    _modeChanges.add(null);
  }

  @override
  Future<void> deletePlan(String id) async {
    await _plans.delete(id);
    final keys = _checks.keys.where((k) => k.toString().endsWith('@$id')).toList();
    await _checks.deleteAll(keys);
    if (_settings.read<String>(SettingsStore.kActivePlan) == id) {
      await _settings.write(SettingsStore.kActivePlan, null);
      await _settings.write(SettingsStore.kAppMode, AppMode.general.name);
    }
    _modeChanges.add(null);
  }

  @override
  AppMode get mode => AppMode.values.firstWhere(
    (m) => m.name == _settings.read<String>(SettingsStore.kAppMode),
    orElse: () => AppMode.general,
  );

  @override
  Future<void> setMode(AppMode mode) async {
    await _settings.write(SettingsStore.kAppMode, mode.name);
    _modeChanges.add(null);
  }

  String? get _planId => _settings.read<String>(SettingsStore.kActivePlan);

  /// Check-ins are scoped to the active plan: `day#item@plan`.
  String _key(String dayKey, String itemId) => '$dayKey#$itemId@${_planId ?? '-'}';

  @override
  Set<String> checksFor(String dayKey) {
    final suffix = '@${_planId ?? '-'}';
    final prefix = '$dayKey#';
    return {
      for (final k in _checks.keys)
        if (k.toString().startsWith(prefix) && k.toString().endsWith(suffix))
          k.toString().substring(prefix.length, k.toString().length - suffix.length),
    };
  }

  @override
  Map<String, Set<String>> checksForDays(Iterable<String> dayKeys) {
    final wanted = dayKeys.toSet();
    final suffix = '@${_planId ?? '-'}';
    final out = {for (final d in wanted) d: <String>{}};
    for (final k in _checks.keys) {
      final key = k.toString();
      if (!key.endsWith(suffix)) continue;
      final hash = key.indexOf('#');
      if (hash < 0) continue;
      final day = key.substring(0, hash);
      if (!wanted.contains(day)) continue;
      out[day]!.add(key.substring(hash + 1, key.length - suffix.length));
    }
    return out;
  }

  @override
  Future<void> setCheck(String dayKey, String itemId, bool done) async {
    final key = _key(dayKey, itemId);
    if (done) {
      await _checks.put(key, DateTime.now().millisecondsSinceEpoch);
    } else {
      await _checks.delete(key);
    }
  }

  @override
  Stream<void> watch() {
    late StreamController<void> c;
    final subs = <StreamSubscription<void>>[];
    c = StreamController<void>.broadcast(
      onListen: () {
        subs
          ..add(_plans.watch().listen((_) => c.add(null)))
          ..add(_checks.watch().listen((_) => c.add(null)))
          ..add(_modeChanges.stream.listen((_) => c.add(null)));
      },
      onCancel: () {
        for (final s in subs) {
          s.cancel();
        }
        subs.clear();
      },
    );
    return c.stream;
  }

  @override
  String exportPlan(TransformationPlan plan) => PlanCodec.encode(plan);

  @override
  TransformationPlan importPlan(String json) => PlanCodec.decode(json);
}

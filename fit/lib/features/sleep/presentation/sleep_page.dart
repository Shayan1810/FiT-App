import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/domain/data_source.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/widgets/bars_3d.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/depth_card.dart';
import '../../../core/widgets/entrance.dart';
import '../../../core/widgets/ring_3d.dart';
import '../../insights/domain/calculators/sleep_calculator.dart';
import '../../insights/domain/entities/daily_briefing.dart';
import '../../insights/presentation/bloc/insights_bloc.dart';
import '../domain/entities/sleep_session.dart';
import 'bloc/sleep_bloc.dart';
import '../../../core/platform/health_brand.dart';

/// Sleep tab: last night, the week, debt, regularity and tonight's bedtime.
class SleepPage extends StatelessWidget {
  const SleepPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 84),
        child: GradientFab(
          icon: Icons.bedtime_rounded,
          label: 'Log sleep',
          onTap: () => showLogSleepSheet(context),
        ),
      ),
      body: BlocBuilder<InsightsBloc, InsightsState>(
        builder: (context, ins) {
          final b = ins.briefing;
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              const SliverSafeArea(
                bottom: false,
                sliver: SliverToBoxAdapter(
                  child: PageHeader(title: 'Sleep', subtitle: 'Recovery starts at night'),
                ),
              ),
              SliverList.list(
                children: [
                  if (b != null) ...[
                    Entrance(child: _LastNight(b.sleep)),
                    Entrance(index: 1, child: _Stats(b.sleep)),
                    Entrance(index: 2, child: _Week(b.sleep)),
                    Entrance(index: 3, child: _Tonight(b.plan)),
                  ],
                  const SectionHeader('History'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    child: Text('Tap a night to edit · swipe left to delete', style: AppText.caption),
                  ),
                  const _History(),
                  const SizedBox(height: 170),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LastNight extends StatelessWidget {
  const _LastNight(this.s);
  final SleepSummary s;

  @override
  Widget build(BuildContext context) {
    final sessions = context.select((SleepBloc b) => b.state.sessions);
    final today = DateKeys.of(DateTime.now());
    final last = sessions.where((x) => x.wakeDayKey == today).toList();
    final main = last.isEmpty ? null : last.reduce((a, b) => a.minutes >= b.minutes ? a : b);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: DepthCard(
        style: DepthStyle.accent,
        accent: AppColors.sleep,
        tilt: true,
        child: Row(
          children: [
            SingleRing(
              progress: (s.lastNightMinutes ?? 0) / s.needMinutes,
              color: const Color(0xFFC7D2FE),
              size: 120,
              stroke: 13,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.lastNightMinutes == null ? '—' : DateKeys.hm(s.lastNightMinutes!),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  Text(
                    'of ${s.needMinutes ~/ 60}h need',
                    style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Last night', style: TextStyle(color: Colors.white70)),
                  if (main == null)
                    const Text(
                      'Not logged yet',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    )
                  else ...[
                    Text(
                      '${DateKeys.clock(main.start)} – ${DateKeys.clock(main.end)}',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    if (s.score != null)
                      Pill('Sleep score ${s.score}', color: Colors.white, icon: Icons.star_rounded),
                    if (main.quality != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            for (var i = 1; i <= 5; i++)
                              Icon(
                                i <= main.quality! ? Icons.star_rounded : Icons.star_border_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats(this.s);
  final SleepSummary s;

  @override
  Widget build(BuildContext context) {
    final sd = s.midpointSdMinutes;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          _tile(
            'Sleep debt',
            DateKeys.hm(s.debt7Minutes),
            s.debt7Minutes > 300 ? AppColors.danger : AppColors.sleep,
          ),
          const SizedBox(width: 10),
          _tile(
            'Regularity',
            sd == null ? '—' : '±${sd.round()} min',
            (sd ?? 0) > 60 ? AppColors.warning : AppColors.sleep,
          ),
          const SizedBox(width: 10),
          _tile('7-day avg', s.avg7Minutes == null ? '—' : DateKeys.hm(s.avg7Minutes!), AppColors.sleep),
        ],
      ),
    );
  }

  Widget _tile(String k, String v, Color c) => Expanded(
    child: DepthCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Text(
            v,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: c),
          ),
          const SizedBox(height: 2),
          Text(k, style: AppText.caption),
        ],
      ),
    ),
  );
}

class _Week extends StatelessWidget {
  const _Week(this.s);
  final SleepSummary s;

  @override
  Widget build(BuildContext context) {
    final days = DateKeys.lastNDays(DateTime.now(), 7);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: DepthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This week (hours)', style: AppText.title),
            Text('Dashed line = your nightly need', style: AppText.caption),
            const SizedBox(height: 12),
            Bars3D(
              color: AppColors.sleep,
              target: s.needMinutes / 60,
              valueLabel: (v) => '${v.toStringAsFixed(1)}h',
              data: [
                for (var i = 0; i < days.length; i++)
                  BarDatum(
                    label: DateFormat('E').format(days[i]).substring(0, 1),
                    value: s.minutesByDay[i] / 60,
                    highlight: i == days.length - 1,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tonight extends StatelessWidget {
  const _Tonight(this.p);
  final NextDayPlan p;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: DepthCard(
        style: DepthStyle.dark,
        child: Row(
          children: [
            const IconBadge(icon: Icons.bedtime_rounded),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tonight', style: TextStyle(color: Colors.white70)),
                  Text(
                    'Lights out ${DateKeys.clock(p.bedtime)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                  Text(
                    'to wake at ${DateKeys.clock(p.wake)} with your full need + ${SleepCalculator.onsetLatencyMinutes} min to fall asleep',
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History();

  @override
  Widget build(BuildContext context) {
    final sessions = context.select((SleepBloc b) => b.state.sessions);
    if (sessions.isEmpty) {
      return EmptyState(
        icon: Icons.nightlight_round,
        title: 'No sleep logged',
        message: 'Log last night, or connect ${HealthBrand.app} to import it automatically.',
      );
    }
    return Column(
      children: [
        for (final s in sessions.take(21))
          Dismissible(
            key: ValueKey(s.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 28),
              child: const Icon(Icons.delete_rounded, color: AppColors.danger),
            ),
            onDismissed: (_) => context.read<SleepBloc>().add(SleepDeleted(s.id)),
            child: ListTile(
              onTap: () => showLogSleepSheet(context, session: s),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Icon(
                s.source == DataSource.healthConnect ? Icons.watch_rounded : Icons.nightlight_round,
                color: AppColors.sleep,
              ),
              title: Text(DateKeys.hm(s.minutes), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${DateFormat('EEE d MMM').format(s.end)} · ${DateKeys.clock(s.start)}–${DateKeys.clock(s.end)}',
                style: AppText.caption,
              ),
              trailing: s.quality == null
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < s.quality!; i++)
                          const Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
                      ],
                    ),
            ),
          ),
      ],
    );
  }
}

/// Opens the "Log sleep" sheet, or the editor when [session] is given
/// (also for nights imported from Samsung Health).
Future<void> showLogSleepSheet(BuildContext context, {SleepSession? session}) {
  final bloc = context.read<SleepBloc>();
  return showAppSheet(
    context,
    BlocProvider.value(
      value: bloc,
      child: _LogSleepSheet(session: session),
    ),
  );
}

class _LogSleepSheet extends StatefulWidget {
  const _LogSleepSheet({this.session});
  final SleepSession? session;

  @override
  State<_LogSleepSheet> createState() => _LogSleepSheetState();
}

class _LogSleepSheetState extends State<_LogSleepSheet> {
  late final SleepSession? _s = widget.session;
  late TimeOfDay _bed = _s == null ? const TimeOfDay(hour: 23, minute: 0) : TimeOfDay.fromDateTime(_s.start);
  late TimeOfDay _wake = _s == null ? const TimeOfDay(hour: 7, minute: 0) : TimeOfDay.fromDateTime(_s.end);
  late DateTime _wakeDay = _s?.end ?? DateTime.now();
  late int _quality = _s?.quality ?? 3;

  (DateTime, DateTime) get _range {
    final wake = DateTime(_wakeDay.year, _wakeDay.month, _wakeDay.day, _wake.hour, _wake.minute);
    var bed = DateTime(_wakeDay.year, _wakeDay.month, _wakeDay.day, _bed.hour, _bed.minute);
    if (!bed.isBefore(wake)) bed = bed.subtract(const Duration(days: 1));
    return (bed, wake);
  }

  Future<void> _pick(bool bed) async {
    final t = await showTimePicker(context: context, initialTime: bed ? _bed : _wake);
    if (t != null) setState(() => bed ? _bed = t : _wake = t);
  }

  @override
  Widget build(BuildContext context) {
    final (start, end) = _range;
    final minutes = end.difference(start).inMinutes;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_s == null ? 'Log sleep' : 'Edit sleep', style: AppText.title),
          if (_s?.source == DataSource.healthConnect)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Imported from ${HealthBrand.app} — your correction is kept and not overwritten by sync.',
                style: AppText.caption,
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _timeTile('Fell asleep', _bed, Icons.bedtime_rounded, () => _pick(true))),
              const SizedBox(width: 12),
              Expanded(child: _timeTile('Woke up', _wake, Icons.wb_sunny_rounded, () => _pick(false))),
            ],
          ),
          const SizedBox(height: 10),
          ActionChip(
            avatar: const Icon(Icons.event_rounded, size: 18),
            label: Text('Woke on ${DateKeys.friendly(_wakeDay)}'),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _wakeDay,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => _wakeDay = d);
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Total: ${DateKeys.hm(minutes)}',
            textAlign: TextAlign.center,
            style: AppText.title.copyWith(color: AppColors.sleep),
          ),
          const SizedBox(height: 12),
          const Text('How rested do you feel?', textAlign: TextAlign.center),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _quality = i),
                  icon: Icon(
                    i <= _quality ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppColors.warning,
                    size: 32,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: minutes < 20 || minutes > 16 * 60
                ? null
                : () {
                    context.read<SleepBloc>().add(
                      SleepLogged(
                        SleepSession(
                          id: _s?.id ?? IdGenerator.next('sleep_'),
                          start: start,
                          end: end,
                          quality: _quality,
                          source: DataSource.manual,
                        ),
                      ),
                    );
                    Navigator.pop(context);
                  },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _timeTile(String label, TimeOfDay t, IconData icon, VoidCallback onTap) => DepthCard(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Column(
      children: [
        Icon(icon, color: AppColors.sleep),
        const SizedBox(height: 4),
        Text(t.format(context), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        Text(label, style: AppText.caption),
      ],
    ),
  );
}

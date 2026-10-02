import 'package:fit/features/health_sync/data/health_connect_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HealthKit sleep segments merge into nights', () {
    DateTime t(int d, int h, [int m = 0]) => DateTime(2025, 3, d, h, m);
    final nights = HealthConnectSource.mergeSegments([
      ('a', t(1, 23), t(2, 1, 30)),
      ('b', t(2, 1, 50), t(2, 4)), // 20 min awake → same night
      ('c', t(2, 4, 30), t(2, 7)),
      ('d', t(2, 14), t(2, 14, 40)), // afternoon nap → its own session
      ('e', t(2, 23, 15), t(3, 6, 45)),
    ]);
    expect(nights.map((n) => n.id), ['hk_a', 'hk_d', 'hk_e']);
    expect(nights.first.start, t(1, 23));
    expect(nights.first.end, t(2, 7));
    expect(HealthConnectSource.mergeSegments(const []), isEmpty);
  });
}

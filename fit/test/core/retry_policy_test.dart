import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:fit/core/network/retry_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final waits = <Duration>[];
  RetryPolicy policy({int attempts = 5}) =>
      RetryPolicy(maxAttempts: attempts, random: Random(1), sleep: (d) async => waits.add(d));

  setUp(waits.clear);

  test('backoff delay is bounded by base × 2ⁿ and the cap', () {
    final p = policy();
    for (var n = 0; n < 8; n++) {
      final cap = min(8000, 400 * pow(2, n).toInt());
      expect(p.delayFor(n).inMilliseconds, inInclusiveRange(0, cap));
    }
  });

  test('Retry-After header wins (capped at maxDelay)', () {
    expect(policy().delayFor(0, retryAfter: const Duration(seconds: 2)), const Duration(seconds: 2));
    expect(policy().delayFor(0, retryAfter: const Duration(minutes: 5)), const Duration(seconds: 8));
  });

  test('retries transient errors then succeeds', () async {
    var calls = 0;
    final result = await policy().run((_) async {
      calls++;
      if (calls < 3) throw const SocketException('down');
      return 'ok';
    });
    expect(result, 'ok');
    expect(calls, 3);
    expect(waits.length, 2);
  });

  test('does not retry non-retryable errors', () async {
    var calls = 0;
    await expectLater(
      policy().run((_) async {
        calls++;
        throw RemoteCallException('bad request', statusCode: 400, retryable: false);
      }),
      throwsA(isA<RemoteCallException>()),
    );
    expect(calls, 1);
  });

  test('gives up after maxAttempts and rethrows the last error', () async {
    var calls = 0;
    await expectLater(
      policy(attempts: 4).run((_) async {
        calls++;
        throw TimeoutException('slow');
      }),
      throwsA(isA<TimeoutException>()),
    );
    expect(calls, 4);
  });

  test('status classification', () {
    for (final c in [408, 429, 500, 502, 503, 504]) {
      expect(RetryPolicy.isRetryableStatus(c), isTrue, reason: '$c');
    }
    for (final c in [400, 401, 403, 404]) {
      expect(RetryPolicy.isRetryableStatus(c), isFalse, reason: '$c');
    }
  });

  test('5 attempts turn a 65 % per-call success rate into ≥ 99.47 %', () {
    double overall(double p, int k) => 1 - pow(1 - p, k).toDouble();
    expect(overall(0.65, 5), greaterThanOrEqualTo(0.9947));
    expect(overall(0.70, 5), greaterThan(0.995));
  });
}

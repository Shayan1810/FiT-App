import 'dart:async';
import 'dart:io';
import 'dart:math';

/// Error raised by a remote call, carrying whether a retry may help.
class RemoteCallException implements Exception {
  RemoteCallException(this.message, {this.statusCode, this.retryable = true, this.retryAfter});

  final String message;
  final int? statusCode;
  final bool retryable;

  /// Server-suggested wait (HTTP `Retry-After`), honoured by [RetryPolicy].
  final Duration? retryAfter;

  @override
  String toString() => 'RemoteCallException($statusCode): $message';
}

/// Exponential backoff with "full jitter" (AWS Architecture Blog, 2015).
///
/// Attempt *n* (0-based) waits `random(0, min(maxDelay, baseDelay × 2ⁿ))`
/// before the next try. Jitter spreads retries from many clients so they
/// don't hammer the API in lock-step after a rate-limit (HTTP 429).
///
/// Success-rate maths (documented in the handbook): if one attempt succeeds
/// with probability *p*, then *k* attempts succeed with 1 − (1 − p)ᵏ.
/// With the default 5 attempts, even a poor p = 0.65 gives 99.47 %, and the
/// usual p ≥ 0.70 gives ≥ 99.76 % — before counting the cache and the local
/// food-database fallback, which push the end-to-end rate higher still.
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 5,
    this.baseDelay = const Duration(milliseconds: 400),
    this.maxDelay = const Duration(seconds: 8),
    this.attemptTimeout = const Duration(seconds: 20),
    Random? random,
    this.sleep = _defaultSleep,
  }) : _random = random;

  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;
  final Duration attemptTimeout;
  final Random? _random;

  /// Injectable sleep so tests run instantly.
  final Future<void> Function(Duration) sleep;

  static Future<void> _defaultSleep(Duration d) => Future<void>.delayed(d);

  /// The backoff delay before retry number [attempt] (0-based).
  Duration delayFor(int attempt, {Duration? retryAfter}) {
    if (retryAfter != null) {
      return retryAfter > maxDelay ? maxDelay : retryAfter;
    }
    final capMs = min(maxDelay.inMilliseconds, baseDelay.inMilliseconds * pow(2, attempt).toInt());
    final rng = _random ?? Random();
    return Duration(milliseconds: rng.nextInt(capMs + 1));
  }

  /// Whether [error] is worth retrying (network faults, timeouts, 408/429/5xx).
  static bool isRetryable(Object error) {
    if (error is RemoteCallException) return error.retryable;
    return error is SocketException ||
        error is TimeoutException ||
        error is HttpException ||
        error is HandshakeException ||
        error is FormatException;
  }

  /// HTTP status codes that are transient.
  static bool isRetryableStatus(int code) =>
      code == 408 || code == 429 || code == 500 || code == 502 || code == 503 || code == 504;

  /// Runs [task] until it succeeds, a non-retryable error occurs, or
  /// [maxAttempts] is reached. [onRetry] is called before each wait.
  Future<T> run<T>(
    Future<T> Function(int attempt) task, {
    void Function(int attempt, Object error, Duration wait)? onRetry,
  }) async {
    Object? lastError;
    StackTrace? lastStack;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await task(attempt).timeout(attemptTimeout);
      } catch (e, st) {
        lastError = e;
        lastStack = st;
        final last = attempt == maxAttempts - 1;
        if (last || !isRetryable(e)) break;
        final wait = delayFor(attempt, retryAfter: e is RemoteCallException ? e.retryAfter : null);
        onRetry?.call(attempt, e, wait);
        await sleep(wait);
      }
    }
    Error.throwWithStackTrace(lastError!, lastStack!);
  }
}

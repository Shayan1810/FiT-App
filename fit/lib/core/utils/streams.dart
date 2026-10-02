import 'dart:async';

/// Merges several "something changed" streams into one broadcast stream.
/// Subscriptions to the sources are cancelled when the last listener leaves.
Stream<void> mergeChanges(List<Stream<void>> sources) {
  late StreamController<void> c;
  final subs = <StreamSubscription<void>>[];
  c = StreamController<void>.broadcast(
    onListen: () {
      for (final s in sources) {
        subs.add(s.listen(c.add));
      }
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

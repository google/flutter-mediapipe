/// Runs operations one at a time, in the order they were added. A failure
/// reaches the operation's caller and leaves the queue usable.
final class OperationQueue {
  Future<void> _tail = Future.value();

  /// Runs [action] once every earlier operation has finished.
  Future<T> add<T>(Future<T> Function() action) {
    final operation = _tail.then((_) => action());
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }
}

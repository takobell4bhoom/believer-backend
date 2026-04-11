enum AsyncStatus { idle, loading, success, error }

class AsyncState<T> {
  final AsyncStatus status;
  final T? data;
  final String? error;

  const AsyncState._({
    required this.status,
    this.data,
    this.error,
  });

  const AsyncState.idle() : this._(status: AsyncStatus.idle);
  const AsyncState.loading() : this._(status: AsyncStatus.loading);
  const AsyncState.success(T value) : this._(status: AsyncStatus.success, data: value);
  const AsyncState.error(String message) : this._(status: AsyncStatus.error, error: message);

  bool get isIdle => status == AsyncStatus.idle;
  bool get isLoading => status == AsyncStatus.loading;
  bool get isSuccess => status == AsyncStatus.success;
  bool get isError => status == AsyncStatus.error;
}

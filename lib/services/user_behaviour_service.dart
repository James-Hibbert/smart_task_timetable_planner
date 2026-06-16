class UserBehaviourService {
  static final Map<String, int> _actionUsage = {};
  static final Map<String, int> _actionIgnored = {};

  static const int _maxTrackedActions = 50;
  static const int _minimumSignals = 2;

  static void recordAction(String actionKey) {
    if (actionKey.trim().isEmpty) return;

    _actionUsage[actionKey] = (_actionUsage[actionKey] ?? 0) + 1;
    _ensureCapacity();
  }

  static void recordIgnored(String actionKey) {
    if (actionKey.trim().isEmpty) return;

    _actionIgnored[actionKey] = (_actionIgnored[actionKey] ?? 0) + 1;
    _ensureCapacity();
  }

  static int getUsage(String actionKey) {
    return _actionUsage[actionKey] ?? 0;
  }

  static int getIgnored(String actionKey) {
    return _actionIgnored[actionKey] ?? 0;
  }

  /// Returns true only when there is enough signal
  /// and usage outweighs ignored behaviour.
  static bool isPreferred(String actionKey) {
    final usage = getUsage(actionKey);
    final ignored = getIgnored(actionKey);

    final totalSignals = usage + ignored;

    if (totalSignals < _minimumSignals) {
      return false;
    }

    return usage > ignored;
  }

  /// Prevents unbounded memory growth
  static void _ensureCapacity() {
    if (_actionUsage.length <= _maxTrackedActions) return;

    final sortedKeys = _actionUsage.keys.toList()
      ..sort((a, b) => getUsage(a).compareTo(getUsage(b)));

    final keysToRemove =
    sortedKeys.take(_actionUsage.length - _maxTrackedActions);

    for (final key in keysToRemove) {
      _actionUsage.remove(key);
      _actionIgnored.remove(key);
    }
  }

  /// Optional: clear behaviour (useful for testing/reset)
  static void reset() {
    _actionUsage.clear();
    _actionIgnored.clear();
  }
}
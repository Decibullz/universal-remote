enum TvPowerState {
  on,
  off,
  unknown,
}

class TvStatus {
  const TvStatus({
    required this.powerState,
    this.currentApp,
  });

  final TvPowerState powerState;
  final String? currentApp;
}

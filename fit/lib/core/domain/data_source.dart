/// Where a record came from. Shared by every feature.
enum DataSource {
  /// Typed in by the user inside FiT.
  manual,

  /// Imported from Health Connect (Samsung Health, Google Fit, a watch, …).
  healthConnect,
}

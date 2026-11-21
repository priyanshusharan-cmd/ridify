/// Frontend-only visibility switches.
///
/// These flags ONLY hide buttons in the UI. All the underlying features,
/// screens, services and backend connections are untouched and still work.
///
/// To unhide everything, set every flag below back to `true`.
class FeatureFlags {
  FeatureFlags._();

  /// "Shared Start" and "Flexible" route options on the Offer a Ride screen.
  static const bool showFlexibleRouteOptions = false;

  /// "Chat" button in the ride status panel (before and during live tracking).
  static const bool showChatButton = false;

  /// "Verify your account" button on the My Profile screen.
  static const bool showVerifyAccountButton = false;
}

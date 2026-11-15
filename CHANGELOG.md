# Changelog

## [1.11.0] - 2026-11-15

### Added
- Customizable title, message, footer, and color palette for the Strict Mode blocked screen.
- A prominent circular lock panel and an activation control that stays accessible at the bottom of the Strict Mode screen.

### Improved
- Removed the Customize action from the blocked screen; appearance settings are managed inside OpenLock.
- Smoother scrolling and less unnecessary timer-driven rebuilding while configuring Strict Mode.
- Best-effort monitor-service restart when the app task is dismissed. Android force-stop, revoked permissions, and manufacturer battery restrictions can still stop monitoring.

### Notes
- Quick Block activation and duration controls are not included in this version yet.
- This is a debug/test build; verify update-signature compatibility before installing over an existing APK.

# Changelog

## [1.11.2] - 2026-11-15

### Fixed
- Restore an unexpired Strict Mode commitment when OpenLock is explicitly launched again after its task was dismissed.
- Push the saved protection configuration to the native monitor before restarting the foreground service, preserving the original end time instead of creating a fresh countdown.

### Notes
- This is best-effort recovery on app launch; Android force-stop, revoked permissions, OEM process restrictions, and other system-level termination can still interrupt enforcement.
- This is a debug/test build. Verify update-signature compatibility before installing over an existing APK.

# Changelog

## [1.11.1] - 2026-11-15

### Fixed
- Prevent the Strict Mode setup form from appearing temporarily while saved configuration is still loading.
- Reduce the duration dropdown's horizontal overflow on narrow screens.

### Improved
- Show each installed app's launcher icon in both the Strict Mode selection list and the active protected-app list, reusing the native icon cache.
- Keep a clear fallback icon and placeholder when an app icon is unavailable.

### Notes
- Strict Mode recovery after dismissing OpenLock from Recents still requires device testing; this build does not claim to defeat Android or manufacturer process-killing policies.
- This is a debug/test build. Verify update-signature compatibility before installing over an existing APK.

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

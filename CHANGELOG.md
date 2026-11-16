# Changelog

## [1.12.2] - 2026-11-16

### Fixed
- Sign CI test APKs with the same persistent keystore as release APKs, enabling in-place updates across revisions.
- Fail the test APK workflow when persistent signing secrets are missing instead of publishing an APK signed with a temporary debug key.


## [1.12.1] - 2026-11-16

### Fixed
- Remove an unused Dart import that caused the zero-tolerance static analysis job to fail.


## [1.12.0] - 2026-11-16

### Added
- Exclude the OpenLock launcher task from Android Recents while keeping its foreground monitor and accessibility enforcement services independent of the launcher task.
- Add an accessibility-based Strict Mode enforcement path that blocks selected apps even when the main monitor service is unavailable.
- Apply the Strict Mode barrier to OpenLock's own App info and Device Administrator deactivation screens when the accessibility guard recognises them.

### Improved
- Debounce accessibility-triggered barriers to avoid repeated launches from window-content events.
- Keep the existing UsageStats monitor as a second enforcement path.

### Notes
- Requires the OpenLock Accessibility service to remain enabled for the independent enforcement and OS-settings guard.
- Android does not let an ordinary app make Device Administrator impossible to deactivate. Force-stop, disabling Accessibility, revoking special access, or OEM/system-level termination may still bypass protection.
- Debug/test build. APK update signing compatibility is a separate issue and may require a one-time migration before future in-place updates work.

# Changelog

## [1.11.4] - 2026-11-15

### Fixed
- Import the shared InstalledApp model explicitly in the Strict Mode screen so the launcher-icon widget passes Dart analysis and CI can continue to tests and APK build.

### Notes
- Includes the v1.11.3 best-effort immediate foreground-monitor restart when the app task is dismissed.
- Device testing on Infinix/XOS is still required; Android force-stop, OEM process termination, or revoked special access can still interrupt enforcement.
- This is a debug/test build. Verify update-signature compatibility before installing over an existing APK.

# Changelog

## [1.11.3] - 2026-11-15

### Fixed
- Request the foreground monitor restart synchronously from `onTaskRemoved` instead of relying on a delayed Handler callback that may be lost when an OEM launcher kills the app process after dismissing Recents.
- Preserve the existing native protection snapshot and original Strict Mode deadline during the restart attempt.

### Notes
- This improves best-effort recovery when OpenLock is swiped away from Recents; it cannot guarantee protection against Android force-stop, OEM process termination, revoked Usage Access/overlay permissions, or other system-level restrictions.
- Device testing is still required to verify behavior on Infinix/XOS.
- This is a debug/test build. Verify update-signature compatibility before installing over an existing APK.

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

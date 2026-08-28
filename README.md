# Universal TV Remote

A private Flutter remote for TVs on your local network.

## Included in v1

- Multiple saved TVs
- LG webOS
- Roku TV / Roku devices
- Vizio SmartCast
- Remembers the last TV you used
- D-pad + OK
- Back + Home
- Input picker + menu/options
- Volume up/down + mute
- Play / pause
- Power off
- iPhone/Android keyboard input
- Four editable app favorites, saved separately for each TV
- Add, rename, remove, and switch TVs
- LAN scanning without SSDP/multicast on iPhone
- LG and Vizio pairing credentials stored in secure storage

## Why discovery does not use SSDP on iPhone

Roku, LG, and Vizio all have multicast/SSDP discovery options, but a physical iPhone
requires Apple's restricted multicast networking entitlement to send multicast packets.
This project instead probes the phone's current IPv4 /24 using short, parallel *unicast*
requests to the known TV APIs.

That keeps the personal sideload simple. Manual IP entry is included for networks that
are not /24.

## Prerequisites

The checked-in project already contains its iOS files. On the Mac that will build the
app, install Flutter and Xcode, open Xcode once to finish its setup, and sign in to your
Apple Account under **Xcode > Settings > Accounts**.

From the project folder, check the toolchain and restore packages:

```bash
flutter doctor -v
flutter pub get
```

Only use the native bootstrap script if the `ios/` or `android/` directory has been
deleted and needs to be recreated:

```bash
dart run tool/bootstrap_native.dart
```

## Build and install on a connected iPhone

This project currently uses:

- Display name: `Tv Remote`
- Bundle identifier: `com.codysnell.universalTvRemote`
- Minimum iOS version: iOS 15.0

### 1. Connect and prepare the iPhone

1. Connect the iPhone to the Mac with a USB cable and unlock it.
2. Tap **Trust** if either device asks whether to trust the other.
3. Enable **Settings > Privacy & Security > Developer Mode** on the iPhone if prompted.
4. Confirm Flutter can see it:

   ```bash
   flutter devices
   ```

The iPhone's device ID is shown in the second column. Keep the phone unlocked during
the first build and launch.

### 2. Configure signing the first time

Open the iOS workspace, not the `.xcodeproj` file:

```bash
open ios/Runner.xcworkspace
```

In Xcode:

1. Select the **Runner** project and the **Runner** target.
2. Open **Signing & Capabilities**.
3. Enable **Automatically manage signing**.
4. Select your Apple Developer Team.
5. Confirm the bundle identifier is `com.codysnell.universalTvRemote`.
6. Select the connected iPhone as the run destination.

An ordinary Apple Account can sign a development build for your own iPhone. A paid
Apple Developer Program membership is required for the family distribution options
below. See Flutter's [physical iOS device setup](https://docs.flutter.dev/get-started/install/macos/mobile-ios)
if Xcode reports a signing or device-preparation error.

### 3. Build, install, and run

For a normal debug build:

```bash
flutter run -d <DEVICE_ID>
```

For a release build that is installed and launched on the connected iPhone:

```bash
flutter run --release -d <DEVICE_ID>
```

Replace `<DEVICE_ID>` with the value printed by `flutter devices`. You can also press
Run in Xcode after choosing the physical iPhone.

To create a signed release build without launching it:

```bash
flutter build ios --release
```

The app is created at `build/ios/iphoneos/Runner.app`. Flutter's
[iOS release guide](https://docs.flutter.dev/deployment/ios) covers archive and IPA
builds as well.

The first time the remote opens, allow **Local Network** access. If scanning later
returns no TVs, check **Settings > Apps > Tv Remote > Local Network** on the iPhone and
make sure the phone and TVs are on the same non-guest Wi-Fi network.

### Common device-build problems

- **No supported devices:** unlock the phone, reconnect the cable, confirm Trust and
  Developer Mode, then run `flutter devices` again.
- **Signing requires a development team:** choose the team in Xcode's Runner target.
- **Bundle identifier is unavailable:** change it to another globally unique reverse-
  domain value in Xcode, then use that same identifier for distribution profiles.
- **The app stopped opening with a free account:** free Personal Team provisioning
  expires after seven days; reconnect and rebuild the app.

## Share privately with family (without a public App Store listing)

### Recommended: TestFlight

TestFlight is the lowest-maintenance family option. The app is not published or
searchable in the public App Store, although the developer must have a paid
[Apple Developer Program membership](https://developer.apple.com/support/compare-memberships/)
and create a private App Store Connect record. Family members only need an Apple
Account and Apple's free TestFlight app.

1. Enroll in the Apple Developer Program and finish the app's signing setup.
2. Create an App Store Connect app using bundle ID
   `com.codysnell.universalTvRemote`.
3. Increase the build number in `pubspec.yaml` before each upload. For example,
   change `version: 1.0.0+1` to `version: 1.0.0+2`.
4. Build an App Store IPA:

   ```bash
   flutter build ipa --release
   ```

5. Upload the archive through Xcode Organizer, or upload the IPA from
   `build/ios/ipa/` with Apple's Transporter app.
6. In App Store Connect, open **TestFlight**, create an external testing group, add the
   family members' email addresses, and select the build.
7. After Apple's first external TestFlight review is approved, each family member can
   accept the email invitation and install the build in TestFlight.

TestFlight builds expire after 90 days, so upload a newer build before the current one
expires. See Apple's [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview)
and [external tester instructions](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers).

### Alternative: Ad Hoc IPA

Ad Hoc distribution avoids a public listing and TestFlight beta review, but it requires
more device management:

1. Use a paid Apple Developer Program membership.
2. Collect and register each family member's iPhone UDID in the developer account.
3. Create an Ad Hoc provisioning profile for
   `com.codysnell.universalTvRemote` that includes those devices.
4. Build the IPA:

   ```bash
   flutter build ipa --release --export-method ad-hoc
   ```

5. Install the signed IPA from `build/ios/ipa/` onto each registered iPhone using a Mac
   and Xcode or Apple Configurator.

Apple allows up to 100 registered iPhones per membership year. Adding a new phone can
require regenerating the provisioning profile and exporting a new IPA. Apple's
[Ad Hoc profile guide](https://developer.apple.com/help/account/provisioning-profiles/create-an-ad-hoc-provisioning-profile)
and [registered-device overview](https://developer.apple.com/help/account/devices/devices-overview)
describe those requirements.

### Why a free Apple Account is not practical for sharing

Free Personal Team profiles expire after seven days and are limited to three test
devices per platform. That is fine for development on your own phone, but family copies
would need frequent rebuilding and reinstalling. TestFlight is the best fit here;
choose Ad Hoc only if managing every device and installation manually is preferable.

## TV setup notes

### LG webOS

- Phone and TV must be on the same LAN.
- The first connection should show an approval prompt on the TV.
- Some models expose **LG Connect Apps**, **Mobile TV On**, or **IP Control** settings
  that need to be enabled.
- The app tries `ws://TV:3000` and falls back to secure `wss://TV:3001`.
- Installed launch points are queried from the TV, so Hulu/Netflix/Crunchyroll/MLB are
  matched by the apps actually installed on that LG.

### Roku

On newer Roku OS versions, enable:

**Settings > System > Advanced system settings > Control by mobile apps > Enabled**

The remote uses Roku ECP on local port `8060`. App IDs are queried from `/query/apps`,
so launcher buttons do not depend on hard-coded Roku channel IDs.

### Vizio SmartCast

The first connection starts SmartCast pairing. Enter the PIN shown on the TV.
The returned auth token is stored in secure storage.

SmartCast normally uses HTTPS port `7345` on newer sets and `9000` on some older sets.
Both are probed.

Hulu and Netflix include legacy fallback launch configs. The app also reads Vizio's
current SmartCast app catalog/availability data at runtime so app launch payloads can
follow firmware/catalog changes. If a specific app is not offered for your Vizio
model/firmware, the launcher reports that rather than pretending it launched.

## Keyboard behavior

The phone keyboard sends input through each TV platform's native remote-input API:

- LG: webOS IME `insertText`, delete, and Enter
- Roku: ECP `Lit_` characters, Backspace, and Enter
- Vizio: SmartCast ASCII key commands

A streaming app still has to expose/focus a compatible text field. If Netflix/Hulu/etc.
implements a screen that ignores the TV's remote keyboard API, no LAN remote can force
that field to accept text.

## Power-on

Power **off** is included.

Power **on** is intentionally not included in this first iPhone build. LG/Vizio wake-up
normally uses Wake-on-LAN broadcast/multicast traffic, which would put us back into
Apple's restricted multicast entitlement. Roku TVs may accept a network PowerOn command,
but behavior differs from Roku sticks and sleep states.

## Architecture

```text
TvRemoteController
├── LgWebOsController
├── RokuController
└── VizioController
```

The UI only talks to `TvRemoteController`, so another brand can be added without
rewriting the remote screen.

## Important v1 note

Smart-TV local APIs are firmware-sensitive, especially Vizio. This project is designed
to surface a useful error message instead of failing silently. If one of your exact TV
models responds differently, capture the model/firmware plus the error and adjust that
brand controller without touching the rest of the app.

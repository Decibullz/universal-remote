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
- Volume up/down + mute
- Play / pause
- Power off
- iPhone/Android keyboard input
- One-tap Hulu, Netflix, Crunchyroll, and MLB launch buttons
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

## First setup

This zip intentionally contains the app source but not generated `ios/` and `android/`
folders. Generate those folders with the Flutter SDK you already use so the native
projects exactly match your installed Flutter version.

From the project folder:

```bash
dart run tool/bootstrap_native.dart
```

That script:

1. Runs `flutter create` for iOS and Android.
2. Restores the included app source.
3. Adds iOS local-network/ATS configuration.
4. Enables Android cleartext LAN traffic for Roku/LG.
5. Runs `flutter pub get`.

Then:

```bash
flutter run
```

## iPhone signing

On your Mac:

1. Open `ios/Runner.xcworkspace`.
2. Select **Runner** > **Signing & Capabilities**.
3. Pick your Apple Developer Team.
4. Change the bundle identifier if desired.
5. Select your iPhone and Run.

No App Store Connect app record is required for development installation.

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
# universal-remote
# universal-remote

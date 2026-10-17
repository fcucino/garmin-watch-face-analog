# Galaxy Analog — Garmin watch face

An analog watch face for the **Forerunner 165 Music** (`fr165m`) in the style of the Galaxy Watch 4 classic analog face.

- All 12 hour numerals, a minute tick ring, and white tapered hands. The second hand uses the accent color and can be hidden.
- Four customizable slots at **2, 4, 8 and 10 o'clock**, each an icon plus value (optional progress arc, off by default). The defaults are date, floors climbed, temperature and weekly run distance.
- Battery (lightning icon + level) at **6 o'clock** and moon phase at **12 o'clock**. Both can be turned off.
- Tap a slot to open the matching Garmin widget.
- Always-on mode: hour ticks, outline numerals and outline hands, shifted every minute against burn-in.

## Battery behaviour

The FR165 has an AMOLED screen, so the OS never calls `onPartialUpdate`. The second hand can only show in high-power mode, which lasts a few seconds after a wrist raise or a touch.

To keep drawing work low:
- The dial, slots and indicators are drawn into one off-screen buffer, redrawn only when something on it visibly changes (a slot value, the battery level, the day or moon, a setting). The date is re-formatted once a day.
- Each `onUpdate` (once a minute, or once a second in high power) copies that buffer and draws the hour and minute hands, plus the second hand when enabled.
- Slot data comes from `Toybox.Complications` change callbacks. Nothing is polled on each second.

## Settings

You can change settings from the Connect IQ / Garmin Connect app on your phone. On the watch, long-press the face and choose the watch face settings.

Each slot can show: none, date, battery, steps, heart rate, calories, Body Battery, stress, notifications, floors climbed, distance today, weekly run distance, next sunrise/sunset, temperature, or intensity minutes.

## Build

You need the Connect IQ SDK, installed through the SDK Manager. `build.sh` reads the SDK path from `~/.Garmin/ConnectIQ/current-sdk.cfg`. It uses the developer key at `~/Dropbox/Various/garmin_developer_key`; set `GARMIN_DEV_KEY` to use a different key.

```sh
./build.sh          # bin/GalaxyAnalog.prg
./build.sh run      # build and open in the simulator
./build.sh export   # bin/GalaxyAnalog.iq for the Connect IQ store
```

To sideload, connect the watch over USB and copy `bin/GalaxyAnalog.prg` to `GARMIN/APPS/`.

The fonts (numerals, outline numerals, icons) are generated files. To regenerate them:

```sh
python3 tools/make_fonts.py [numerals.ttf]   # needs Pillow; defaults to the SDK's OpenSans
```

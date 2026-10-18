import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Lang;

//! Typed, cached access to the user settings (properties.xml).
module Settings {

    // Slot kinds, matching the list values in settings.xml
    enum SlotKind {
        SLOT_NONE = 0,
        SLOT_DATE,
        SLOT_BATTERY,
        SLOT_STEPS,
        SLOT_HEART_RATE,
        SLOT_CALORIES,
        SLOT_BODY_BATTERY,
        SLOT_STRESS,
        SLOT_NOTIFICATIONS,
        SLOT_FLOORS,
        SLOT_DISTANCE,
        SLOT_WEEKLY_RUN,
        SLOT_SUN,
        SLOT_TEMPERATURE,
        SLOT_INTENSITY,
        SLOT_KIND_COUNT
    }

    const ACCENT_COLORS = [
        0xFF3B30, // red
        0xFF8C00, // orange
        0xFFD60A, // yellow
        0x30D158, // green
        0x40C8E0, // cyan
        0x0A84FF, // blue
        0xBF5AF2, // purple
        0xFF375F, // pink
        0xFFFFFF  // white
    ] as Array<Number>;

    const DEFAULT_SLOTS = [SLOT_DATE, SLOT_FLOORS, SLOT_TEMPERATURE, SLOT_WEEKLY_RUN] as Array<Number>;

    var slots as Array<Number> = [SLOT_DATE, SLOT_FLOORS, SLOT_TEMPERATURE, SLOT_WEEKLY_RUN] as Array<Number>;
    var showSeconds as Boolean = true;
    var accentIndex as Number = 0;
    var accentColor as Number = ACCENT_COLORS[0];
    var showArcs as Boolean = false;
    var showBattery as Boolean = true;
    var showSun as Boolean = true;

    function load() as Void {
        for (var i = 0; i < 4; i++) {
            var v = readNumber("Slot" + (i + 1), DEFAULT_SLOTS[i]);
            slots[i] = (v >= 0 && v < SLOT_KIND_COUNT) ? v : SLOT_NONE;
        }
        showSeconds = readBoolean("ShowSeconds", true);
        accentIndex = readNumber("AccentColor", 0);
        if (accentIndex < 0 || accentIndex >= ACCENT_COLORS.size()) {
            accentIndex = 0;
        }
        accentColor = ACCENT_COLORS[accentIndex];
        showArcs = readBoolean("ShowArcs", false);
        showBattery = readBoolean("ShowBattery", true);
        showSun = readBoolean("ShowSun", true);
    }

    function readNumber(key as String, def as Number) as Number {
        try {
            var v = Properties.getValue(key);
            if (v instanceof Number) {
                return v;
            }
        } catch (e) {
        }
        return def;
    }

    function readBoolean(key as String, def as Boolean) as Boolean {
        try {
            var v = Properties.getValue(key);
            if (v instanceof Boolean) {
                return v;
            }
        } catch (e) {
        }
        return def;
    }
}

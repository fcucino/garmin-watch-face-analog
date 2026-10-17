import Toybox.ActivityMonitor;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! The four customizable data slots (2, 4, 8 and 10 o'clock).
//!
//! System data arrives through Complications change callbacks and is only
//! cached here; nothing is read on the per-second tick. Values that have no
//! callback (distance today, next sunrise/sunset) are checked once per minute
//! and the date once per day. `dirty` is set only when visible output changes.
class Slots {

    // Clock positions of the slots, in hours
    static const POSITIONS = [2, 4, 8, 10] as Array<Number>;

    // Icon font glyph per slot kind (see tools/make_fonts.py)
    static const ICONS = ["", "a", "n", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n"] as Array<String>;

    var centers as Array<[Number, Number]> = [] as Array<[Number, Number]>;
    var radius as Number = 32;

    // true when a displayed value changed since the last render
    var dirty as Boolean = true;

    private const ICON_HEIGHT = 26;
    private const ICON_GAP = 5;     // space between icon and text
    private const LINE_HEIGHT = 18; // text line pitch in the small font

    private var _iconFont as FontResource;
    private var _textFont as FontResource;
    private var _raw as Dictionary<Number, Object?> = {} as Dictionary<Number, Object?>;
    private var _text as Array<String> = ["", "", "", ""] as Array<String>;
    // Optional second text line (date: weekday)
    private var _sub as Array<String?> = [null, null, null, null] as Array<String?>;
    private var _progress as Array<Float?> = [null, null, null, null] as Array<Float?>;

    function initialize(iconFont as FontResource) {
        _iconFont = iconFont;
        _textFont = WatchUi.loadResource($.Rez.Fonts.Small) as FontResource;
    }

    //! Small text font shared with the indicators.
    function textFont() as FontResource {
        return _textFont;
    }

    //! Compute slot centers for a round screen of the given size.
    function layout(size as Number) as Void {
        var c = size / 2;
        var r = (size * 0.26).toNumber();
        radius = (size * 0.082).toNumber();
        centers = [] as Array<[Number, Number]>;
        for (var i = 0; i < POSITIONS.size(); i++) {
            var a = POSITIONS[i] * Math.PI / 6.0;
            centers.add([(c + r * Math.sin(a)).toNumber(), (c - r * Math.cos(a)).toNumber()]);
        }
    }

    //! (Re)subscribe to the complications needed by the current settings.
    function subscribe() as Void {
        Complications.registerComplicationChangeCallback(method(:onComplicationChanged));
        Complications.unsubscribeFromAllUpdates();
        _raw = {} as Dictionary<Number, Object?>;
        for (var i = 0; i < 4; i++) {
            var types = complicationTypes(Settings.slots[i]);
            for (var t = 0; t < types.size(); t++) {
                var type = types[t];
                if (_raw.hasKey(type)) {
                    continue;
                }
                var id = new Complications.Id(type);
                try {
                    _raw[type] = Complications.getComplication(id).value;
                    Complications.subscribeToUpdates(id);
                } catch (e) {
                    _raw[type] = null;
                }
            }
        }
        refresh();
    }

    function unsubscribe() as Void {
        Complications.unsubscribeFromAllUpdates();
        Complications.registerComplicationChangeCallback(null);
    }

    function onComplicationChanged(id as Complications.Id) as Void {
        var type = id.getType();
        try {
            _raw[type] = Complications.getComplication(id).value;
        } catch (e) {
            _raw[type] = null;
        }
        for (var i = 0; i < 4; i++) {
            if (complicationTypes(Settings.slots[i]).indexOf(type) >= 0) {
                format(i);
            }
        }
    }

    //! Re-format every slot (after subscribing / settings change).
    function refresh() as Void {
        for (var i = 0; i < 4; i++) {
            format(i);
        }
        dirty = true;
    }

    //! Once-a-minute check of the values that have no change callback.
    //! The date is only re-formatted when the day changes.
    function poll(newDay as Boolean) as Void {
        for (var i = 0; i < 4; i++) {
            var kind = Settings.slots[i];
            if (kind == Settings.SLOT_DISTANCE || kind == Settings.SLOT_SUN || (newDay && kind == Settings.SLOT_DATE)) {
                format(i);
            }
        }
    }

    //! Draw all slots into dc.
    function draw(dc as Dc) as Void {
        var accent = Settings.accent();
        for (var i = 0; i < 4; i++) {
            var kind = Settings.slots[i];
            if (kind == Settings.SLOT_NONE) {
                continue;
            }
            var x = centers[i][0];
            var y = centers[i][1];

            var p = _progress[i];
            if (Settings.showArcs && p != null && p > 0.0) {
                dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
                if (p >= 1.0) {
                    dc.drawCircle(x, y, radius);
                } else {
                    dc.drawArc(x, y, radius, Graphics.ARC_CLOCKWISE, 90, 90 - (360 * p).toNumber());
                }
            }

            // Stack icon and text line(s), centered on the slot
            var sub = _sub[i];
            var lines = sub != null ? 2 : 1;
            var top = y - (ICON_HEIGHT + ICON_GAP + lines * LINE_HEIGHT) / 2;
            var textTop = top + ICON_HEIGHT + ICON_GAP;
            var justify = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, top + ICON_HEIGHT / 2, _iconFont, ICONS[kind], justify);
            dc.drawText(x, textTop + LINE_HEIGHT / 2, _textFont, _text[i], justify);
            if (sub != null) {
                dc.drawText(x, textTop + LINE_HEIGHT * 3 / 2, _textFont, sub, justify);
            }
        }
    }

    //! Index of the slot under (x, y), or -1.
    function hitTest(x as Number, y as Number) as Number {
        for (var i = 0; i < centers.size(); i++) {
            var dx = x - centers[i][0];
            var dy = y - centers[i][1];
            var r = radius + 6;
            if (dx * dx + dy * dy <= r * r) {
                return i;
            }
        }
        return -1;
    }

    //! Complication to open when slot i is tapped.
    function tapTarget(i as Number) as Complications.Id? {
        var types = complicationTypes(Settings.slots[i]);
        if (types.size() == 0) {
            var kind = Settings.slots[i];
            if (kind == Settings.SLOT_DATE) {
                return new Complications.Id(Complications.COMPLICATION_TYPE_CALENDAR_EVENTS);
            } else if (kind == Settings.SLOT_DISTANCE) {
                return new Complications.Id(Complications.COMPLICATION_TYPE_STEPS);
            }
            return null;
        }
        return new Complications.Id(types[0]);
    }

    //! System complications backing a slot kind.
    static function complicationTypes(kind as Number) as Array<Complications.Type> {
        switch (kind) {
            case Settings.SLOT_BATTERY:       return [Complications.COMPLICATION_TYPE_BATTERY];
            case Settings.SLOT_STEPS:         return [Complications.COMPLICATION_TYPE_STEPS];
            case Settings.SLOT_HEART_RATE:    return [Complications.COMPLICATION_TYPE_HEART_RATE];
            case Settings.SLOT_CALORIES:      return [Complications.COMPLICATION_TYPE_CALORIES];
            case Settings.SLOT_BODY_BATTERY:  return [Complications.COMPLICATION_TYPE_BODY_BATTERY];
            case Settings.SLOT_STRESS:        return [Complications.COMPLICATION_TYPE_STRESS];
            case Settings.SLOT_NOTIFICATIONS: return [Complications.COMPLICATION_TYPE_NOTIFICATION_COUNT];
            case Settings.SLOT_FLOORS:        return [Complications.COMPLICATION_TYPE_FLOORS_CLIMBED];
            case Settings.SLOT_WEEKLY_RUN:    return [Complications.COMPLICATION_TYPE_WEEKLY_RUN_DISTANCE];
            case Settings.SLOT_SUN:           return [Complications.COMPLICATION_TYPE_SUNRISE, Complications.COMPLICATION_TYPE_SUNSET];
            case Settings.SLOT_TEMPERATURE:   return [Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE];
            case Settings.SLOT_INTENSITY:     return [Complications.COMPLICATION_TYPE_INTENSITY_MINUTES];
        }
        return [] as Array<Complications.Type>;
    }

    private function format(i as Number) as Void {
        var kind = Settings.slots[i];
        var text = "--";
        var sub = null;
        var progress = null;

        switch (kind) {
            case Settings.SLOT_NONE:
                text = "";
                break;
            case Settings.SLOT_DATE: {
                // "Ott 17" / "Sab" (month and weekday names follow the watch language)
                var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
                text = capitalize(info.month as String) + " " + info.day;
                sub = capitalize(info.day_of_week as String);
                break;
            }
            case Settings.SLOT_BATTERY: {
                var v = rawNumber(Complications.COMPLICATION_TYPE_BATTERY);
                if (v != null) {
                    text = v.format("%d") + "%";
                    progress = v / 100.0;
                }
                break;
            }
            case Settings.SLOT_STEPS: {
                var v = rawNumber(Complications.COMPLICATION_TYPE_STEPS);
                if (v != null) {
                    text = v >= 10000 ? (v / 1000.0).format("%.1f") + "k" : v.format("%d");
                    progress = ratio(v, ActivityMonitor.getInfo().stepGoal);
                }
                break;
            }
            case Settings.SLOT_HEART_RATE:
                text = numberOrDash(Complications.COMPLICATION_TYPE_HEART_RATE);
                break;
            case Settings.SLOT_CALORIES:
                text = numberOrDash(Complications.COMPLICATION_TYPE_CALORIES);
                break;
            case Settings.SLOT_BODY_BATTERY: {
                var v = rawNumber(Complications.COMPLICATION_TYPE_BODY_BATTERY);
                if (v != null) {
                    text = v.format("%d");
                    progress = v / 100.0;
                }
                break;
            }
            case Settings.SLOT_STRESS: {
                var v = rawNumber(Complications.COMPLICATION_TYPE_STRESS);
                if (v != null && v >= 0) {
                    text = v.format("%d");
                    progress = v / 100.0;
                }
                break;
            }
            case Settings.SLOT_NOTIFICATIONS:
                text = numberOrDash(Complications.COMPLICATION_TYPE_NOTIFICATION_COUNT);
                break;
            case Settings.SLOT_FLOORS: {
                var v = rawNumber(Complications.COMPLICATION_TYPE_FLOORS_CLIMBED);
                if (v != null) {
                    text = v.format("%d");
                    progress = ratio(v, ActivityMonitor.getInfo().floorsClimbedGoal);
                }
                break;
            }
            case Settings.SLOT_DISTANCE: {
                var cm = ActivityMonitor.getInfo().distance;
                if (cm != null) {
                    text = formatDistance(cm / 100.0);
                }
                break;
            }
            case Settings.SLOT_WEEKLY_RUN: {
                var m = rawNumber(Complications.COMPLICATION_TYPE_WEEKLY_RUN_DISTANCE);
                if (m != null) {
                    text = formatDistance(m);
                }
                break;
            }
            case Settings.SLOT_SUN:
                text = formatSun();
                break;
            case Settings.SLOT_TEMPERATURE: {
                var c = rawNumber(Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE);
                if (c != null) {
                    if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
                        c = c * 9.0 / 5.0 + 32;
                    }
                    text = Math.round(c).format("%d") + "°";
                }
                break;
            }
            case Settings.SLOT_INTENSITY: {
                var v = rawNumber(Complications.COMPLICATION_TYPE_INTENSITY_MINUTES);
                if (v != null) {
                    text = v.format("%d");
                    progress = ratio(v, ActivityMonitor.getInfo().activeMinutesWeekGoal);
                }
                break;
            }
        }
        // Only flag a redraw if something visible actually changed
        var oldSub = _sub[i];
        var subChanged = (sub == null) ? (oldSub != null) : (oldSub == null || !sub.equals(oldSub));
        if (!text.equals(_text[i]) || subChanged || progress != _progress[i]) {
            _text[i] = text;
            _sub[i] = sub;
            _progress[i] = progress;
            dirty = true;
        }
    }

    private static function capitalize(s as String) as String {
        if (s.length() < 2) {
            return s.toUpper();
        }
        return s.substring(0, 1).toUpper() + s.substring(1, s.length()).toLower();
    }

    private function rawNumber(type as Complications.Type) as Numeric? {
        var v = _raw[type];
        return (v instanceof Number || v instanceof Float || v instanceof Long || v instanceof Double) ? v as Numeric : null;
    }

    private function numberOrDash(type as Complications.Type) as String {
        var v = rawNumber(type);
        return v != null ? v.format("%d") : "--";
    }

    private static function ratio(v as Numeric, goal as Numeric?) as Float? {
        if (goal == null || goal <= 0) {
            return null;
        }
        return v.toFloat() / goal;
    }

    //! Meters to "12.3" km (or mi), one decimal below 100.
    private static function formatDistance(m as Numeric) as String {
        var d = m / 1000.0;
        if (System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE) {
            d = m / 1609.344;
        }
        return d < 100 ? d.format("%.1f") : d.format("%d");
    }

    //! Next sunrise or sunset as a clock time.
    private function formatSun() as String {
        var rise = rawNumber(Complications.COMPLICATION_TYPE_SUNRISE);
        var set = rawNumber(Complications.COMPLICATION_TYPE_SUNSET);
        if (rise == null || set == null) {
            return "--";
        }
        var t = System.getClockTime();
        var now = t.hour * 3600 + t.min * 60;
        var next = ((now >= rise && now < set) ? set : rise).toNumber();
        var h = next / 3600;
        var m = (next % 3600) / 60;
        if (!System.getDeviceSettings().is24Hour) {
            h = h % 12;
            if (h == 0) {
                h = 12;
            }
        }
        return h.format("%d") + ":" + m.format("%02d");
    }
}

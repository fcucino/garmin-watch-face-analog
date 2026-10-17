import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

//! Galaxy Watch-style analog face.
//!
//! Battery strategy (AMOLED, no partial updates). The OS calls onUpdate once
//! a minute, or once a second in high power for a few seconds after a gesture:
//! - The dial, slots and indicators live in one off-screen background that
//!   is redrawn only when something on it visibly changes (slot value,
//!   battery level, sun arc step, settings). On a normal minute it is untouched.
//! - Every onUpdate is one bitmap blit plus the hour/minute hands, plus the
//!   second hand in high power when enabled.
//! - Always-on mode draws a sparse outline face (<10% lit pixels) once per
//!   minute, shifted every minute against burn-in.
class GalaxyAnalogView extends WatchUi.WatchFace {

    // Burn-in protection offsets cycled every minute in always-on mode
    private const AOD_SHIFTS = [[0, 0], [3, 0], [3, 3], [0, 3], [-3, 3], [-3, 0], [-3, -3], [0, -3]] as Array<[Number, Number]>;

    private var _dial as Dial;
    private var _slots as Slots;
    private var _iconFont as FontResource;
    private var _buffer as BufferedBitmap?;
    private var _size as Number = 390;
    private var _c as Number = 195;

    private var _sleeping as Boolean = false;
    private var _burnIn as Boolean = false;
    private var _lastMinute as Number = -1;
    private var _bgDirty as Boolean = true;
    private var _day as Number = -1;
    private var _battery as Number = -1;
    private var _sunStep as Number = -2;
    private var _sunNow as Number = 0;

    function initialize() {
        WatchFace.initialize();
        var settings = System.getDeviceSettings();
        _burnIn = (settings has :requiresBurnInProtection) && settings.requiresBurnInProtection;
        _dial = new Dial();
        _iconFont = WatchUi.loadResource($.Rez.Fonts.Icons) as FontResource;
        _slots = new Slots(_iconFont);
    }

    function onLayout(dc as Dc) as Void {
        _size = dc.getWidth();
        _c = _size / 2;
        _dial.layout(_size);
        _slots.layout(_size);
        _buffer = null;
        try {
            _buffer = Graphics.createBufferedBitmap({:width => _size, :height => _size}).get() as BufferedBitmap;
        } catch (e) {
            // Fall back to drawing straight to the screen
        }
        _bgDirty = true;
    }

    function onShow() as Void {
        _slots.subscribe();
        _lastMinute = -1;
        _bgDirty = true;
    }

    function onHide() as Void {
        _slots.unsubscribe();
    }

    function onSettingsChanged() as Void {
        _slots.subscribe();
        _bgDirty = true;
        WatchUi.requestUpdate();
    }

    function slots() as Slots {
        return _slots;
    }

    function onUpdate(dc as Dc) as Void {
        var t = System.getClockTime();
        dc.clearClip();

        if (_sleeping && _burnIn) {
            drawAod(dc, t);
            return;
        }

        var minute = t.hour * 60 + t.min;
        if (minute != _lastMinute) {
            _lastMinute = minute;
            pollMinute();
        }
        if (_slots.dirty) {
            _bgDirty = true;
        }

        var buffer = _buffer;
        if (buffer != null) {
            if (_bgDirty) {
                renderBackground(buffer.getDc());
            }
            dc.drawBitmap(0, 0, buffer);
        } else {
            renderBackground(dc);
        }

        drawHands(dc, t);
        if (!_sleeping && Settings.showSeconds) {
            drawSecondHand(dc, t.sec);
        }
    }

    function onEnterSleep() as Void {
        _sleeping = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _sleeping = false;
    }

    //! Once-a-minute cheap checks; each marks the background dirty only on a visible change.
    private function pollMinute() as Void {
        var day = Time.today().value();
        var newDay = day != _day;
        if (newDay) {
            _day = day;
        }
        _slots.poll(newDay);

        // Sun arc: redraw only when the dot moves to the next step or day/night flips
        var t = System.getClockTime();
        _sunNow = t.hour * 3600 + t.min * 60;
        var sun = _slots.sunTimes();
        var step = sun != null ? Indicators.sunStep(sun[0], sun[1], _sunNow) : -2;
        if (step != _sunStep) {
            _sunStep = step;
            if (Settings.showSun) {
                _bgDirty = true;
            }
        }

        var battery = (System.getSystemStats().battery + 0.5).toNumber();
        if (battery != _battery) {
            _battery = battery;
            if (Settings.showBattery) {
                _bgDirty = true;
            }
        }
    }

    //! Dial, indicators and slots: everything that does not move every minute.
    private function renderBackground(dc as Dc) as Void {
        _bgDirty = false;
        _slots.dirty = false;

        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        _dial.draw(dc);

        var indicatorOffset = (_size * 0.30).toNumber();
        var sun = _slots.sunTimes();
        if (Settings.showSun && sun != null) {
            Indicators.drawSun(dc, _c, _c - indicatorOffset + 8, (_size * 0.056).toNumber(), sun[0], sun[1], _sunNow, _slots.textFont());
        }
        if (Settings.showBattery) {
            Indicators.drawBattery(dc, _c, _c + indicatorOffset, _battery, _iconFont, _slots.textFont());
        }

        _slots.draw(dc);
    }

    //! Hour and minute hands plus the center hub, drawn on top of the background.
    private function drawHands(dc as Dc, t as System.ClockTime) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        var hourAngle = ((t.hour % 12) * 60 + t.min) * Math.PI / 360.0;
        var minuteAngle = t.min * Math.PI / 30.0;
        drawHand(dc, hourAngle, _size * 0.27, _size * 0.035, 16, 10);
        drawHand(dc, minuteAngle, _size * 0.42, _size * 0.035, 12, 7);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_c, _c, 8);
        dc.setColor(Settings.accent(), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_c, _c, 4);
    }

    //! Solid tapered white hand with a thin black outline so it reads over slots.
    private function drawHand(dc as Dc, angle as Float, length as Float, tail as Float, wBase as Number, wTip as Number) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(handPolygon(_c, _c, angle, length + 2, tail + 2, wBase + 4, wTip + 4));
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(handPolygon(_c, _c, angle, length, tail, wBase, wTip));
    }

    private function drawSecondHand(dc as Dc, sec as Number) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        var angle = sec * Math.PI / 30.0;
        dc.setColor(Settings.accent(), Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(handPolygon(_c, _c, angle, _size * 0.46, _size * 0.09, 4, 3));
        dc.fillCircle(_c, _c, 6);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_c, _c, 2);
    }

    //! Sparse always-on face: outline numerals and outline hands.
    private function drawAod(dc as Dc, t as System.ClockTime) as Void {
        var shift = AOD_SHIFTS[t.min % AOD_SHIFTS.size()];
        var dx = shift[0];
        var dy = shift[1];

        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        _dial.drawAod(dc, dx, dy);

        var cx = _c + dx;
        var cy = _c + dy;
        var hourAngle = ((t.hour % 12) * 60 + t.min) * Math.PI / 360.0;
        var minuteAngle = t.min * Math.PI / 30.0;
        dc.setPenWidth(2);
        dc.setColor(0xB4B4B4, Graphics.COLOR_TRANSPARENT);
        outline(dc, handPolygon(cx, cy, hourAngle, _size * 0.27, _size * 0.035, 16, 10));
        outline(dc, handPolygon(cx, cy, minuteAngle, _size * 0.42, _size * 0.035, 12, 7));
        dc.drawCircle(cx, cy, 8);
    }

    private function outline(dc as Dc, pts as Array<[Float, Float]>) as Void {
        var n = pts.size();
        for (var i = 0; i < n; i++) {
            var a = pts[i];
            var b = pts[(i + 1) % n];
            dc.drawLine(a[0], a[1], b[0], b[1]);
        }
    }

    //! Quad for a hand pointing at `angle` (radians, clockwise from 12),
    //! tapering from wBase at the tail to wTip at the tip.
    private static function handPolygon(cx as Number, cy as Number, angle as Float, length as Float, tail as Float, wBase as Number, wTip as Number) as Array<[Float, Float]> {
        var s = Math.sin(angle);
        var co = Math.cos(angle);
        var hb = wBase / 2.0;
        var ht = wTip / 2.0;
        var local = [[-hb, -tail], [-ht, length], [ht, length], [hb, -tail]];
        var pts = new Array<[Float, Float]>[4];
        for (var i = 0; i < 4; i++) {
            var x = local[i][0];
            var y = local[i][1];
            pts[i] = [cx + x * co + y * s, cy + x * s - y * co];
        }
        return pts;
    }
}

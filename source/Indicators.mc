import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

//! Fixed indicators: battery at 6 o'clock and moon phase at 12 o'clock.
module Indicators {

    const SYNODIC_MONTH = 29.530588853d;
    // Reference new moon: 2000-01-06 18:14 UTC
    const NEW_MOON_EPOCH = 947182440;

    const MOON_LIT = 0xE6E6E6;
    const MOON_DARK = 0x2E2E2E;

    //! Moon age as a fraction of the synodic month: 0 = new, 0.5 = full.
    function moonPhase(unixSeconds as Number) as Float {
        var days = (unixSeconds - NEW_MOON_EPOCH) / 86400.0d;
        var cycles = days / SYNODIC_MONTH;
        var p = cycles - Math.floor(cycles);
        return p.toFloat();
    }

    //! Draw the moon disc centered at (x, y) with radius r.
    function drawMoon(dc as Dc, x as Number, y as Number, r as Number, phase as Float) as Void {
        dc.setColor(MOON_DARK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);

        // Lit half: right side while waxing, left side while waning
        dc.setColor(MOON_LIT, Graphics.COLOR_TRANSPARENT);
        if (phase < 0.5) {
            dc.setClip(x, y - r - 1, r + 2, 2 * r + 3);
        } else {
            dc.setClip(x - r - 1, y - r - 1, r + 1, 2 * r + 3);
        }
        dc.fillCircle(x, y, r);
        dc.clearClip();

        // Terminator: an ellipse that hides (crescent) or extends (gibbous) the lit half
        var k = Math.cos(2 * Math.PI * phase);
        var rx = (r * k.abs()).toNumber();
        if (rx > 0) {
            dc.setColor(k > 0 ? MOON_DARK : MOON_LIT, Graphics.COLOR_TRANSPARENT);
            dc.fillEllipse(x, y, rx, r);
        }
    }

    //! Draw a lightning icon followed by the battery level (no % sign), centered on (x, y).
    function drawBattery(dc as Dc, x as Number, y as Number, pct as Number, iconFont as WatchUi.FontResource, textFont as WatchUi.FontResource) as Void {
        var text = pct.format("%d");
        var iconW = 20; // visible width of the bolt glyph in its 26 px cell
        var gap = 2;
        var w = iconW + gap + dc.getTextWidthInPixels(text, textFont);
        var left = x - w / 2;
        var justify = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(pct < 15 ? 0xFF3B30 : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + iconW / 2, y, iconFont, "n", justify);
        dc.drawText(left + iconW + gap, y, textFont, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

//! Fixed indicators: battery at 6 o'clock and the sun arc at 12 o'clock.
module Indicators {

    // Quantization of the sun position: the arc is redrawn at most this many times per day
    const SUN_STEPS = 36;

    const SUN_COLOR = 0xFFC400;

    //! Discrete sun state used to decide when the background needs a redraw:
    //! -1 at night, 0..SUN_STEPS along the arc during the day.
    function sunStep(rise as Number, set as Number, now as Number) as Number {
        if (now < rise || now >= set || set <= rise) {
            return -1;
        }
        return (now - rise) * SUN_STEPS / (set - rise);
    }

    //! Sun arc over a horizon, centered on the horizon point (x, y):
    //! the dot travels the half-circle from sunrise (left) to sunset (right);
    //! the next event time is printed below with an up/down arrow.
    function drawSun(dc as Dc, x as Number, y as Number, r as Number, rise as Number, set as Number, now as Number, textFont as WatchUi.FontResource) as Void {
        var step = sunStep(rise, set, now);
        var day = step >= 0;

        dc.setPenWidth(2);
        dc.setColor(day ? 0x8C8C8C : 0x3A3A3A, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(x, y, r, Graphics.ARC_COUNTER_CLOCKWISE, 0, 180);
        dc.setColor(0x8C8C8C, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x - r - 8, y, x + r + 9, y);

        if (day) {
            var a = Math.PI * (1.0 - step.toFloat() / SUN_STEPS);
            dc.setColor(SUN_COLOR, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + r * Math.cos(a), y - r * Math.sin(a), 4);
        } else {
            // Below the horizon: a dim dot resting on the line
            dc.setColor(0x5A5A5A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, 3);
        }

        // Next event: sunset while the sun is up, otherwise sunrise
        var text = Slots.formatClock(day ? set : rise);
        var arrowW = 8;
        var gap = 3;
        var w = arrowW + gap + dc.getTextWidthInPixels(text, textFont);
        var left = x - w / 2;
        var ty = y + 15;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        if (day) {
            dc.fillPolygon([[left, ty - 3], [left + arrowW, ty - 3], [left + arrowW / 2, ty + 4]]);
        } else {
            dc.fillPolygon([[left, ty + 3], [left + arrowW, ty + 3], [left + arrowW / 2, ty - 4]]);
        }
        dc.drawText(left + arrowW + gap, ty, textFont, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
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

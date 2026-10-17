import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

//! Static dial: minute tick ring and the 12 hour numerals.
//! All geometry is precomputed in layout() so drawing is just blits/lines.
class Dial {

    private var _ticks as Array<[Number, Number, Number, Number]> = [] as Array<[Number, Number, Number, Number]>;
    private var _numerals as Array<[Number, Number]> = [] as Array<[Number, Number]>;
    private var _font as FontResource;
    private var _aodFont as FontResource;

    function initialize() {
        _font = WatchUi.loadResource($.Rez.Fonts.Numerals) as FontResource;
        _aodFont = WatchUi.loadResource($.Rez.Fonts.NumeralsAod) as FontResource;
    }

    function layout(size as Number) as Void {
        var c = size / 2.0;
        var outer = c - 1;
        _ticks = [] as Array<[Number, Number, Number, Number]>;
        for (var i = 0; i < 60; i++) {
            var a = i * Math.PI / 30.0;
            var inner = outer - ((i % 5 == 0) ? 14 : 7);
            var s = Math.sin(a);
            var co = Math.cos(a);
            _ticks.add([(c + inner * s).toNumber(), (c - inner * co).toNumber(),
                        (c + outer * s).toNumber(), (c - outer * co).toNumber()]);
        }

        var r = size * 0.402; // numeral ring, with clearance from the hour ticks
        _numerals = [] as Array<[Number, Number]>;
        for (var h = 1; h <= 12; h++) {
            var a = h * Math.PI / 6.0;
            _numerals.add([(c + r * Math.sin(a)).toNumber(), (c - r * Math.cos(a)).toNumber()]);
        }
    }

    //! Full dial for the active (high/low power, no burn-in) face.
    function draw(dc as Dc) as Void {
        for (var i = 0; i < 60; i++) {
            var t = _ticks[i];
            if (i % 5 == 0) {
                dc.setPenWidth(3);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setPenWidth(2);
                dc.setColor(0x6E6E6E, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawLine(t[0], t[1], t[2], t[3]);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawNumerals(dc, _font, 0, 0);
    }

    //! Sparse outline numerals for always-on mode, shifted by (dx, dy).
    function drawAod(dc as Dc, dx as Number, dy as Number) as Void {
        dc.setColor(0x8C8C8C, Graphics.COLOR_TRANSPARENT);
        drawNumerals(dc, _aodFont, dx, dy);
    }

    private function drawNumerals(dc as Dc, font as FontResource, dx as Number, dy as Number) as Void {
        for (var h = 1; h <= 12; h++) {
            var p = _numerals[h - 1];
            dc.drawText(p[0] + dx, p[1] + dy, font, h.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}

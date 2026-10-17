import Toybox.Complications;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Watch face input: tapping a slot opens the matching Garmin widget.
class FaceDelegate extends WatchUi.WatchFaceDelegate {

    private var _view as GalaxyAnalogView;

    function initialize(view as GalaxyAnalogView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    function onPress(event as WatchUi.ClickEvent) as Boolean {
        var xy = event.getCoordinates();
        var slots = _view.slots();
        var i = slots.hitTest(xy[0], xy[1]);
        if (i < 0) {
            return false;
        }
        var target = slots.tapTarget(i);
        if (target == null) {
            return false;
        }
        try {
            Complications.exitTo(target);
        } catch (e) {
            return false;
        }
        return true;
    }

    function onPowerBudgetExceeded(powerInfo as WatchUi.WatchFacePowerInfo) as Void {
        System.println("Power budget exceeded: avg " + powerInfo.executionTimeAverage + " limit " + powerInfo.executionTimeLimit);
    }
}

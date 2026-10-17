import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class GalaxyAnalogApp extends Application.AppBase {

    private var _view as GalaxyAnalogView?;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        Settings.load();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new GalaxyAnalogView();
        _view = view;
        return [view, new FaceDelegate(view)];
    }

    //! Settings changed from the phone app (or the on-device menu).
    function onSettingsChanged() as Void {
        Settings.load();
        var view = _view;
        if (view != null) {
            view.onSettingsChanged();
        }
        WatchUi.requestUpdate();
    }

    //! On-device settings (watch face "Customize" menu).
    function getSettingsView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] or Null {
        return [new SettingsMenu(), new SettingsMenuDelegate()];
    }
}

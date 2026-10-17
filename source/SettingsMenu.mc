import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.WatchUi;

//! Resource ids for the list settings, indexed by property value.
module SettingsStrings {

    function slotTitles() as Array<ResourceId> {
        return [Rez.Strings.Slot1Title, Rez.Strings.Slot2Title, Rez.Strings.Slot3Title, Rez.Strings.Slot4Title];
    }

    function slotNames() as Array<ResourceId> {
        return [
            Rez.Strings.SlotNone, Rez.Strings.SlotDate, Rez.Strings.SlotBattery, Rez.Strings.SlotSteps,
            Rez.Strings.SlotHeartRate, Rez.Strings.SlotCalories, Rez.Strings.SlotBodyBattery, Rez.Strings.SlotStress,
            Rez.Strings.SlotNotifications, Rez.Strings.SlotFloors, Rez.Strings.SlotDistance, Rez.Strings.SlotWeeklyRun,
            Rez.Strings.SlotSun, Rez.Strings.SlotTemperature, Rez.Strings.SlotIntensityMin
        ];
    }

    function colorNames() as Array<ResourceId> {
        return [
            Rez.Strings.ColorRed, Rez.Strings.ColorOrange, Rez.Strings.ColorYellow, Rez.Strings.ColorGreen,
            Rez.Strings.ColorCyan, Rez.Strings.ColorBlue, Rez.Strings.ColorPurple, Rez.Strings.ColorPink,
            Rez.Strings.ColorWhite
        ];
    }

    function load(id as ResourceId) as String {
        return WatchUi.loadResource(id) as String;
    }

    //! Persist and apply settings changed from the watch.
    function apply() as Void {
        (Application.getApp() as GalaxyAnalogApp).onSettingsChanged();
    }
}

//! On-device settings menu, editing the same properties as the phone app.
class SettingsMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({:title => Rez.Strings.SettingsTitle});
        Settings.load();

        var titles = SettingsStrings.slotTitles();
        var names = SettingsStrings.slotNames();
        for (var i = 0; i < 4; i++) {
            addItem(new WatchUi.MenuItem(SettingsStrings.load(titles[i]), SettingsStrings.load(names[Settings.slots[i]]), "Slot" + (i + 1), null));
        }
        addItem(new WatchUi.ToggleMenuItem(SettingsStrings.load(Rez.Strings.ShowSecondsTitle), null, "ShowSeconds", Settings.showSeconds, null));
        addItem(new WatchUi.MenuItem(SettingsStrings.load(Rez.Strings.AccentColorTitle),
            SettingsStrings.load(SettingsStrings.colorNames()[Settings.accentIndex]), "AccentColor", null));
        addItem(new WatchUi.ToggleMenuItem(SettingsStrings.load(Rez.Strings.ShowArcsTitle), null, "ShowArcs", Settings.showArcs, null));
        addItem(new WatchUi.ToggleMenuItem(SettingsStrings.load(Rez.Strings.ShowBatteryTitle), null, "ShowBattery", Settings.showBattery, null));
        addItem(new WatchUi.ToggleMenuItem(SettingsStrings.load(Rez.Strings.ShowMoonTitle), null, "ShowMoon", Settings.showMoon, null));
    }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var key = item.getId() as String;
        if (item instanceof WatchUi.ToggleMenuItem) {
            Properties.setValue(key, item.isEnabled());
            SettingsStrings.apply();
            return;
        }
        var names = key.equals("AccentColor") ? SettingsStrings.colorNames() : SettingsStrings.slotNames();
        var menu = new WatchUi.Menu2({:title => item.getLabel()});
        for (var v = 0; v < names.size(); v++) {
            menu.addItem(new WatchUi.MenuItem(SettingsStrings.load(names[v]), null, v, null));
        }
        menu.setFocus(Settings.readNumber(key, 0));
        WatchUi.pushView(menu, new ChoiceMenuDelegate(key, item, names), WatchUi.SLIDE_LEFT);
    }
}

//! Picks one value of a list setting and writes it back.
class ChoiceMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _key as String;
    private var _parent as WatchUi.MenuItem;
    private var _names as Array<ResourceId>;

    function initialize(key as String, parent as WatchUi.MenuItem, names as Array<ResourceId>) {
        Menu2InputDelegate.initialize();
        _key = key;
        _parent = parent;
        _names = names;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var value = item.getId() as Number;
        Properties.setValue(_key, value);
        _parent.setSubLabel(SettingsStrings.load(_names[value]));
        SettingsStrings.apply();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

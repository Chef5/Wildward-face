import Toybox.Lang;
import Toybox.WatchUi;

// 表盘长按：根据触摸坐标跳转至对应指标的系统 Widget / Glance。
// onPowerBudgetExceeded：1Hz 局部刷新超预算时由系统回调，暂停 onPartialUpdate。
class ChefWatchFaceDelegate extends WatchUi.WatchFaceDelegate {

    private var _view as ChefWatchFaceView;

    function initialize(view as ChefWatchFaceView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    function onPress(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        if (coords == null || coords.size() < 2) {
            return false;
        }
        return _view.handleMetricLongPress(coords[0] as Number, coords[1] as Number);
    }

    function onPowerBudgetExceeded(powerInfo as WatchFacePowerInfo) as Void {
        _view.disablePartialUpdates();
    }

}

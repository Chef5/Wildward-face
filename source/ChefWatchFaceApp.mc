import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class ChefWatchFaceApp extends Application.AppBase {

    private var _view as ChefWatchFaceView?;

    function initialize() {
        AppBase.initialize();
    }

    // onStart() 在应用启动时调用
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() 在应用退出时调用
    function onStop(state as Dictionary?) as Void {
    }

    // 在此返回应用的初始界面
    function getInitialView() as [Views] or [Views, InputDelegates] {
        _view = new ChefWatchFaceView();
        return [ _view, new ChefWatchFaceDelegate(_view) ];
    }

    // 收到新的应用设置后触发界面刷新（须在 AppBase 中实现，不能放在 View）
    function onSettingsChanged() as Void {
        if (_view != null) {
            _view.loadSettings();
            WatchUi.requestUpdate();
        }
    }

}

function getApp() as ChefWatchFaceApp {
    return Application.getApp() as ChefWatchFaceApp;
}
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class Background extends WatchUi.Drawable {

    function initialize() {
        Drawable.initialize({ :identifier => "Background" });
    }

    function draw(dc as Dc) as Void {
        var bg = 0x000000;
        var v = Application.Properties.getValue("BackgroundColor");
        if (v != null) { bg = v as Number; }
        dc.setColor(Graphics.COLOR_TRANSPARENT, bg);
        dc.clear();
    }
}

package pe.edu.upc.gestuvoz

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gestuvoz/pantalla")
            .setMethodCallHandler { call, result ->
                if (call.method == "rotacion") {
                    @Suppress("DEPRECATION")
                    result.success(windowManager.defaultDisplay.rotation * 90)
                } else {
                    result.notImplemented()
                }
            }
    }
}

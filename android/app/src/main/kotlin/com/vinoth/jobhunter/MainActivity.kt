package com.vinoth.jobhunter

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // Android Q (API 29) introduced an automatic contrast scrim over the
    // status / navigation bars. From Android 15 (API 35) edge-to-edge is
    // enforced and the scrim defaults to ON, which paints a black band
    // over our gradient header even though we set statusBarColor =
    // transparent on the Flutter side. Disable it here so the gradient
    // shows through edge-to-edge. Flutter exposes the same flags via
    // SystemUiOverlayStyle.systemStatusBarContrastEnforced, but those
    // don't always survive an AppBar overlay style change — overriding
    // at the window level is authoritative.
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }
    }
}

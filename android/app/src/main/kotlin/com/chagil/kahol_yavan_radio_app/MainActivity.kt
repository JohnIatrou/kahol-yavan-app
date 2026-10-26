package com.chagil.kahol_yavan_radio_app

import android.content.pm.PackageManager
import android.os.Bundle
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // On a TV the player is the screen: keep it on instead of letting the screensaver take over.
        if (packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }
}

package com.haven.uaq

import android.os.Bundle
import android.view.View
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        findViewById<View>(android.R.id.content)?.isHapticFeedbackEnabled = true
    }
}

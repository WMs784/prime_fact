package com.example.prime_fact

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Android 14 以前でも Android 15 以降と同じエッジ ツー エッジ表示にする
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}

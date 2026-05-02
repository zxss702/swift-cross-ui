package dev.swiftcrossui.androidbackend

import android.view.WindowInsets
import android.app.Activity
import android.os.Handler
import android.os.Looper

class AndroidBackendHelpers {
    fun getWindowWidth(activity: Activity): Int {
        val windowMetrics = activity.getWindowManager().getCurrentWindowMetrics()
        val insets = windowMetrics.getWindowInsets()
                .getInsetsIgnoringVisibility(WindowInsets.Type.systemBars())
        return windowMetrics.getBounds().width() - insets.left - insets.right
    }

    fun getWindowHeight(activity: Activity): Int {
        val windowMetrics = activity.getWindowManager().getCurrentWindowMetrics()
        val insets = windowMetrics.getWindowInsets()
                .getInsetsIgnoringVisibility(WindowInsets.Type.systemBars())
        return windowMetrics.getBounds().height() - insets.top - insets.bottom
    }

    fun getPreferredFramesPerSecond(activity: Activity): Float {
        val refreshRate = activity.getWindowManager().getDefaultDisplay().getRefreshRate()
        return if (refreshRate > 0.0f) refreshRate else 60.0f
    }

    fun runOnMainThread(action: SwiftAction) {
        Handler(Looper.getMainLooper()).post {
            action.call()
        }
    }
}

package dev.swiftcrossui.androidbackend

import android.view.WindowInsets
import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.text.Layout
import android.text.StaticLayout
import android.widget.TextView
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.roundToInt

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

    fun getSafeAreaLeftInset(activity: Activity): Int {
        val windowMetrics = activity.getWindowManager().getCurrentWindowMetrics()
        val insets = windowMetrics.getWindowInsets()
                .getInsetsIgnoringVisibility(WindowInsets.Type.systemBars())
        return insets.left
    }

    fun getSafeAreaTopInset(activity: Activity): Int {
        val windowMetrics = activity.getWindowManager().getCurrentWindowMetrics()
        val insets = windowMetrics.getWindowInsets()
                .getInsetsIgnoringVisibility(WindowInsets.Type.systemBars())
        return insets.top
    }
}

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

    fun getPreferredFramesPerSecond(activity: Activity): Float {
        val refreshRate = activity.getWindowManager().getDefaultDisplay().getRefreshRate()
        return if (refreshRate > 0.0f) refreshRate else 60.0f
    }

    fun runOnMainThread(action: SwiftAction) {
        Handler(Looper.getMainLooper()).post {
            action.call()
        }
    }

    fun textLayoutFragmentMetrics(textView: TextView, text: String, proposedWidth: Int): IntArray {
        if (text.isEmpty()) {
            return IntArray(0)
        }

        val width = if (proposedWidth > 0) {
            proposedWidth
        } else {
            max(1, ceil(textView.paint.measureText(text)).toInt())
        }
        val layout = StaticLayout.Builder.obtain(text, 0, text.length, textView.paint, width)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setIncludePad(textView.includeFontPadding)
            .setLineSpacing(textView.lineSpacingExtra, textView.lineSpacingMultiplier)
            .setMaxLines(textView.maxLines)
            .setEllipsize(textView.ellipsize)
            .build()

        val values = IntArray((text.length + 1) * 6)
        for (offset in 0..text.length) {
            val line = layout.getLineForOffset(offset.coerceAtMost(text.length))
            val base = offset * 6
            values[base] = layout.getPrimaryHorizontal(offset.coerceAtMost(text.length)).roundToInt()
            values[base + 1] = layout.getLineTop(line)
            values[base + 2] = layout.getLineBaseline(line)
            values[base + 3] = layout.getLineBottom(line)
            values[base + 4] = line
            values[base + 5] = layout.getLineRight(line).roundToInt()
        }
        return values
    }
}

package com.snapstraight.app

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PointF
import android.graphics.RectF
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import android.widget.ImageView
import org.opencv.core.Point

/**
 * 四边形可拖拽覆盖层（与iOS交互一致）
 * - 在图片显示区域之上绘制四个可拖拽的圆点与连线
 * - 坐标转换遵循与iOS一致的归一化约定（0..1，左下为原点）
 */
class QuadOverlayView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : View(context, attrs) {

    private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = 0xFFFFC107.toInt() // system yellow
        strokeWidth = 6f
    }
    private val handlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = 0xFFFFC107.toInt()
    }
    private val handleBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = 0x99000000.toInt()
        strokeWidth = 4f
    }

    private val handleRadius = 20f

    private var imageRect = RectF(0f, 0f, 0f, 0f)
    private var points: MutableList<PointF> = mutableListOf()

    private var activeHandleIndex: Int = -1

    /**
     * 根据ImageView的显示区域配置覆盖层与初始四边形
     */
    fun configure(imageView: ImageView, initialQuad: ImageProcessor.NormalizedQuad?) {
        imageRect = computeImageDisplayRect(imageView)

        // 默认矩形：图片内边距 10%
        val defaultQuad = ImageProcessor.NormalizedQuad(
            Point(0.1, 0.9),
            Point(0.9, 0.9),
            Point(0.9, 0.1),
            Point(0.1, 0.1)
        )
        val quad = initialQuad ?: defaultQuad

        points = mutableListOf(
            toViewPoint(quad.topLeft),
            toViewPoint(quad.topRight),
            toViewPoint(quad.bottomRight),
            toViewPoint(quad.bottomLeft)
        )
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (points.size != 4) return

        // 绘制四边形连线
        for (i in 0..3) {
            val p1 = points[i]
            val p2 = points[(i + 1) % 4]
            canvas.drawLine(p1.x, p1.y, p2.x, p2.y, strokePaint)
        }

        // 绘制四个拖拽圆点
        points.forEach { p ->
            canvas.drawCircle(p.x, p.y, handleRadius, handlePaint)
            canvas.drawCircle(p.x, p.y, handleRadius, handleBorderPaint)
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                activeHandleIndex = findHandleAt(event.x, event.y)
                return activeHandleIndex != -1
            }
            MotionEvent.ACTION_MOVE -> {
                if (activeHandleIndex != -1) {
                    val nx = event.x.coerceIn(imageRect.left, imageRect.right)
                    val ny = event.y.coerceIn(imageRect.top, imageRect.bottom)
                    points[activeHandleIndex].set(nx, ny)
                    invalidate()
                    return true
                }
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                activeHandleIndex = -1
            }
        }
        return super.onTouchEvent(event)
    }

    private fun findHandleAt(x: Float, y: Float): Int {
        for (i in points.indices) {
            val p = points[i]
            val dx = x - p.x
            val dy = y - p.y
            if (dx * dx + dy * dy <= handleRadius * handleRadius * 4) {
                return i
            }
        }
        return -1
    }

    /**
     * 将归一化坐标（左下原点）转换到View坐标（左上原点）
     */
    private fun toViewPoint(norm: Point): PointF {
        val vx = imageRect.left + (norm.x * imageRect.width())
        val vy = imageRect.top + ((1.0 - norm.y) * imageRect.height())
        return PointF(vx.toFloat(), vy.toFloat())
    }

    /**
     * 将View坐标转换为归一化坐标（左下原点）
     */
    private fun toNormalized(p: PointF): Point {
        val nx = ((p.x - imageRect.left) / imageRect.width()).toDouble().coerceIn(0.0, 1.0)
        val nyTopOrigin = ((p.y - imageRect.top) / imageRect.height()).toDouble().coerceIn(0.0, 1.0)
        val ny = 1.0 - nyTopOrigin
        return Point(nx, ny)
    }

    /**
     * 读取当前四边形（归一化坐标）
     */
    fun currentNormalizedQuad(): ImageProcessor.NormalizedQuad? {
        if (points.size != 4) return null
        return ImageProcessor.NormalizedQuad(
            toNormalized(points[0]),
            toNormalized(points[1]),
            toNormalized(points[2]),
            toNormalized(points[3])
        )
    }

    /**
     * 计算ImageView在FIT_CENTER下的实际图片显示区域
     */
    private fun computeImageDisplayRect(imageView: ImageView): RectF {
        val d = imageView.drawable ?: return RectF(
            imageView.left.toFloat(), imageView.top.toFloat(),
            imageView.right.toFloat(), imageView.bottom.toFloat()
        )
        val vw = imageView.width.toFloat()
        val vh = imageView.height.toFloat()
        val iw = d.intrinsicWidth.toFloat()
        val ih = d.intrinsicHeight.toFloat()
        if (vw <= 0f || vh <= 0f || iw <= 0f || ih <= 0f) {
            return RectF(0f, 0f, vw, vh)
        }
        val scale = minOf(vw / iw, vh / ih)
        val dw = iw * scale
        val dh = ih * scale
        val left = (vw - dw) * 0.5f
        val top = (vh - dh) * 0.5f
        return RectF(left, top, left + dw, top + dh)
    }
}

package com.snapstraight.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.opencv.android.Utils
import org.opencv.core.*
import org.opencv.imgproc.Imgproc
import java.io.File
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * 图像处理核心类
 * 实现边缘检测、透视矫正、自动裁剪、亮度优化等功能
 */
object ImageProcessor {

    init {
        // 加载OpenCV库
        System.loadLibrary("opencv_java4")
    }

    /**
     * 归一化四边形（与iOS一致：坐标范围0..1，原点位于左下）
     */
    data class NormalizedQuad(
        val topLeft: Point,
        val topRight: Point,
        val bottomRight: Point,
        val bottomLeft: Point
    )

    /**
     * 处理图片（从Uri）
     */
    suspend fun processImage(
        context: Context,
        uri: Uri,
        onComplete: (Bitmap) -> Unit
    ) {
        withContext(Dispatchers.IO) {
            try {
                val inputStream = context.contentResolver.openInputStream(uri)
                val bitmap = BitmapFactory.decodeStream(inputStream)
                inputStream?.close()

                val processed = processImageInternal(bitmap)
                withContext(Dispatchers.Main) {
                    onComplete(processed)
                }
            } catch (e: Exception) {
                e.printStackTrace()
                withContext(Dispatchers.Main) {
                    onComplete(Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888))
                }
            }
        }
    }

    /**
     * 处理图片（从File）
     */
    fun processImage(
        context: Context,
        file: File,
        onComplete: (Bitmap) -> Unit
    ) {
        Thread {
            try {
                val bitmap = BitmapFactory.decodeFile(file.absolutePath)
                val processed = processImageInternal(bitmap)
                android.os.Handler(context.mainLooper).post {
                    onComplete(processed)
                }
            } catch (e: Exception) {
                e.printStackTrace()
                android.os.Handler(context.mainLooper).post {
                    onComplete(Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888))
                }
            }
        }.start()
    }

    /**
     * 图像处理主流程
     * 1. 边缘检测
     * 2. 透视变换矫正
     * 3. 自动裁剪
     * 4. 亮度优化
     */
    private fun processImageInternal(bitmap: Bitmap): Bitmap {
        // 转换为OpenCV Mat
        val src = Mat()
        Utils.bitmapToMat(bitmap, src)

        // 1. 预处理：调整大小以提高处理速度
        val processed = Mat()
        val scale = 800.0 / maxOf(src.width(), src.height())
        if (scale < 1.0) {
            Imgproc.resize(src, processed, Size(), scale, scale, Imgproc.INTER_AREA)
        } else {
            src.copyTo(processed)
        }

        // 2. 边缘检测
        val corners = detectEdges(processed)

        // 3. 透视变换矫正
        val warped = if (corners != null && corners.size == 4) {
            perspectiveTransform(processed, corners)
        } else {
            // 如果检测失败，返回原图并自动提亮
            processed
        }

        // 4. 自动提亮优化
        val enhanced = autoEnhance(warped)

        // 5. 如果之前缩小了图片，现在需要对原图应用相同的变换
        val finalResult = if (scale < 1.0 && corners != null && corners.size == 4) {
            // 将角点坐标还原到原始尺寸
            val originalCorners = corners.map {
                Point(it.x / scale, it.y / scale)
            }
            val warpedOriginal = perspectiveTransform(src, originalCorners)
            autoEnhance(warpedOriginal)
        } else {
            enhanced
        }

        // 转换回Bitmap
        val resultBitmap = Bitmap.createBitmap(
            finalResult.width(),
            finalResult.height(),
            Bitmap.Config.ARGB_8888
        )
        Utils.matToBitmap(finalResult, resultBitmap)

        // 释放资源
        src.release()
        processed.release()
        warped.release()
        enhanced.release()
        if (finalResult != enhanced) finalResult.release()

        return resultBitmap
    }

    /**
     * 从Bitmap检测文档四边形，返回归一化坐标系（0..1，左下为原点）
     */
    fun detectQuad(bitmap: Bitmap): NormalizedQuad? {
        val src = Mat()
        Utils.bitmapToMat(bitmap, src)

        // 统一缩放以提高稳定性与速度
        val processed = Mat()
        val scale = 1000.0 / maxOf(src.width(), src.height())
        if (scale < 1.0) {
            Imgproc.resize(src, processed, Size(), scale, scale, Imgproc.INTER_AREA)
        } else {
            src.copyTo(processed)
        }

        val corners = detectEdges(processed)

        // 将角点转换到原始尺寸，并归一化（注意Android图像坐标y向下，需要翻转为左下原点）
        val quad = corners?.map { p ->
            val px = p.x / (processed.width())
            val py = p.y / (processed.height())
            // 归一化到0..1，翻转y
            Point(px, 1.0 - py)
        }

        src.release(); processed.release()

        return if (quad != null && quad.size == 4) {
            NormalizedQuad(quad[0], quad[1], quad[2], quad[3])
        } else null
    }

    /**
     * 使用用户指定的归一化四边形进行透视矫正与增强
     */
    fun processImageWithQuad(bitmap: Bitmap, quad: NormalizedQuad): Bitmap {
        val src = Mat()
        Utils.bitmapToMat(bitmap, src)

        // 将归一化坐标映射到图像像素坐标（Android图像原点在左上，故需要再翻回）
        val tl = Point(quad.topLeft.x * src.width(), (1.0 - quad.topLeft.y) * src.height())
        val tr = Point(quad.topRight.x * src.width(), (1.0 - quad.topRight.y) * src.height())
        val br = Point(quad.bottomRight.x * src.width(), (1.0 - quad.bottomRight.y) * src.height())
        val bl = Point(quad.bottomLeft.x * src.width(), (1.0 - quad.bottomLeft.y) * src.height())

        val warped = perspectiveTransform(src, listOf(tl, tr, br, bl))
        val enhanced = autoEnhance(warped)

        val resultBitmap = Bitmap.createBitmap(
            enhanced.width(), enhanced.height(), Bitmap.Config.ARGB_8888
        )
        Utils.matToBitmap(enhanced, resultBitmap)

        src.release(); warped.release(); enhanced.release()
        return resultBitmap
    }

    /**
     * 边缘检测，找到文档的四个角点
     */
    private fun detectEdges(src: Mat): List<Point>? {
        val gray = Mat()
        val blurred = Mat()
        val edges = Mat()

        // 转灰度
        Imgproc.cvtColor(src, gray, Imgproc.COLOR_BGR2GRAY)

        // 高斯模糊
        Imgproc.GaussianBlur(gray, blurred, Size(5.0, 5.0), 0.0)

        // Canny边缘检测
        Imgproc.Canny(blurred, edges, 75.0, 200.0)

        // 查找轮廓
        val contours = ArrayList<MatOfPoint>()
        val hierarchy = Mat()
        Imgproc.findContours(
            edges,
            contours,
            hierarchy,
            Imgproc.RETR_LIST,
            Imgproc.CHAIN_APPROX_SIMPLE
        )

        // 找到最大的矩形轮廓
        var maxArea = 0.0
        var maxContour: MatOfPoint? = null

        for (contour in contours) {
            val area = Imgproc.contourArea(contour)
            if (area > maxArea) {
                val peri = Imgproc.arcLength(MatOfPoint2f(*contour.toArray()), true)
                val approx = MatOfPoint2f()
                Imgproc.approxPolyDP(
                    MatOfPoint2f(*contour.toArray()),
                    approx,
                    0.02 * peri,
                    true
                )

                // 如果是四边形且面积足够大
                if (approx.total() == 4L && area > src.width() * src.height() * 0.1) {
                    maxArea = area
                    maxContour = MatOfPoint(*approx.toArray())
                }
            }
        }

        // 释放资源
        gray.release()
        blurred.release()
        edges.release()
        hierarchy.release()

        // 返回四个角点
        return maxContour?.let {
            val points = it.toArray().toList()
            orderPoints(points)
        }
    }

    /**
     * 对四个角点排序：左上、右上、右下、左下
     */
    private fun orderPoints(points: List<Point>): List<Point> {
        // 更稳健的角点排序：按x+y找到左上与右下，剩余两点根据x比较确定右上与左下
        val sorted = points.sortedBy { it.x + it.y }
        val topLeft = sorted.first()
        val bottomRight = sorted.last()

        val remaining = points.filter { it != topLeft && it != bottomRight }
        val (p1, p2) = remaining
        val topRight = if (p1.x > p2.x) p1 else p2
        val bottomLeft = if (p1.x > p2.x) p2 else p1

        return listOf(topLeft, topRight, bottomRight, bottomLeft)
    }

    /**
     * 透视变换矫正
     */
    private fun perspectiveTransform(src: Mat, corners: List<Point>): Mat {
        val (tl, tr, br, bl) = corners

        // 计算新图片的宽度和高度
        val widthA = sqrt((br.x - bl.x) * (br.x - bl.x) + (br.y - bl.y) * (br.y - bl.y))
        val widthB = sqrt((tr.x - tl.x) * (tr.x - tl.x) + (tr.y - tl.y) * (tr.y - tl.y))
        val maxWidth = maxOf(widthA, widthB).toInt()

        val heightA = sqrt((tr.x - br.x) * (tr.x - br.x) + (tr.y - br.y) * (tr.y - br.y))
        val heightB = sqrt((tl.x - bl.x) * (tl.x - bl.x) + (tl.y - bl.y) * (tl.y - bl.y))
        val maxHeight = maxOf(heightA, heightB).toInt()

        // 目标点
        val dst = MatOfPoint2f(
            Point(0.0, 0.0),
            Point(maxWidth - 1.0, 0.0),
            Point(maxWidth - 1.0, maxHeight - 1.0),
            Point(0.0, maxHeight - 1.0)
        )

        // 源点
        val srcPoints = MatOfPoint2f(*corners.toTypedArray())

        // 获取透视变换矩阵
        val matrix = Imgproc.getPerspectiveTransform(srcPoints, dst)

        // 应用透视变换
        val warped = Mat()
        Imgproc.warpPerspective(
            src,
            warped,
            matrix,
            Size(maxWidth.toDouble(), maxHeight.toDouble())
        )

        matrix.release()
        dst.release()
        srcPoints.release()

        return warped
    }

    /**
     * 自动提亮和对比度优化
     */
    private fun autoEnhance(src: Mat): Mat {
        val lab = Mat()
        val channels = ArrayList<Mat>()

        // 转换到LAB色彩空间
        Imgproc.cvtColor(src, lab, Imgproc.COLOR_BGR2Lab)
        Core.split(lab, channels)

        // 对L通道应用CLAHE（限制对比度自适应直方图均衡化）
        val clahe = Imgproc.createCLAHE(2.0, Size(8.0, 8.0))
        clahe.apply(channels[0], channels[0])

        // 合并通道
        Core.merge(channels, lab)

        // 转换回BGR
        val enhanced = Mat()
        Imgproc.cvtColor(lab, enhanced, Imgproc.COLOR_Lab2BGR)

        // 释放资源
        lab.release()
        channels.forEach { it.release() }

        return enhanced
    }
}

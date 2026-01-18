package com.snapstraight.app

import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.View
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.core.content.ContextCompat
import com.snapstraight.app.databinding.ActivityCameraBinding
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.MatOfPoint
import org.opencv.core.MatOfPoint2f
import org.opencv.core.Point
import org.opencv.core.Size
import org.opencv.imgproc.Imgproc
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * 相机拍摄Activity
 * 全屏取景，一键拍照，自动进入处理流程
 */
class CameraActivity : AppCompatActivity() {

    private lateinit var binding: ActivityCameraBinding
    private var imageCapture: ImageCapture? = null
    private lateinit var cameraExecutor: ExecutorService
    private var imageAnalysis: ImageAnalysis? = null

    // 检测状态
    private var isAutoCapturing = false
    private var hasDetectedRectangle = false
    private var stabilityCounter = 0
    private val stabilityThreshold = 25
    private var lastCenterX = 0.0
    private var lastCenterY = 0.0
    private var hasLastCenter = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityCameraBinding.inflate(layoutInflater)
        setContentView(binding.root)

        cameraExecutor = Executors.newSingleThreadExecutor()

        startCamera()
        setupButtons()

        // 初始UI状态
        binding.tvHint.text = getString(R.string.hint_no_edges)
        binding.tvHint.visibility = View.GONE
        binding.progressIndicator.max = stabilityThreshold
        binding.progressIndicator.progress = 0
    }

    private fun setupButtons() {
        // 返回按钮
        binding.btnBack.setOnClickListener {
            finish()
        }

        // 拍照按钮
        binding.btnCapture.setOnClickListener {
            takePhoto()
        }
    }

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)

        cameraProviderFuture.addListener({
            val cameraProvider = cameraProviderFuture.get()

            // 预览
            val preview = Preview.Builder()
                .build()
                .also {
                    it.setSurfaceProvider(binding.previewView.surfaceProvider)
                }

            // 图像捕获
            imageCapture = ImageCapture.Builder()
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                .build()

            // 默认后置摄像头
            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

            try {
                cameraProvider.unbindAll()
                // 实时分析（用于自动拍照稳定判定）
                imageAnalysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()

                imageAnalysis?.setAnalyzer(cameraExecutor) { image ->
                    analyzeFrame(image)
                }

                cameraProvider.bindToLifecycle(
                    this, cameraSelector, preview, imageCapture, imageAnalysis
                )
            } catch (e: Exception) {
                Log.e(TAG, "Camera binding failed", e)
            }

        }, ContextCompat.getMainExecutor(this))
    }

    private fun takePhoto() {
        val imageCapture = imageCapture ?: return

        // 创建临时文件
        val photoFile = File(
            cacheDir,
            "temp_${System.currentTimeMillis()}.jpg"
        )

        val outputOptions = ImageCapture.OutputFileOptions.Builder(photoFile).build()

        imageCapture.takePicture(
            outputOptions,
            ContextCompat.getMainExecutor(this),
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                    // 拍照成功：读取原图，检测初始四边形，进入结果页
                    Thread {
                        try {
                            val bitmap = android.graphics.BitmapFactory.decodeFile(photoFile.absolutePath)
                            val quad = if (bitmap != null) ImageProcessor.detectQuad(bitmap) else null

                            // 删除临时文件
                            photoFile.delete()

                            runOnUiThread {
                                val intent = Intent(this@CameraActivity, ResultActivity::class.java)
                                ResultActivity.setOriginalBitmap(bitmap!!)
                                ResultActivity.setInitialQuad(quad)
                                startActivity(intent)
                                finish()
                            }
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }.start()
                }

                override fun onError(exception: ImageCaptureException) {
                    Log.e(TAG, "Photo capture failed: ${exception.message}", exception)
                }
            }
        )
    }

    private fun analyzeFrame(image: ImageProxy) {
        if (isAutoCapturing) { image.close(); return }
        try {
            val corners = detectEdges(image)
            runOnUiThread {
                updateDetectionUI(corners, image.width.toDouble(), image.height.toDouble())
            }
        } catch (e: Exception) {
            Log.e(TAG, "analyze error", e)
        } finally {
            image.close()
        }
    }

    private fun updateDetectionUI(corners: List<org.opencv.core.Point>?, w: Double, h: Double) {
        if (corners == null) {
            binding.tvHint.visibility = View.VISIBLE
            hasDetectedRectangle = false
            stabilityCounter = 0
            binding.progressIndicator.progress = 0
            updateCaptureEnabled(false)
            hasLastCenter = false
            return
        }

        // 计算中心点（像素坐标）并归一化
        val cx = (corners[0].x + corners[1].x + corners[2].x + corners[3].x) * 0.25 / w
        val cy = (corners[0].y + corners[1].y + corners[2].y + corners[3].y) * 0.25 / h

        binding.tvHint.visibility = View.GONE
        if (!hasDetectedRectangle) {
            hasDetectedRectangle = true
            updateCaptureEnabled(true)
        }

        if (hasLastCenter) {
            val dx = cx - lastCenterX
            val dy = cy - lastCenterY
            val dist = kotlin.math.sqrt(dx * dx + dy * dy)
            when {
                dist < 0.02 -> stabilityCounter += 1
                dist > 0.05 -> stabilityCounter = 0
            }
        } else {
            stabilityCounter = 0
            hasLastCenter = true
        }
        lastCenterX = cx
        lastCenterY = cy

        binding.progressIndicator.progress = stabilityCounter

        if (stabilityCounter >= stabilityThreshold) {
            triggerAutoCapture()
        }
    }

    private fun updateCaptureEnabled(enabled: Boolean) {
        binding.btnCapture.isEnabled = enabled
        binding.btnCapture.alpha = if (enabled) 1.0f else 0.5f
        binding.btnCapture.scaleX = if (enabled) 1.0f else 0.9f
        binding.btnCapture.scaleY = if (enabled) 1.0f else 0.9f
    }

    private fun triggerAutoCapture() {
        if (isAutoCapturing) return
        isAutoCapturing = true
        stabilityCounter = 0
        binding.progressIndicator.progress = 0

        // 震动反馈
        val vibrator = getSystemService(VIBRATOR_SERVICE) as android.os.Vibrator
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            vibrator.vibrate(
                android.os.VibrationEffect.createOneShot(
                    80,
                    android.os.VibrationEffect.DEFAULT_AMPLITUDE
                )
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(80)
        }

        takePhoto()
        isAutoCapturing = false
    }

    /**
     * 从 ImageProxy 的Y平面进行边缘检测，返回四个角点（像素坐标）
     */
    private fun detectEdges(image: ImageProxy): List<org.opencv.core.Point>? {
        val yPlane = image.planes[0]
        val width = image.width
        val height = image.height
        val rowStride = yPlane.rowStride
        val pixelStride = yPlane.pixelStride

        val yBuffer = yPlane.buffer
        yBuffer.rewind()

        // 构造灰度Mat
        val gray = Mat(height, width, CvType.CV_8UC1)
        val rowData = ByteArray(rowStride)

        for (r in 0 until height) {
            yBuffer.position(r * rowStride)
            yBuffer.get(rowData, 0, rowStride)
            if (pixelStride == 1) {
                gray.put(r, 0, rowData, 0, width)
            } else {
                // 非常罕见：像素步长>1，按步长采样
                val line = ByteArray(width)
                var idx = 0
                var srcIdx = 0
                while (idx < width && srcIdx < rowStride) {
                    line[idx] = rowData[srcIdx]
                    idx++
                    srcIdx += pixelStride
                }
                gray.put(r, 0, line)
            }
        }

        // 缩放以提速
        val scale = 800.0 / maxOf(width, height)
        val small = Mat()
        if (scale < 1.0) {
            Imgproc.resize(gray, small, Size(), scale, scale, Imgproc.INTER_AREA)
        } else {
            gray.copyTo(small)
        }

        // 边缘与轮廓
        val blurred = Mat()
        val edges = Mat()
        Imgproc.GaussianBlur(small, blurred, Size(5.0, 5.0), 0.0)
        Imgproc.Canny(blurred, edges, 75.0, 200.0)

        val contours = ArrayList<MatOfPoint>()
        val hierarchy = Mat()
        Imgproc.findContours(edges, contours, hierarchy, Imgproc.RETR_LIST, Imgproc.CHAIN_APPROX_SIMPLE)

        var maxArea = 0.0
        var best: MatOfPoint2f? = null
        for (c in contours) {
            val area = Imgproc.contourArea(c)
            if (area > maxArea) {
                val peri = Imgproc.arcLength(MatOfPoint2f(*c.toArray()), true)
                val approx = MatOfPoint2f()
                Imgproc.approxPolyDP(MatOfPoint2f(*c.toArray()), approx, 0.02 * peri, true)
                if (approx.total() == 4L && area > small.width() * small.height() * 0.1) {
                    maxArea = area
                    best = approx
                }
            }
        }

        // 清理
        gray.release(); small.release(); blurred.release(); edges.release(); hierarchy.release()
        contours.forEach { it.release() }

        val cornersSmall = best?.toArray()?.toList()
        if (cornersSmall == null) return null

        // 映射回原图尺寸
        val invScale = if (scale < 1.0) (1.0 / scale) else 1.0
        val corners = cornersSmall.map { p -> org.opencv.core.Point(p.x * invScale, p.y * invScale) }
        return orderPoints(corners)
    }

    private fun orderPoints(points: List<org.opencv.core.Point>): List<org.opencv.core.Point> {
        val sorted = points.sortedBy { it.x + it.y }
        val topLeft = sorted.first()
        val bottomRight = sorted.last()
        val remaining = points.filter { it != topLeft && it != bottomRight }
        val p1 = remaining[0]
        val p2 = remaining[1]
        val topRight = if (p1.x > p2.x) p1 else p2
        val bottomLeft = if (p1.x > p2.x) p2 else p1
        return listOf(topLeft, topRight, bottomRight, bottomLeft)
    }

    override fun onDestroy() {
        super.onDestroy()
        cameraExecutor.shutdown()
    }

    companion object {
        private const val TAG = "CameraActivity"

        init {
            try {
                System.loadLibrary("opencv_java4")
            } catch (_: UnsatisfiedLinkError) {
                // library loading will be attempted elsewhere if needed
            }
        }
    }
}

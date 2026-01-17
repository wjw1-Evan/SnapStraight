package com.snapstraight.app

import android.graphics.Bitmap
import android.view.View
import android.view.ViewTreeObserver
import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.snapstraight.app.databinding.ActivityResultBinding

/**
 * 结果展示Activity
 * 显示处理后的图片，提供保存功能
 */
class ResultActivity : AppCompatActivity() {

    private lateinit var binding: ActivityResultBinding
    private lateinit var overlayView: QuadOverlayView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityResultBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setupUI()
        setupButtons()
    }

    private fun setupUI() {
        // 如果有原图，显示原图并配置覆盖层
        originalBitmap?.let { bitmap ->
            binding.ivResult.setImageBitmap(bitmap)

            overlayView = QuadOverlayView(this)
            // 将覆盖层添加到根布局，并与图片视图同区域约束
            val root = binding.root as androidx.constraintlayout.widget.ConstraintLayout
            overlayView.id = View.generateViewId()
            root.addView(overlayView, 0)

            // 约束覆盖层与图片视图对齐
            val params = overlayView.layoutParams as androidx.constraintlayout.widget.ConstraintLayout.LayoutParams
            params.width = 0
            params.height = 0
            params.topToTop = binding.ivResult.id
            params.bottomToBottom = binding.ivResult.id
            params.startToStart = binding.ivResult.id
            params.endToEnd = binding.ivResult.id
            overlayView.layoutParams = params

            // 等待ImageView完成布局后再配置覆盖层坐标
            binding.ivResult.viewTreeObserver.addOnGlobalLayoutListener(object: ViewTreeObserver.OnGlobalLayoutListener{
                override fun onGlobalLayout() {
                    binding.ivResult.viewTreeObserver.removeOnGlobalLayoutListener(this)
                    overlayView.configure(binding.ivResult, initialQuad)
                }
            })
        }
    }

    private fun setupButtons() {
        // 返回按钮
        binding.btnBack.setOnClickListener {
            finish()
        }

        // 保存按钮
        binding.btnSave.setOnClickListener {
            saveImage()
        }
    }

    private fun saveImage() {
        val quad = overlayView.currentNormalizedQuad()
        val src = originalBitmap
        if (quad == null || src == null) return

        Toast.makeText(this, R.string.processing, Toast.LENGTH_SHORT).show()

        Thread {
            try {
                val processed = ImageProcessor.processImageWithQuad(src, quad)
                runOnUiThread {
                    ImageSaver.saveToGallery(this, processed) { success ->
                        if (success) {
                            Toast.makeText(this, R.string.save_success, Toast.LENGTH_SHORT).show()
                            vibrate()
                            finish()
                        } else {
                            Toast.makeText(this, R.string.save_failed, Toast.LENGTH_SHORT).show()
                        }
                    }
                }
            } catch (e: Exception) {
                runOnUiThread {
                    Toast.makeText(this, R.string.save_failed, Toast.LENGTH_SHORT).show()
                }
            }
        }.start()
    }

    private fun vibrate() {
        val vibrator = getSystemService(VIBRATOR_SERVICE) as android.os.Vibrator
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            vibrator.vibrate(
                android.os.VibrationEffect.createOneShot(
                    100,
                    android.os.VibrationEffect.DEFAULT_AMPLITUDE
                )
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(100)
        }
    }

    companion object {
        // 原图与初始四边形（实际项目中请使用更安全的传递方式）
        private var originalBitmap: Bitmap? = null
        private var initialQuad: ImageProcessor.NormalizedQuad? = null

        fun setOriginalBitmap(bitmap: Bitmap) { originalBitmap = bitmap }
        fun setInitialQuad(quad: ImageProcessor.NormalizedQuad?) { initialQuad = quad }
    }
}

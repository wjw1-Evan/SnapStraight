package com.snapstraight.app

import android.graphics.Bitmap
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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityResultBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setupUI()
        setupButtons()
    }

    private fun setupUI() {
        // 显示处理后的图片
        imageBitmap?.let {
            binding.ivResult.setImageBitmap(it)
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
        imageBitmap?.let { bitmap ->
            ImageSaver.saveToGallery(this, bitmap) { success ->
                if (success) {
                    Toast.makeText(this, R.string.save_success, Toast.LENGTH_SHORT).show()
                    // 轻微震动反馈
                    vibrate()
                    // 返回主页
                    finish()
                } else {
                    Toast.makeText(this, R.string.save_failed, Toast.LENGTH_SHORT).show()
                }
            }
        }
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
        // 使用静态变量临时存储图片（实际项目中应使用更好的方案）
        private var imageBitmap: Bitmap? = null

        fun setImageBitmap(bitmap: Bitmap) {
            imageBitmap = bitmap
        }
    }
}

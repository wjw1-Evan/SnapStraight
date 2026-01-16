package com.snapstraight.app

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStream

/**
 * 图片保存工具类
 * 负责将处理后的图片保存到相册
 */
object ImageSaver {

    /**
     * 保存图片到相册
     * @param context 上下文
     * @param bitmap 要保存的图片
     * @param onComplete 完成回调，返回是否成功
     */
    fun saveToGallery(
        context: Context,
        bitmap: Bitmap,
        onComplete: (Boolean) -> Unit
    ) {
        Thread {
            try {
                val success = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    // Android 10及以上使用MediaStore
                    saveImageAboveQ(context, bitmap)
                } else {
                    // Android 10以下直接保存到文件
                    saveImageBelowQ(context, bitmap)
                }

                android.os.Handler(context.mainLooper).post {
                    onComplete(success)
                }
            } catch (e: Exception) {
                e.printStackTrace()
                android.os.Handler(context.mainLooper).post {
                    onComplete(false)
                }
            }
        }.start()
    }

    /**
     * Android 10及以上保存方式
     */
    private fun saveImageAboveQ(context: Context, bitmap: Bitmap): Boolean {
        val fileName = "SnapStraight_${System.currentTimeMillis()}.jpg"
        val contentValues = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/SnapStraight")
        }

        val uri = context.contentResolver.insert(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            contentValues
        )

        return uri?.let {
            val outputStream: OutputStream? = context.contentResolver.openOutputStream(it)
            outputStream?.use { stream ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 95, stream)
            }
            true
        } ?: false
    }

    /**
     * Android 10以下保存方式
     */
    private fun saveImageBelowQ(context: Context, bitmap: Bitmap): Boolean {
        val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
        val snapStraightDir = File(picturesDir, "SnapStraight")
        
        if (!snapStraightDir.exists()) {
            snapStraightDir.mkdirs()
        }

        val fileName = "SnapStraight_${System.currentTimeMillis()}.jpg"
        val file = File(snapStraightDir, fileName)

        return try {
            FileOutputStream(file).use { outputStream ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 95, outputStream)
            }

            // 通知系统扫描新文件
            val contentValues = ContentValues().apply {
                put(MediaStore.Images.Media.DATA, file.absolutePath)
                put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
            }
            context.contentResolver.insert(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                contentValues
            )

            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}

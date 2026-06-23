package com.trafficsafety.traffic_safety_app

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Matrix
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * FrameProcessor handles camera frame preprocessing for YOLOv8 TFLite inference.
 * Uses pure Android Bitmap APIs — no OpenCV dependency required.
 *
 * Pipeline: YUV_420_888 → RGB Bitmap → Rotate → 640×640 resize → [0,1] normalized ByteBuffer
 */
class FrameProcessor {
    private val TAG = "FrameProcessor"
    private val MODEL_INPUT_SIZE = 640

    /**
     * Converts YUV_420_888 plane byte arrays to an Android Bitmap (ARGB_8888).
     * Includes bounds checking to handle varied hardware stride sizes safely.
     */
    fun yuvToBitmap(
        width: Int,
        height: Int,
        yBytes: ByteArray,
        uBytes: ByteArray,
        vBytes: ByteArray,
        yRowStride: Int,
        uRowStride: Int,
        vRowStride: Int,
        uPixelStride: Int,
        vPixelStride: Int
    ): Bitmap {
        val pixels = IntArray(width * height)

        for (row in 0 until height) {
            for (col in 0 until width) {
                // Y plane
                val yIndex = row * yRowStride + col
                val y = if (yIndex < yBytes.size) (yBytes[yIndex].toInt() and 0xFF) else 0

                // UV planes (subsampled 2x2)
                val uvRow = row / 2
                val uvCol = col / 2
                val uIndex = uvRow * uRowStride + uvCol * uPixelStride
                val vIndex = uvRow * vRowStride + uvCol * vPixelStride

                val u = if (uIndex < uBytes.size) (uBytes[uIndex].toInt() and 0xFF) - 128 else 0
                val v = if (vIndex < vBytes.size) (vBytes[vIndex].toInt() and 0xFF) - 128 else 0

                // YUV to RGB conversion (BT.601)
                val r = (y + 1.370705 * v).toInt().coerceIn(0, 255)
                val g = (y - 0.337633 * u - 0.698001 * v).toInt().coerceIn(0, 255)
                val b = (y + 1.732446 * u).toInt().coerceIn(0, 255)

                pixels[row * width + col] = (0xFF shl 24) or (r shl 16) or (g shl 8) or b
            }
        }

        return Bitmap.createBitmap(pixels, width, height, Bitmap.Config.ARGB_8888)
    }

    /**
     * Rotates a Bitmap by the specified degrees and recycles the original bitmap.
     */
    fun rotateBitmap(bitmap: Bitmap, degrees: Float): Bitmap {
        if (degrees == 0f) return bitmap
        val matrix = Matrix()
        matrix.postRotate(degrees)
        val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        if (rotated != bitmap) {
            bitmap.recycle()
        }
        return rotated
    }

    /**
     * Checks if the image is blurry using variance of pixel intensity gradients.
     * Uses optimized bit shifting.
     */
    fun isBlurry(bitmap: Bitmap, threshold: Double = 100.0): Pair<Boolean, Double> {
        val width = bitmap.width
        val height = bitmap.height
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)

        // Convert to grayscale and compute Laplacian variance
        var sum = 0.0
        var sumSq = 0.0
        var count = 0

        for (row in 1 until height - 1) {
            for (col in 1 until width - 1) {
                val center = luminance(pixels[row * width + col])
                val top = luminance(pixels[(row - 1) * width + col])
                val bottom = luminance(pixels[(row + 1) * width + col])
                val left = luminance(pixels[row * width + (col - 1)])
                val right = luminance(pixels[row * width + (col + 1)])

                // Laplacian: 4*center - top - bottom - left - right
                val laplacian = 4.0 * center - top - bottom - left - right
                sum += laplacian
                sumSq += laplacian * laplacian
                count++
            }
        }

        val mean = sum / count
        val variance = (sumSq / count) - (mean * mean)

        return Pair(variance < threshold, variance)
    }

    /**
     * Applies a simple sharpening kernel using 3x3 unsharp mask.
     * Highly optimized using bitwise shifts instead of Color methods.
     */
    fun sharpen(bitmap: Bitmap): Bitmap {
        val width = bitmap.width
        val height = bitmap.height
        val srcPixels = IntArray(width * height)
        bitmap.getPixels(srcPixels, 0, width, 0, 0, width, height)

        val dstPixels = IntArray(width * height)

        // Sharpening kernel: center=5, neighbors=-1
        for (row in 1 until height - 1) {
            for (col in 1 until width - 1) {
                val idx = row * width + col
                val center = srcPixels[idx]
                val top = srcPixels[(row - 1) * width + col]
                val bottom = srcPixels[(row + 1) * width + col]
                val left = srcPixels[row * width + (col - 1)]
                val right = srcPixels[row * width + (col + 1)]

                val cR = (center shr 16) and 0xFF
                val tR = (top shr 16) and 0xFF
                val bR = (bottom shr 16) and 0xFF
                val lR = (left shr 16) and 0xFF
                val rR = (right shr 16) and 0xFF
                val r = (5 * cR - tR - bR - lR - rR).coerceIn(0, 255)

                val cG = (center shr 8) and 0xFF
                val tG = (top shr 8) and 0xFF
                val bG = (bottom shr 8) and 0xFF
                val lG = (left shr 8) and 0xFF
                val rG = (right shr 8) and 0xFF
                val g = (5 * cG - tG - bG - lG - rG).coerceIn(0, 255)

                val cB = center and 0xFF
                val tB = top and 0xFF
                val bB = bottom and 0xFF
                val lB = left and 0xFF
                val rB = right and 0xFF
                val b = (5 * cB - tB - bB - lB - rB).coerceIn(0, 255)

                dstPixels[idx] = (0xFF shl 24) or (r shl 16) or (g shl 8) or b
            }
        }

        // Copy border pixels unchanged
        for (col in 0 until width) {
            dstPixels[col] = srcPixels[col] // top row
            dstPixels[(height - 1) * width + col] = srcPixels[(height - 1) * width + col] // bottom row
        }
        for (row in 0 until height) {
            dstPixels[row * width] = srcPixels[row * width] // left column
            dstPixels[row * width + (width - 1)] = srcPixels[row * width + (width - 1)] // right column
        }

        return Bitmap.createBitmap(dstPixels, width, height, Bitmap.Config.ARGB_8888)
    }

    /**
     * Full preprocessing pipeline:
     * YUV → Bitmap → Rotate → (optional sharpen) → Resize 640×640 → Normalized ByteBuffer
     *
     * Returns a Pair of (ByteBuffer for TFLite input, resized Bitmap for reference).
     */
    fun preprocessFrame(
        width: Int,
        height: Int,
        yBytes: ByteArray,
        uBytes: ByteArray,
        vBytes: ByteArray,
        yRowStride: Int,
        uRowStride: Int,
        vRowStride: Int,
        uPixelStride: Int,
        vPixelStride: Int,
        sensorOrientation: Int
    ): Pair<ByteBuffer, Bitmap> {
        // 1. Convert YUV to RGB Bitmap
        var bitmap = yuvToBitmap(
            width, height, yBytes, uBytes, vBytes,
            yRowStride, uRowStride, vRowStride, uPixelStride, vPixelStride
        )

        // 2. Rotate bitmap upright based on camera sensor orientation
        if (sensorOrientation != 0) {
            bitmap = rotateBitmap(bitmap, sensorOrientation.toFloat())
        }

        // 3. Optional sharpening for blurry frames (skip for speed if frame is sharp)
        try {
            val (blurry, variance) = isBlurry(bitmap)
            if (blurry) {
                Log.d(TAG, "Frame blurry (variance: $variance). Applying sharpening.")
                val sharpened = sharpen(bitmap)
                bitmap.recycle()
                bitmap = sharpened
            }
        } catch (e: Exception) {
            Log.w(TAG, "Blur check failed, skipping: ${e.message}")
        }

        // 4. Resize to 640×640
        val resized = Bitmap.createScaledBitmap(bitmap, MODEL_INPUT_SIZE, MODEL_INPUT_SIZE, true)
        if (resized != bitmap) {
            bitmap.recycle()
        }

        // 5. Normalize pixel values to [0.0, 1.0] and pack into ByteBuffer (optimized bitwise shift)
        val byteBuffer = ByteBuffer.allocateDirect(1 * MODEL_INPUT_SIZE * MODEL_INPUT_SIZE * 3 * 4)
        byteBuffer.order(ByteOrder.nativeOrder())
        byteBuffer.rewind()

        val pixels = IntArray(MODEL_INPUT_SIZE * MODEL_INPUT_SIZE)
        resized.getPixels(pixels, 0, MODEL_INPUT_SIZE, 0, 0, MODEL_INPUT_SIZE, MODEL_INPUT_SIZE)

        for (pixel in pixels) {
            val r = (pixel shr 16) and 0xFF
            val g = (pixel shr 8) and 0xFF
            val b = pixel and 0xFF
            byteBuffer.putFloat(r / 255.0f)
            byteBuffer.putFloat(g / 255.0f)
            byteBuffer.putFloat(b / 255.0f)
        }

        return Pair(byteBuffer, resized)
    }

    /**
     * Compute luminance (grayscale intensity) from an ARGB pixel (optimized shift).
     */
    private fun luminance(pixel: Int): Double {
        val r = (pixel shr 16) and 0xFF
        val g = (pixel shr 8) and 0xFF
        val b = pixel and 0xFF
        return 0.299 * r + 0.587 * g + 0.114 * b
    }
}

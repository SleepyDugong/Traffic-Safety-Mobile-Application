package com.trafficsafety.traffic_safety_app

import android.content.res.AssetManager
import android.graphics.Bitmap
import android.util.Log
import org.opencv.core.*
import org.opencv.imgproc.Imgproc
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel

class FrameProcessor(private val assetManager: AssetManager) {
    private val TAG = "FrameProcessor"
    
    // Check if the image is blurry using the variance of Laplacian method
    fun isBlurry(rgbMat: Mat, threshold: Double = 15.0): Pair<Boolean, Double> {
        val gray = Mat()
        Imgproc.cvtColor(rgbMat, gray, Imgproc.COLOR_RGB2GRAY)
        val destination = Mat()
        Imgproc.Laplacian(gray, destination, CvType.CV_64F)
        
        val mean = MatOfDouble()
        val stddev = MatOfDouble()
        Core.meanStdDev(destination, mean, stddev)
        
        val variance = stddev.toArray()[0] * stddev.toArray()[0]
        
        gray.release()
        destination.release()
        
        return Pair(variance < threshold, variance)
    }

    // Apply OpenCV unsharp masking to sharpen blurry images
    fun sharpen(rgbMat: Mat): Mat {
        val blurred = Mat()
        Imgproc.GaussianBlur(rgbMat, blurred, Size(0.0, 0.0), 3.0)
        
        val sharpened = Mat()
        Core.addWeighted(rgbMat, 1.5, blurred, -0.5, 0.0, sharpened)
        
        blurred.release()
        return sharpened
    }

    // Converts YUV_420_888 plane byte arrays to an OpenCV RGB Mat
    fun yuvToRgbMat(
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
    ): Mat {
        val nv21 = ByteArray(width * height * 3 / 2)
        
        // Copy Y channel
        if (yRowStride == width) {
            System.arraycopy(yBytes, 0, nv21, 0, width * height)
        } else {
            for (row in 0 until height) {
                System.arraycopy(yBytes, row * yRowStride, nv21, row * width, width)
            }
        }
        
        // Interleave V and U channels (NV21 format has V first, then U: V, U, V, U...)
        var nvIndex = width * height
        val uvWidth = width / 2
        val uvHeight = height / 2
        
        for (row in 0 until uvHeight) {
            val uRowStart = row * uRowStride
            val vRowStart = row * vRowStride
            for (col in 0 until uvWidth) {
                val uVal = uBytes[uRowStart + col * uPixelStride]
                val vVal = vBytes[vRowStart + col * vPixelStride]
                nv21[nvIndex++] = vVal
                nv21[nvIndex++] = uVal
            }
        }
        
        val yuvMat = Mat(height + height / 2, width, CvType.CV_8UC1)
        yuvMat.put(0, 0, nv21)
        
        val rgbMat = Mat()
        Imgproc.cvtColor(yuvMat, rgbMat, Imgproc.COLOR_YUV2RGB_NV21)
        yuvMat.release()
        return rgbMat
    }

    // Preprocess the frame: convert to Mat, sharpen if blurry, resize to 640x640, normalize and return input bytebuffer for TFLite
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
        vPixelStride: Int
    ): Pair<ByteBuffer, Mat> {
        // Convert YUV to RGB Mat
        var rgbMat = yuvToRgbMat(width, height, yBytes, uBytes, vBytes, yRowStride, uRowStride, vRowStride, uPixelStride, vPixelStride)
        
        // Assess and enhance if blurry
        val (blurry, variance) = isBlurry(rgbMat)
        if (blurry) {
            Log.d(TAG, "Frame blurry (variance: $variance). Applying OpenCV unsharp mask filter.")
            val sharpened = sharpen(rgbMat)
            rgbMat.release()
            rgbMat = sharpened
        }
        
        // Resize to 640x640
        val resizedMat = Mat()
        Imgproc.resize(rgbMat, resizedMat, Size(640.0, 640.0))
        
        // Prepare ByteBuffer
        val byteBuffer = ByteBuffer.allocateDirect(1 * 640 * 640 * 3 * 4)
        byteBuffer.order(ByteOrder.nativeOrder())
        byteBuffer.rewind()
        
        // Put data into ByteBuffer normalized to [0.0, 1.0]
        val rowData = ByteArray(640 * 3)
        for (i in 0 until 640) {
            resizedMat.get(i, 0, rowData)
            for (j in 0 until 640) {
                // Get R, G, B values from rowData (byte is signed, convert to unsigned)
                val r = (rowData[j * 3].toInt() and 0xFF) / 255.0f
                val g = (rowData[j * 3 + 1].toInt() and 0xFF) / 255.0f
                val b = (rowData[j * 3 + 2].toInt() and 0xFF) / 255.0f
                byteBuffer.putFloat(r)
                byteBuffer.putFloat(g)
                byteBuffer.putFloat(b)
            }
        }
        
        resizedMat.release()
        return Pair(byteBuffer, rgbMat)
    }
}

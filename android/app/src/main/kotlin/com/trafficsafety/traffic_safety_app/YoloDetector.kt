package com.trafficsafety.traffic_safety_app

import android.content.res.AssetManager
import android.graphics.RectF
import android.util.Log
import org.tensorflow.lite.Interpreter
import org.tensorflow.lite.gpu.GpuDelegate
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel

data class Detection(
    val boundingBox: RectF, // Normalized coordinates [left, top, right, bottom]
    val confidence: Float,
    val label: String
)

class YoloDetector(private val assetManager: AssetManager) {
    private val TAG = "YoloDetector"
    private var interpreter: Interpreter? = null
    private var gpuDelegate: GpuDelegate? = null

    init {
        try {
            val modelBuffer = loadModelFile(assetManager, "yolov8n_car.tflite")
            val options = Interpreter.Options()
            
            // Try enabling GPU delegate, fallback to CPU
            try {
                gpuDelegate = GpuDelegate()
                options.addDelegate(gpuDelegate)
                Log.i(TAG, "TFLite GPU Delegate added successfully.")
            } catch (e: Exception) {
                Log.w(TAG, "TFLite GPU Delegate failed to initialize: ${e.message}. Using CPU.")
                options.setNumThreads(4)
            }
            
            interpreter = Interpreter(modelBuffer, options)
            Log.i(TAG, "YOLOv8 TFLite model loaded successfully.")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load YOLOv8 TFLite model: ${e.message}")
        }
    }

    private fun loadModelFile(assets: AssetManager, modelPath: String): MappedByteBuffer {
        val fileDescriptor = assets.openFd(modelPath)
        val inputStream = FileInputStream(fileDescriptor.fileDescriptor)
        val fileChannel = inputStream.channel
        val startOffset = fileDescriptor.startOffset
        val declaredLength = fileDescriptor.declaredLength
        return fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength)
    }

    fun detect(inputBuffer: ByteBuffer): List<Detection> {
        val tflite = interpreter ?: return emptyList()
        
        // Output tensor shape is [1, 84, 8400]
        val output = Array(1) { Array(84) { FloatArray(8400) } }
        
        tflite.run(inputBuffer, output)
        
        val detections = ArrayList<Detection>()
        val confidenceThreshold = 0.35f
        
        for (anchor in 0 until 8400) {
            // Find max class confidence
            var maxClassId = -1
            var maxScore = 0.0f
            
            // Class index begins at 4
            for (c in 4 until 84) {
                val score = output[0][c][anchor]
                if (score > maxScore) {
                    maxScore = score
                    maxClassId = c - 4
                }
            }
            
            if (maxScore >= confidenceThreshold) {
                val cx = output[0][0][anchor]
                val cy = output[0][1][anchor]
                val w = output[0][2][anchor]
                val h = output[0][3][anchor]
                
                // Convert center-based coordinates to left-top-right-bottom RectF
                val left = (cx - w / 2.0f) / 640.0f
                val top = (cy - h / 2.0f) / 640.0f
                val right = (cx + w / 2.0f) / 640.0f
                val bottom = (cy + h / 2.0f) / 640.0f
                
                val box = RectF(
                    left.coerceIn(0.0f, 1.0f),
                    top.coerceIn(0.0f, 1.0f),
                    right.coerceIn(0.0f, 1.0f),
                    bottom.coerceIn(0.0f, 1.0f)
                )
                
                // Map COCO IDs to labels of interest
                val label = when (maxClassId) {
                    0 -> "Pedestrian"
                    1 -> "Bicycle"
                    2 -> "car"
                    3 -> "Motorcycle"
                    5 -> "Truck" // Map bus/large vehicle to Truck
                    7 -> "Truck"
                    else -> null // Filter out classes not relevant to our HUD warnings
                }
                
                if (label != null) {
                    detections.add(Detection(box, maxScore, label))
                }
            }
        }
        
        // Run Non-Maximum Suppression (NMS)
        return runNMS(detections)
    }

    private fun runNMS(detections: List<Detection>, iouThreshold: Float = 0.45f): List<Detection> {
        val sorted = detections.sortedByDescending { it.confidence }
        val kept = ArrayList<Detection>()
        val suppressed = BooleanArray(sorted.size)
        
        for (i in sorted.indices) {
            if (suppressed[i]) continue
            val current = sorted[i]
            kept.add(current)
            
            for (j in i + 1 until sorted.size) {
                if (suppressed[j]) continue
                val next = sorted[j]
                
                // Class-specific NMS
                if (current.label == next.label) {
                    val iou = calculateIoU(current.boundingBox, next.boundingBox)
                    if (iou > iouThreshold) {
                        suppressed[j] = true
                    }
                }
            }
        }
        return kept
    }

    private fun calculateIoU(boxA: RectF, boxB: RectF): Float {
        val xA = maxOf(boxA.left, boxB.left)
        val yA = maxOf(boxA.top, boxB.top)
        val xB = minOf(boxA.right, boxB.right)
        val yB = minOf(boxA.bottom, boxB.bottom)
        
        val interArea = maxOf(0.0f, xB - xA) * maxOf(0.0f, yB - yA)
        if (interArea == 0.0f) return 0.0f
        
        val areaA = (boxA.right - boxA.left) * (boxA.bottom - boxA.top)
        val areaB = (boxB.right - boxB.left) * (boxB.bottom - boxB.top)
        
        return interArea / (areaA + areaB - interArea)
    }

    fun close() {
        interpreter?.close()
        gpuDelegate?.close()
    }
}

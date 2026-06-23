package com.trafficsafety.traffic_safety_app

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val BACKGROUND_CHANNEL = "com.trafficsafety.app/background"
    private val YOLO_CHANNEL = "com.trafficsafety.app/yolo"

    private lateinit var frameProcessor: FrameProcessor
    private lateinit var yoloDetector: YoloDetector
    private lateinit var vehicleTracker: VehicleTracker
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var latestDetections: List<Map<String, Any>> = emptyList()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize pure-Android frame processor (no OpenCV needed)
        frameProcessor = FrameProcessor()
        yoloDetector = YoloDetector(assets)
        vehicleTracker = VehicleTracker()

        Log.i("MainActivity", "Traffic Safety system initialized successfully.")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Background Channel — allows the app to be sent to background
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKGROUND_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendToBackground") {
                moveTaskToBack(true)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }

        // YOLO detection channel — processes camera frames and returns detection results
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, YOLO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getLatestDetections" -> {
                    result.success(latestDetections)
                }
                "processFrame" -> {
                    val width = call.argument<Int>("width")
                    val height = call.argument<Int>("height")
                    val yBytes = call.argument<ByteArray>("y")
                    val uBytes = call.argument<ByteArray>("u")
                    val vBytes = call.argument<ByteArray>("v")
                    val yRowStride = call.argument<Int>("yRowStride")
                    val uRowStride = call.argument<Int>("uRowStride")
                    val vRowStride = call.argument<Int>("vRowStride")
                    val uPixelStride = call.argument<Int>("uPixelStride")
                    val vPixelStride = call.argument<Int>("vPixelStride")
                    val sensorOrientation = call.argument<Int>("sensorOrientation") ?: 90

                    if (width != null && height != null && yBytes != null && uBytes != null && vBytes != null &&
                        yRowStride != null && uRowStride != null && vRowStride != null &&
                        uPixelStride != null && vPixelStride != null
                    ) {
                        executor.execute {
                            try {
                                val (inputBuffer, bitmap) = frameProcessor.preprocessFrame(
                                    width, height, yBytes, uBytes, vBytes,
                                    yRowStride, uRowStride, vRowStride, uPixelStride, vPixelStride,
                                    sensorOrientation
                                )
                                val detections = yoloDetector.detect(inputBuffer)
                                val trackedObjects = vehicleTracker.track(detections)

                                val results = trackedObjects.map { obj ->
                                    mapOf(
                                        "label" to obj.label,
                                        "confidence" to obj.confidence.toDouble(),
                                        "boundingBox" to listOf(
                                            obj.boundingBox.left.toDouble(),
                                            obj.boundingBox.top.toDouble(),
                                            (obj.boundingBox.right - obj.boundingBox.left).toDouble(),
                                            (obj.boundingBox.bottom - obj.boundingBox.top).toDouble()
                                        ),
                                        "estimatedDistance" to obj.estimatedDistance,
                                        "isApproaching" to obj.isApproaching,
                                        "distanceCategory" to obj.distanceCategory
                                    )
                                }
                                latestDetections = results
                                bitmap.recycle()

                                // Return the results to Flutter on the main thread
                                mainHandler.post {
                                    result.success(results)
                                }
                            } catch (e: Exception) {
                                Log.e("MainActivity", "Error processing frame: ${e.message}", e)
                                mainHandler.post {
                                    result.error("PROCESSING_ERROR", e.message, null)
                                }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing arguments for processFrame", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        executor.shutdown()
        yoloDetector.close()
        super.onDestroy()
    }
}

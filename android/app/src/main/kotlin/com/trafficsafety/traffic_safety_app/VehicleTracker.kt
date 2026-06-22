package com.trafficsafety.traffic_safety_app

import android.graphics.RectF
import java.util.UUID

// Tracked vehicle class
data class TrackedObject(
    val id: String,
    var label: String,
    var confidence: Float,
    var boundingBox: RectF,
    var estimatedDistance: Double,
    var isApproaching: Boolean,
    var lastSeenFrame: Long,
    var distanceCategory: String = "far",
    var areaGrowthStreak: Int = 0
)

class VehicleTracker {
    private val TAG = "VehicleTracker"
    private var frameCount: Long = 0
    private val trackedObjects = ArrayList<TrackedObject>()
    
    // Configurable thresholds
    private val maxFrameAge = 5L // remove objects if not seen for 5 frames
    private val matchIoUThreshold = 0.25f // minimum IoU to consider a match

    fun track(detections: List<Detection>): List<TrackedObject> {
        frameCount++
        
        val newTrackedList = ArrayList<TrackedObject>()
        val matchedDetectionIndices = BooleanArray(detections.size)
        
        // 1. Try to match current detections with existing tracked objects
        for (tracked in trackedObjects) {
            var bestDetectionIndex = -1
            var bestIoU = matchIoUThreshold
            
            for (i in detections.indices) {
                if (matchedDetectionIndices[i]) continue
                val detection = detections[i]
                
                // Must be the same label to match (case-insensitive)
                if (detection.label.equals(tracked.label, ignoreCase = true)) {
                    val iou = calculateIoU(tracked.boundingBox, detection.boundingBox)
                    if (iou > bestIoU) {
                        bestIoU = iou
                        bestDetectionIndex = i
                    }
                }
            }
            
            if (bestDetectionIndex != -1) {
                // We found a match! Update the tracked object.
                matchedDetectionIndices[bestDetectionIndex] = true
                val detection = detections[bestDetectionIndex]
                
                // Calculate distance before updating coordinates
                val currentDistance = estimateDistance(detection.boundingBox, detection.label)
                
                // Estimate motion direction using bounding box area change
                val currentArea = detection.boundingBox.width() * detection.boundingBox.height()
                val previousArea = tracked.boundingBox.width() * tracked.boundingBox.height()
                
                if (currentArea > previousArea * 1.04f) {
                    tracked.areaGrowthStreak++
                } else {
                    tracked.areaGrowthStreak = 0
                }
                
                // Approaching if area grows by > 4% over at least 2 consecutive frames
                tracked.isApproaching = tracked.areaGrowthStreak >= 2
                
                // Smooth distance using a running average (alpha = 0.6 for new value)
                tracked.estimatedDistance = 0.4 * tracked.estimatedDistance + 0.6 * currentDistance
                
                // Update distance category
                tracked.distanceCategory = getDistanceCategory(detection.boundingBox, detection.label)
                
                tracked.boundingBox = detection.boundingBox
                tracked.confidence = detection.confidence
                tracked.label = detection.label // keep label updated
                tracked.lastSeenFrame = frameCount
                newTrackedList.add(tracked)
            } else {
                // Not matched. If it was seen recently, keep it (decay memory)
                if (frameCount - tracked.lastSeenFrame < maxFrameAge) {
                    newTrackedList.add(tracked)
                }
            }
        }
        
        // 2. Add unmatched detections as new tracked objects
        for (i in detections.indices) {
            if (matchedDetectionIndices[i]) continue
            val detection = detections[i]
            val distance = estimateDistance(detection.boundingBox, detection.label)
            val category = getDistanceCategory(detection.boundingBox, detection.label)
            val newTrack = TrackedObject(
                id = UUID.randomUUID().toString(),
                label = detection.label,
                confidence = detection.confidence,
                boundingBox = detection.boundingBox,
                estimatedDistance = distance,
                isApproaching = true, // Default to approaching for warning safety
                lastSeenFrame = frameCount,
                distanceCategory = category,
                areaGrowthStreak = 0
            )
            newTrackedList.add(newTrack)
        }
        
        trackedObjects.clear()
        trackedObjects.addAll(newTrackedList)
        return trackedObjects
    }
    
    // Heuristic distance estimation in meters based on height or width of bounding box
    private fun estimateDistance(box: RectF, label: String): Double {
        val height = box.height()
        
        return when {
            label.equals("Pedestrian", ignoreCase = true) -> {
                val focalFactor = 5.0
                (1.7 * focalFactor) / height
            }
            label.equals("car", ignoreCase = true) -> {
                // Custom physics-based formula for passenger cars: 7.0 / heightRatio
                7.0 / height
            }
            label.equals("Motorcycle", ignoreCase = true) || label.equals("Bicycle", ignoreCase = true) -> {
                val focalFactor = 5.5
                (1.4 * focalFactor) / height
            }
            label.equals("Truck", ignoreCase = true) -> {
                val focalFactor = 7.0
                (3.0 * focalFactor) / height
            }
            else -> {
                val focalFactor = 5.0
                (1.5 * focalFactor) / height
            }
        }.toDouble().coerceIn(0.5, 80.0) // Clamp to reasonable ranges
    }

    // Determine distance category natively based on bounding box height ratio or general distance
    private fun getDistanceCategory(box: RectF, label: String): String {
        if (label.equals("car", ignoreCase = true)) {
            val heightRatio = box.height()
            return when {
                heightRatio > 0.48f -> "very_close"  // Distance < 6 meters (ratio > 0.48)
                heightRatio > 0.28f -> "close"       // Distance 6 - 12 meters
                heightRatio > 0.12f -> "medium"      // Distance 12 - 25 meters
                else -> "far"
            }
        } else {
            val distance = estimateDistance(box, label)
            return when {
                distance < 5.0 -> "very_close"
                distance < 15.0 -> "close"
                distance < 25.0 -> "medium"
                else -> "far"
            }
        }
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
}

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
    var lastSeenFrame: Long
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
                
                // Must be the same label to match
                if (detection.label == tracked.label) {
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
                
                // Estimate motion direction: if distance decreased, it's approaching.
                // We also check bounding box area increase as a secondary check.
                val prevArea = (tracked.boundingBox.right - tracked.boundingBox.left) * (tracked.boundingBox.bottom - tracked.boundingBox.top)
                val currArea = (detection.boundingBox.right - detection.boundingBox.left) * (detection.boundingBox.bottom - detection.boundingBox.top)
                
                val distanceDecreasing = currentDistance < tracked.estimatedDistance
                val areaIncreasing = currArea > prevArea
                
                // A combination of both metrics for robust determination
                tracked.isApproaching = distanceDecreasing || (areaIncreasing && Math.abs(currentDistance - tracked.estimatedDistance) < 2.0)
                
                // Smooth distance using a running average (alpha = 0.6 for new value)
                tracked.estimatedDistance = 0.4 * tracked.estimatedDistance + 0.6 * currentDistance
                
                tracked.boundingBox = detection.boundingBox
                tracked.confidence = detection.confidence
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
            val newTrack = TrackedObject(
                id = UUID.randomUUID().toString(),
                label = detection.label,
                confidence = detection.confidence,
                boundingBox = detection.boundingBox,
                estimatedDistance = distance,
                isApproaching = true, // Default to approaching for warning safety
                lastSeenFrame = frameCount
            )
            newTrackedList.add(newTrack)
        }
        
        trackedObjects.clear()
        trackedObjects.addAll(newTrackedList)
        return trackedObjects
    }
    
    // Heuristic distance estimation in meters based on height or width of bounding box
    private fun estimateDistance(box: RectF, label: String): Double {
        val width = box.right - box.left
        val height = box.bottom - box.top
        
        // Standard heights/widths of classes in meters (assumed prior knowledge)
        // Focal length multiplier based on typical mobile camera field of view (approx 60 deg)
        // Distance = (RealDimension * FocalLengthFactor) / BoundingBoxDimension
        
        return when (label) {
            "Pedestrian" -> {
                // Real height: ~1.7 meters.
                val focalFactor = 5.0
                (1.7 * focalFactor) / height
            }
            "Car" -> {
                // Real width: ~1.8 meters, real height: ~1.5 meters.
                val focalFactor = 6.0
                (1.5 * focalFactor) / height
            }
            "Motorcycle", "Bicycle" -> {
                val focalFactor = 5.5
                (1.4 * focalFactor) / height
            }
            "Truck" -> {
                // Real height: ~3.0 meters
                val focalFactor = 7.0
                (3.0 * focalFactor) / height
            }
            else -> {
                val focalFactor = 5.0
                (1.5 * focalFactor) / height
            }
        }.coerceIn(0.5, 80.0) // Clamp to reasonable ranges
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

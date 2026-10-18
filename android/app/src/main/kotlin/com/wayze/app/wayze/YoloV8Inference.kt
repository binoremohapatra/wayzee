package com.wayze.app.wayze

import android.content.Context
import org.tensorflow.lite.Interpreter
import org.tensorflow.lite.support.common.FileUtil
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel
import kotlin.math.max
import kotlin.math.min

data class DetectionResult(
    val label: String,
    val confidence: Float,
    val zone: String,
    val boxArea: Float,
    val bottomY: Float,
    val timestamp: Long
)

class YoloV8Inference(
    private val context: Context,
    private val modelPath: String = "models/yolov8n_int8_320.tflite",
    numThreads: Int = 2
) {
    private var interpreter: Interpreter? = null
    private val inputSize = 320
    private val hfovDegrees = 65.0f

    // Standard indoor navigation & hazard classes (custom Wayze + COCO subset)
    private val defaultLabels = listOf(
        "door", "stairs_up", "stairs_down", "person", "chair",
        "table", "obstacle", "drop_off", "sign", "elevator"
    )

    init {
        initializeInterpreter(numThreads)
    }

    private fun initializeInterpreter(threads: Int) {
        try {
            val options = Interpreter.Options().apply {
                setNumThreads(threads)
                // Use XNNPACK delegate for optimal INT8 acceleration on ARM Cortex CPUs
                setUseXNNPACK(true)
            }
            val modelBuffer = loadModelFile(modelPath)
            interpreter = Interpreter(modelBuffer, options)
        } catch (e: Exception) {
            // Fallback: try loading alternative model from assets if specific path not found
            try {
                val fallbackBuffer = loadModelFile("models/wayze.tflite")
                interpreter = Interpreter(fallbackBuffer, Interpreter.Options().apply {
                    setNumThreads(threads)
                    setUseXNNPACK(true)
                })
            } catch (_: Exception) {
                // If model file is missing during test or stub runs, interpreter remains null
                interpreter = null
            }
        }
    }

    private fun loadModelFile(path: String): ByteBuffer {
        val assetManager = context.assets
        val fileDescriptor = assetManager.openFd(path)
        val inputStream = FileInputStream(fileDescriptor.fileDescriptor)
        val fileChannel = inputStream.channel
        val startOffset = fileDescriptor.startOffset
        val declaredLength = fileDescriptor.declaredLength
        return fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength)
    }

    fun updateThreadCount(newThreads: Int) {
        interpreter?.close()
        initializeInterpreter(newThreads)
    }

    /**
     * Executes inference on the preprocessed 320x320 INT8 buffer.
     * The image buffer is strictly consumed in RAM and never saved or transmitted.
     */
    fun processFrame(
        inputBuffer: ByteBuffer,
        confidenceThreshold: Float = 0.25f,
        iouThreshold: Float = 0.45f
    ): List<DetectionResult> {
        val tflite = interpreter ?: return emptyList()

        // Output tensor shape for YOLOv8 320x320: [1, 4 + numClasses, 2100]
        val numClasses = defaultLabels.size
        val numPredictions = 2100
        val outputArray = Array(1) { Array(4 + numClasses) { FloatArray(numPredictions) } }

        inputBuffer.rewind()
        tflite.run(inputBuffer, outputArray)

        val rawDetections = mutableListOf<RawBox>()
        val predictions = outputArray[0]

        for (i in 0 until numPredictions) {
            var maxScore = 0f
            var bestClassIndex = -1

            for (c in 0 until numClasses) {
                val score = predictions[4 + c][i]
                if (score > maxScore) {
                    maxScore = score
                    bestClassIndex = c
                }
            }

            if (maxScore >= confidenceThreshold && bestClassIndex >= 0) {
                val cx = predictions[0][i] / inputSize.toFloat()
                val cy = predictions[1][i] / inputSize.toFloat()
                val w = predictions[2][i] / inputSize.toFloat()
                val h = predictions[3][i] / inputSize.toFloat()

                val x1 = max(0f, cx - w / 2f)
                val y1 = max(0f, cy - h / 2f)
                val x2 = min(1f, cx + w / 2f)
                val y2 = min(1f, cy + h / 2f)

                rawDetections.add(
                    RawBox(
                        x1 = x1,
                        y1 = y1,
                        x2 = x2,
                        y2 = y2,
                        score = maxScore,
                        classIndex = bestClassIndex
                    )
                )
            }
        }

        // Apply Non-Maximum Suppression (NMS)
        val nmsBoxes = applyNMS(rawDetections, iouThreshold)
        val now = System.currentTimeMillis()

        return nmsBoxes.map { box ->
            val centerX = (box.x1 + box.x2) / 2f
            val boxWidth = (box.x2 - box.x1)
            val boxHeight = (box.y2 - box.y1)
            val area = boxWidth * boxHeight
            val bottomY = box.y2

            // Zone mapping from horizontal center bearing
            val bearing = (centerX - 0.5f) * hfovDegrees
            val zone = when {
                bearing < -12.0f -> "left"
                bearing > 12.0f -> "right"
                else -> "center"
            }

            DetectionResult(
                label = defaultLabels.getOrElse(box.classIndex) { "obstacle" },
                confidence = box.score,
                zone = zone,
                boxArea = area,
                bottomY = bottomY,
                timestamp = now
            )
        }
    }

    private fun applyNMS(boxes: List<RawBox>, iouThreshold: Float): List<RawBox> {
        val sorted = boxes.sortedByDescending { it.score }.toMutableList()
        val selected = mutableListOf<RawBox>()

        while (sorted.isNotEmpty()) {
            val first = sorted.removeAt(0)
            selected.add(first)

            val iterator = sorted.iterator()
            while (iterator.hasNext()) {
                val next = iterator.next()
                if (first.classIndex == next.classIndex && calculateIoU(first, next) > iouThreshold) {
                    iterator.remove()
                }
            }
        }
        return selected
    }

    private fun calculateIoU(a: RawBox, b: RawBox): Float {
        val interX1 = max(a.x1, b.x1)
        val interY1 = max(a.y1, b.y1)
        val interX2 = min(a.x2, b.x2)
        val interY2 = min(a.y2, b.y2)

        val interArea = max(0f, interX2 - interX1) * max(0f, interY2 - interY1)
        val aArea = (a.x2 - a.x1) * (a.y2 - a.y1)
        val bArea = (b.x2 - b.x1) * (b.y2 - b.y1)

        val unionArea = aArea + bArea - interArea
        return if (unionArea > 0f) interArea / unionArea else 0f
    }

    fun close() {
        interpreter?.close()
        interpreter = null
    }

    private data class RawBox(
        val x1: Float,
        val y1: Float,
        val x2: Float,
        val y2: Float,
        val score: Float,
        val classIndex: Int
    )
}

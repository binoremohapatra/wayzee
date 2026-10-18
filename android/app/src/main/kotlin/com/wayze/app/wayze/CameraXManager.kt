package com.wayze.app.wayze

import android.content.Context
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min

data class FrameQuality(
    val meanLuminance: Float,
    val varianceLuminance: Float,
    val isDark: Boolean,
    val isBlocked: Boolean
)

class CameraXManager(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner,
    private val inference: YoloV8Inference,
    private val onDetectionsReady: (List<DetectionResult>, Long, FrameQuality) -> Unit
) {
    private val backgroundExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var imageAnalysis: ImageAnalysis? = null

    // Target input dimensions
    private val targetSize = 320

    // Reusable direct byte buffer (1 * 320 * 320 * 3 bytes) to eliminate per-frame allocations
    private val inputBuffer: ByteBuffer = ByteBuffer.allocateDirect(1 * targetSize * targetSize * 3).apply {
        order(ByteOrder.nativeOrder())
    }

    // Adaptive FPS throttling
    @Volatile
    private var minFrameIntervalMs: Long = 100L // 10 FPS default
    private var lastInferenceTimeMs: Long = 0L

    fun setAdaptiveFps(isStationary: Boolean) {
        minFrameIntervalMs = if (isStationary) {
            250L // 4 FPS when stationary to preserve thermal budget
        } else {
            100L // 10 FPS active walking navigation
        }
    }

    fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            val cameraProvider = cameraProviderFuture.get()

            imageAnalysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_YUV_420_888)
                .build()
                .also { analysis ->
                    analysis.setAnalyzer(backgroundExecutor) { imageProxy ->
                        processImageProxy(imageProxy)
                    }
                }

            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

            try {
                cameraProvider.unbindAll()
                cameraProvider.bindToLifecycle(
                    lifecycleOwner,
                    cameraSelector,
                    imageAnalysis
                )
            } catch (_: Exception) {}
        }, ContextCompat.getMainExecutor(context))
    }

    private fun processImageProxy(imageProxy: ImageProxy) {
        val currentTime = System.currentTimeMillis()
        if (currentTime - lastInferenceTimeMs < minFrameIntervalMs) {
            // Drop frame to maintain target FPS without allocating memory
            imageProxy.close()
            return
        }
        lastInferenceTimeMs = currentTime

        try {
            val startTime = System.currentTimeMillis()

            // Preprocess YUV to RGB Letterbox into preallocated inputBuffer
            val frameQuality = preprocessYuvToLetterbox(imageProxy, inputBuffer)

            // Execute INT8 inference
            val results = inference.processFrame(inputBuffer)
            val elapsedMs = System.currentTimeMillis() - startTime

            onDetectionsReady(results, elapsedMs, frameQuality)
        } catch (_: Exception) {
        } finally {
            // Frame is strictly processed in RAM and closed immediately. Never stored.
            imageProxy.close()
        }
    }

    /**
     * Converts YUV_420_888 planes into normalized 320x320 RGB letterbox bytes.
     * Computes luminance mean and variance heuristics purely in RAM without storing frames.
     */
    private fun preprocessYuvToLetterbox(imageProxy: ImageProxy, output: ByteBuffer): FrameQuality {
        output.rewind()

        val planes = imageProxy.planes
        val yPlane = planes[0].buffer
        val uPlane = planes[1].buffer
        val vPlane = planes[2].buffer

        val srcWidth = imageProxy.width
        val srcHeight = imageProxy.height
        val yRowStride = planes[0].rowStride
        val uvRowStride = planes[1].rowStride
        val uvPixelStride = planes[1].pixelStride

        // Fast nearest-neighbor subsampling directly into target buffer
        val scaleX = srcWidth.toFloat() / targetSize.toFloat()
        val scaleY = srcHeight.toFloat() / targetSize.toFloat()

        var sumY: Long = 0L
        var sumYsq: Long = 0L
        val totalPixels = targetSize * targetSize

        for (targetY in 0 until targetSize) {
            val srcY = min(srcHeight - 1, (targetY * scaleY).toInt())
            val uvRow = srcY shr 1

            for (targetX in 0 until targetSize) {
                val srcX = min(srcWidth - 1, (targetX * scaleX).toInt())
                val uvCol = srcX shr 1

                val yIndex = srcY * yRowStride + srcX
                val uvIndex = uvRow * uvRowStride + uvCol * uvPixelStride

                val yVal = (yPlane.get(yIndex).toInt() and 0xFF)
                val uVal = (uPlane.get(uvIndex).toInt() and 0xFF) - 128
                val vVal = (vPlane.get(uvIndex).toInt() and 0xFF) - 128

                sumY += yVal
                sumYsq += (yVal.toLong() * yVal.toLong())

                // ITU-R BT.601 conversion
                val r = min(255, max(0, (yVal + 1.402f * vVal).toInt()))
                val g = min(255, max(0, (yVal - 0.344136f * uVal - 0.714136f * vVal).toInt()))
                val b = min(255, max(0, (yVal + 1.772f * uVal).toInt()))

                // INT8 quantization centered around zero [-128..127]
                output.put((r - 128).toByte())
                output.put((g - 128).toByte())
                output.put((b - 128).toByte())
            }
        }

        val meanY = sumY.toFloat() / totalPixels.toFloat()
        val varianceY = (sumYsq.toFloat() / totalPixels.toFloat()) - (meanY * meanY)
        val isDark = meanY < 20.0f
        val isBlocked = varianceY < 5.0f && meanY < 45.0f

        return FrameQuality(
            meanLuminance = meanY,
            varianceLuminance = varianceY,
            isDark = isDark,
            isBlocked = isBlocked
        )
    }

    fun stopCamera() {
        imageAnalysis?.clearAnalyzer()
        imageAnalysis = null
        backgroundExecutor.shutdown()
    }
}

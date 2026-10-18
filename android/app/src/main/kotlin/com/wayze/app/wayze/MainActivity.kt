package com.wayze.app.wayze

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.view.KeyEvent
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val SERVICE_CHANNEL = "com.wayze/service"
    private val VISION_EVENT_CHANNEL = "com.wayze/vision_stream"
    private val HARDWARE_KEY_CHANNEL = "com.wayze/hardware_keys"

    private var visionEventSink: EventChannel.EventSink? = null
    private var hardwareKeyEventSink: EventChannel.EventSink? = null

    private var yoloInference: YoloV8Inference? = null
    private var cameraXManager: CameraXManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Service control channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SERVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startForegroundService" -> {
                        startWayzeService()
                        result.success(true)
                    }
                    "stopForegroundService" -> {
                        stopWayzeService()
                        result.success(true)
                    }
                    "startVision" -> {
                        startVisionPipeline()
                        result.success(true)
                    }
                    "stopVision" -> {
                        stopVisionPipeline()
                        result.success(true)
                    }
                    "setStationary" -> {
                        val isStationary = call.argument<Boolean>("isStationary") ?: false
                        cameraXManager?.setAdaptiveFps(isStationary)
                        result.success(true)
                    }
                    "getThermalStatus" -> {
                        val thermalStatus = getDeviceThermalStatus()
                        result.success(thermalStatus)
                    }
                    else -> result.notImplemented()
                }
            }

        // 2. Vision stream EventChannel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VISION_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    visionEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    visionEventSink = null
                }
            })

        // 3. Hardware keys EventChannel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, HARDWARE_KEY_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    hardwareKeyEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    hardwareKeyEventSink = null
                }
            })
    }

    private fun startWayzeService() {
        val serviceIntent = Intent(this, WayzeForegroundService::class.java).apply {
            action = WayzeForegroundService.ACTION_START
        }
        ContextCompat.startForegroundService(this, serviceIntent)
    }

    private fun stopWayzeService() {
        val serviceIntent = Intent(this, WayzeForegroundService::class.java).apply {
            action = WayzeForegroundService.ACTION_STOP
        }
        startService(serviceIntent)
    }

    private fun startVisionPipeline() {
        if (cameraXManager != null) return

        yoloInference = YoloV8Inference(this)
        cameraXManager = CameraXManager(
            context = this,
            lifecycleOwner = this,
            inference = yoloInference!!
        ) { detections, latencyMs, frameQuality ->
            runOnUiThread {
                val mappedList = detections.map { d ->
                    mapOf(
                        "label" to d.label,
                        "confidence" to d.confidence.toDouble(),
                        "zone" to d.zone,
                        "boxArea" to d.boxArea.toDouble(),
                        "bottomY" to d.bottomY.toDouble(),
                        "timestamp" to d.timestamp,
                        "latencyMs" to latencyMs,
                        "x1" to d.x1.toDouble(),
                        "y1" to d.y1.toDouble(),
                        "x2" to d.x2.toDouble(),
                        "y2" to d.y2.toDouble()
                    )
                }
                val payload = mapOf(
                    "detections" to mappedList,
                    "quality" to mapOf(
                        "meanLuminance" to frameQuality.meanLuminance.toDouble(),
                        "varianceLuminance" to frameQuality.varianceLuminance.toDouble(),
                        "isDark" to frameQuality.isDark,
                        "isBlocked" to frameQuality.isBlocked,
                        "timestamp" to System.currentTimeMillis()
                    )
                )
                visionEventSink?.success(payload)
            }
        }
        cameraXManager?.startCamera()
    }

    private fun stopVisionPipeline() {
        cameraXManager?.stopCamera()
        cameraXManager = null
        yoloInference?.close()
        yoloInference = null
    }

    private fun getDeviceThermalStatus(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.currentThermalStatus
        } else {
            0 // PowerManager.THERMAL_STATUS_NONE
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        return when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> {
                hardwareKeyEventSink?.success("VOLUME_UP_VOICE_TRIGGER")
                true
            }
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                hardwareKeyEventSink?.success("VOLUME_DOWN_REPEAT_GUIDANCE")
                true
            }
            else -> super.onKeyDown(keyCode, event)
        }
    }

    override fun onDestroy() {
        stopVisionPipeline()
        super.onDestroy()
    }
}

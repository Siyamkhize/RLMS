package com.example.rlmss

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.Log
import com.zkteco.android.biometric.core.device.ParameterHelper
import com.zkteco.android.biometric.core.device.TransportType
import com.zkteco.android.biometric.core.utils.LogHelper
import com.zkteco.android.biometric.module.fingerprint.FingerprintCaptureListener
import com.zkteco.android.biometric.module.fingerprint.FingerprintFactory
import com.zkteco.android.biometric.module.fingerprint.FingerprintSensor
import com.zkteco.android.biometric.module.fingerprint.exception.FingerprintSensorException
import com.zkteco.android.biometric.module.fingerprintreader.ZKFingerService
// Server-side inference - no TensorFlow Lite imports needed
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean
// Import Futronic SDK classes
import com.futronictech.AnsiSDKLib
import com.futronictech.UsbDeviceDataExchangeImpl
import io.flutter.plugin.common.MethodCall

class MainActivity : FlutterActivity() {
    private lateinit var methodChannel: MethodChannel
    private var fingerprintSensor: FingerprintSensor? = null
    private var usbManager: UsbManager? = null
    private var usbReceiver: BroadcastReceiver? = null
    private var currentOperation: String? = null

    private var isScannerConnected = false
    private var isRegistering = false
    private var isCapturing = false
    private var isVerifying = false
    private var verificationResult: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val isInitialized = AtomicBoolean(false)
    private val FUTRONIC_CHANNEL = "futronic_channel"
    
    // Futronic SDK objects - create once and reuse
    private var futronicUsbContext: UsbDeviceDataExchangeImpl? = null
    private val futronicHandler = Handler(Looper.getMainLooper())

    companion object {
        private const val TAG = "MainActivity"
        private const val METHOD_CHANNEL = "com.example.rlmss/fingerprint"
        private const val ZKTECO_VID = 6997
        private const val SLK20M_PID = 289
        private const val ACTION_USB_PERMISSION = "com.example.rlmss.USB_PERMISSION"
        private const val CAPTURE_TIMEOUT_MS = 3000L  // Reduced to 3s for ultra-fast 1:N verification
                private const val MIN_MATCH_SCORE = 92  // Reduced from 95 for better real-world usability  // Increased threshold for stricter 1:N verification to prevent false positives
        // Minimum acceptable template size (bytes) to consider a capture as a full fingerprint
        // Set conservatively to avoid rejecting valid templates while still filtering obvious partials
        private const val MIN_TEMPLATE_SIZE_BYTES = 200
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "--- MainActivity onCreate START ---")
        LogHelper.setLevel(Log.VERBOSE)
        LogHelper.setNDKLogLevel(Log.VERBOSE)
        usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
        setupContactlessChannel() // <-- Add this line
        setupUsbReceiver()
        initDevice()
        
        // Initialize Futronic USB context on main thread with better error handling
        initializeFutronicUsbContext()
    }

    private fun initializeFutronicUsbContext() {
        try {
            Log.d(TAG, "=== Enhanced Futronic USB Context Initialization ===")
            Log.d(TAG, "Device: ${android.os.Build.MODEL} (${android.os.Build.MANUFACTURER})")
            Log.d(TAG, "Android version: ${android.os.Build.VERSION.RELEASE}")
            
            // Clean up any existing context first
            futronicUsbContext?.let {
                try {
                    it.CloseDevice()
                    it.Destroy()
                    Log.d(TAG, "Cleaned up existing Futronic USB context")
                } catch (e: Exception) {
                    Log.e(TAG, "Error cleaning up existing context: ${e.message}")
                }
            }
            
            Log.d(TAG, "Creating new Futronic USB context...")
            futronicUsbContext = UsbDeviceDataExchangeImpl(this, futronicHandler)
            Log.d(TAG, "Futronic USB context created: ${futronicUsbContext != null}")
            
            // Enhanced validation with multiple checks
            futronicUsbContext?.let { context ->
                try {
                    Log.d(TAG, "Performing enhanced USB context validation...")
                    
                    // Check 1: Basic validation
                    val testResult = context.ValidateContext()
                    Log.d(TAG, "Basic validation result: $testResult")
                    
                    // Check 2: USB manager check
                    val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
                    val devices = usbManager.deviceList
                    Log.d(TAG, "USB devices available: ${devices.size}")
                    
                    // Check 3: Try to get device info without opening
                    try {
                        val deviceInfo = context.GetDeviceInfo(ByteArray(0))
                        Log.d(TAG, "Device info check: $deviceInfo")
                    } catch (e: Exception) {
                        Log.d(TAG, "Device info not available (normal): ${e.message}")
                    }
                    
                    Log.d(TAG, "Futronic USB context validation completed successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "Enhanced validation failed: ${e.message}")
                    Log.d(TAG, "Context still usable, validation failure is not critical")
                    // Don't null the context as validation can fail but context may still work
                }
            }
            
            Log.d(TAG, "=== Futronic USB Context Initialization Complete ===")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Futronic USB context: ${e.message}", e)
            futronicUsbContext = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Existing ZKTeco channel setup (if any)
        flutterEngine.dartExecutor.binaryMessenger.let { messenger ->
            methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
            methodChannel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSensorConnected" -> checkSensorConnection(result)
                    "startEnrollment" -> {
                        val finger = call.argument<String>("finger") ?: "unknown"
                        startEnrollment(finger, result)
                    }
                    "cancelEnrollment" -> cancelEnrollment(result)
                    "resetSensor" -> resetSensor(result)
                    "verify" -> {
                        val finger = call.argument<String>("finger") ?: "unknown"
                        val template = call.argument<String>("template") ?: ""
                        Log.d(TAG, "[VERIFY] Received verify request - finger: $finger, template length: ${template.length}")
                        Log.d(TAG, "[VERIFY] Current sensor state - isScannerConnected: $isScannerConnected, fingerprintSensor: ${fingerprintSensor != null}")
                        
                        if (!isScannerConnected || fingerprintSensor == null) {
                            Log.e(TAG, "[VERIFY] Sensor not connected or null")
                            result.error("SENSOR_NOT_CONNECTED", "ZKTeco sensor is not connected", null)
                            return@setMethodCallHandler
                        }
                        
                        // Use startVerificationFlow for proper fingerprint capture and verification
                        startVerificationFlow(template, null, result)
                    }
                    "startCapture" -> startSimpleCapture(result)
                    "matchTemplates" -> {
                        val storedTemplate = call.argument<String>("storedTemplate")
                        val scannedTemplate = call.argument<String>("scannedTemplate")
                        if (storedTemplate != null && scannedTemplate != null) {
                            matchTemplates(storedTemplate, scannedTemplate, result)
                        } else {
                            result.error("INVALID_ARGS", "Both storedTemplate and scannedTemplate are required", null)
                        }
                    }
                    "verifyFingerprint" -> {
                        val storedTemplate1 = call.argument<String>("storedTemplate1")
                        val storedTemplate2 = call.argument<String>("storedTemplate2") // Can be null
                        if (storedTemplate1 != null) {
                            startVerificationFlow(storedTemplate1, storedTemplate2, result)
                        } else {
                            result.error("INVALID_ARGS", "At least one stored template is required.", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
        // Add Futronic platform channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FUTRONIC_CHANNEL).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "enroll" -> {
                    val finger = call.argument<String>("finger") ?: "left"
                    enrollWithFutronic(finger, result)
                }
                "verify" -> {
                    val finger = call.argument<String>("finger") ?: "left"
                    val template = call.argument<String>("template") ?: ""
                    verifyWithFutronic(finger, template, result)
                }
                // New method: single capture, verify against left and right templates
                "verifyBoth" -> {
                    val hintFinger = call.argument<String>("hintFinger") ?: "left"
                    val templateLeft = call.argument<String>("templateLeft")
                    val templateRight = call.argument<String>("templateRight")
                    verifyWithFutronicBoth(hintFinger, templateLeft, templateRight, result)
                }
                "isFutronicConnected" -> {
                    isFutronicConnected(result)
                }
                else -> result.notImplemented()
            }
        }
    }



    private fun setupContactlessChannel() {
        val CONTACTLESS_CHANNEL = "com.example.rlmss/contactless_fingerprint"
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, CONTACTLESS_CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "matchContactlessFingerprint" -> {
                        Log.d(TAG, "[CONTACTLESS] Server-side inference is now used. This method is deprecated.")
                        result.error("DEPRECATED", "Use server-side inference for contactless matching", null)
                    }
                    "extractFingerprintFeatures" -> {
                        Log.d(TAG, "[CONTACTLESS] Server-side inference is now used. This method is deprecated.")
                        result.error("DEPRECATED", "Use server-side inference for feature extraction", null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    // Server-side inference - these methods are no longer used locally

    private fun isBusy(): Boolean {
        return isRegistering || isCapturing || isVerifying
    }

    private fun startVerificationFlow(template1: String, template2: String?, flutterResult: MethodChannel.Result) {
        if (isBusy()) {
            flutterResult.error("BUSY", "Another operation is in progress.", null)
            return
        }
        if (!isScannerConnected) {
            flutterResult.error("NOT_CONNECTED", "Fingerprint scanner is not connected.", null)
            return
        }

        isVerifying = true
        currentOperation = "verify"
        this.verificationResult = flutterResult // Store the result callback

        invokeOnMainThread("onStatusChanged", "Place finger on scanner to verify...")
        
        // Add timeout for verification
        mainHandler.postDelayed({
            if (isVerifying) {
                Log.w(TAG, "[VERIFY] Verification timeout - no response from sensor")
                verificationResult?.error("TIMEOUT", "Verification timeout - please try again", null)
                finishOperation()
            }
        }, 30000) // 30 second timeout

        try {
            Log.d(TAG, "[VERIFY] Starting verification flow with template length: ${template1.length}")
            Log.d(TAG, "[VERIFY] Sensor state before open: ${fingerprintSensor != null}")
            
            fingerprintSensor?.open(0)
            Log.d(TAG, "[VERIFY] Sensor opened successfully")

            val captureListener = object : FingerprintCaptureListener {
                override fun captureOK(mode: Int, rawImage: ByteArray?, attributes: IntArray?, fpTemplate: ByteArray?) {
                    Log.d(TAG, "[VERIFY] captureOK called - mode: $mode, template size: ${fpTemplate?.size ?: 0}")
                    if (fpTemplate != null) {
                        var matchFound = false
                        try {
                            val storedTemplate1 = Base64.decode(template1, Base64.DEFAULT)
                            val score1 = ZKFingerService.verify(storedTemplate1, fpTemplate)
                            Log.d(TAG, "Verification score against template 1: $score1")
                            if (score1 > MIN_MATCH_SCORE) {
                                matchFound = true
                            }

                            if (!matchFound && template2 != null) {
                                val storedTemplate2 = Base64.decode(template2, Base64.DEFAULT)
                                val score2 = ZKFingerService.verify(storedTemplate2, fpTemplate)
                                Log.d(TAG, "Verification score against template 2: $score2")
                                if (score2 > MIN_MATCH_SCORE) {
                                    matchFound = true
                                }
                            }
                            mainHandler.post { verificationResult?.success(matchFound) }
                        } catch (e: IllegalArgumentException) {
                            Log.e(TAG, "Error decoding Base64 template", e)
                            mainHandler.post { verificationResult?.error("INVALID_TEMPLATE", "Invalid Base64 template string.", null) }
                        } finally {
                            finishOperation()
                        }
                    } else {
                        mainHandler.post { verificationResult?.error("EXTRACTION_FAILED", "Failed to extract template. Please try again.", null) }
                        finishOperation()
                    }
                }

                override fun captureError(e: FingerprintSensorException) {
                    Log.e(TAG, "[VERIFY] Fingerprint sensor exception during verification", e)
                    mainHandler.post { verificationResult?.error("SENSOR_ERROR", "Sensor error: ${e.message}", null) }
                    finishOperation()
                }
            }

            fingerprintSensor?.setFingerprintCaptureListener(0, captureListener)
            Log.d(TAG, "[VERIFY] Capture listener set successfully")
            
            fingerprintSensor?.startCapture(0)
            Log.d(TAG, "[VERIFY] Capture started successfully")

        } catch (e: FingerprintSensorException) {
            Log.e(TAG, "Failed to start verification flow", e)
            verificationResult?.error("SENSOR_ERROR", "Failed to start verification: ${e.message}", null)
            finishOperation()
        }
    }

    private fun setupUsbReceiver() {
        usbReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    ACTION_USB_PERMISSION -> {
                        synchronized(this) {
                            val device: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                            } else {
                                @Suppress("DEPRECATION")
                                intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                            }
                            if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                                device?.let { connectScanner() }
                            } else {
                                Log.w(TAG, "USB permission denied")
                                invokeOnMainThread("onStatusChanged", "USB permission denied")
                            }
                        }
                    }
                    UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                        val device: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                        }
                        if (device?.vendorId == ZKTECO_VID && device.productId == SLK20M_PID) {
                            cleanupSensor()
                        }
                    }
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(ACTION_USB_PERMISSION)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(usbReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            registerReceiver(usbReceiver, filter, RECEIVER_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(usbReceiver, filter)
        }
    }

    private fun initDevice() {
        Log.d(TAG, "Initializing device...")
        try {
            usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
            if (usbManager == null) {
                Log.e(TAG, "Failed to get USB Manager service")
                invokeOnMainThread("onStatusChanged", "Error: Could not access USB service")
                return
            }
            requestUsbPermission()
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing device", e)
            invokeOnMainThread("onStatusChanged", "Error initializing device: ${e.message}")
        }
    }

    private fun requestUsbPermission() {
        Log.d(TAG, "Requesting USB permission...")
        val deviceList = usbManager?.deviceList
        if (deviceList.isNullOrEmpty()) {
            Log.e(TAG, "No USB devices found")
            invokeOnMainThread("onStatusChanged", "No USB devices found. Please connect the fingerprint scanner.")
            return
        }

        val device = deviceList.values.find {
            it.vendorId == ZKTECO_VID && it.productId == SLK20M_PID
        }
        if (device == null) {
            Log.e(TAG, "ZKTeco fingerprint scanner not found")
            invokeOnMainThread("onStatusChanged", "Fingerprint scanner not found. Please connect a ZKTeco SLK20M device.")
            return
        }

        if (usbManager?.hasPermission(device) == true) {
            Log.d(TAG, "Already have USB permission")
            connectScanner()
        } else {
            Log.d(TAG, "Requesting USB permission...")
            val intent = Intent(ACTION_USB_PERMISSION).apply {
                setPackage(packageName)
            }
            val permissionIntent = PendingIntent.getBroadcast(
                this,
                0,
                intent,
                PendingIntent.FLAG_IMMUTABLE
            )
            usbManager?.requestPermission(device, permissionIntent)
        }
    }

    private fun connectScanner() {
        Log.d(TAG, "Connecting to scanner...")
        try {
            val param = hashMapOf(
                ParameterHelper.PARAM_KEY_VID to ZKTECO_VID,
                ParameterHelper.PARAM_KEY_PID to SLK20M_PID
            ) as Map<String, Any>
            Log.d(TAG, "Creating fingerprint sensor with params: $param")
            fingerprintSensor = FingerprintFactory.createFingerprintSensor(
                this,
                TransportType.USB,
                param
            )
            fingerprintSensor?.open(0)
            Log.d(TAG, "Fingerprint sensor created successfully")

            try {
                if (ZKFingerService.init() != 0) {
                    Log.e(TAG, "Failed to initialize ZKFingerService")
                    invokeOnMainThread("onStatusChanged", "Failed to initialize fingerprint service")
                    cleanupSensor()
                    return
                }
            } catch (e: UnsatisfiedLinkError) {
                Log.e(TAG, "Native library error: ZKFingerService.init() failed", e)
                invokeOnMainThread("onStatusChanged", "Error: Missing fingerprint library. ${e.message}")
                cleanupSensor()
                return
            }

            setupCaptureListener()
            isInitialized.set(true)
            isScannerConnected = true
            invokeOnMainThread("onStatusChanged", "Scanner Ready")
        } catch (e: FingerprintSensorException) {
            Log.e(TAG, "Scanner connection failed", e)
            invokeOnMainThread("onStatusChanged", "Error: ${e.message}")
            cleanupSensor()
        }
    }

    private fun setupCaptureListener() {
        // This is a general-purpose listener. Specific operations will override it.
    }

    private fun checkSensorConnection(result: MethodChannel.Result) {
        Log.d(TAG, "[SENSOR_CHECK] Checking sensor connection - isScannerConnected: $isScannerConnected, fingerprintSensor: ${fingerprintSensor != null}")
        if (!isScannerConnected) {
            Log.d(TAG, "[SENSOR_CHECK] Sensor not connected, attempting to initialize")
            initDevice()
            result.success(false)
        } else {
            Log.d(TAG, "[SENSOR_CHECK] Sensor already connected")
            result.success(true)
        }
    }

    private fun startSimpleCapture(result: MethodChannel.Result) {
        if (isBusy()) {
            result.error("BUSY", "Sensor is busy with another operation", null)
            return
        }
        if (!isScannerConnected) {
            result.error("NOT_CONNECTED", "Scanner is not connected", null)
            return
        }

        isCapturing = true
        currentOperation = "capture"
        var replySent = false

        val safeResultSuccess: (Any?) -> Unit = { value ->
            if (!replySent) {
                replySent = true
                result.success(value)
            }
        }
        val safeResultError: (String, String?, Any?) -> Unit = { code, msg, details ->
            if (!replySent) {
                replySent = true
                result.error(code, msg, details)
            }
        }

        invokeOnMainThread("onStatusChanged", "Place finger on scanner...")

        try {
            fingerprintSensor?.open(0)
            fingerprintSensor?.setFingerprintCaptureListener(0, object : FingerprintCaptureListener {
                override fun captureOK(mode: Int, rawImage: ByteArray?, attributes: IntArray?, fpTemplate: ByteArray?) {
                    if (!isCapturing || replySent) return
                    finishOperation()
                    if (fpTemplate == null) {
                        invokeOnMainThread("onCaptureError", "Capture failed: No template extracted.")
                        safeResultError("CAPTURE_FAILED", "No template extracted", null)
                        return
                    }
                    // Convert to WSQ format before sending to Flutter
                    val base64Template = Base64.encodeToString(fpTemplate, Base64.NO_WRAP)
                    invokeOnMainThread("onCaptureSuccess", base64Template)
                    safeResultSuccess(base64Template)
                }

                override fun captureError(e: FingerprintSensorException) {
                    if (!isCapturing || replySent) return
                    finishOperation()
                    invokeOnMainThread("onCaptureError", "Capture error: ${e.message}")
                    safeResultError("CAPTURE_ERROR", e.message, null)
                }
            })
            fingerprintSensor?.startCapture(0)

            mainHandler.postDelayed({
                if (isCapturing && !replySent) {
                    finishOperation()
                    invokeOnMainThread("onCaptureError", "Capture timed out")
                    safeResultError("TIMEOUT", "Fingerprint capture timed out", null)
                }
            }, CAPTURE_TIMEOUT_MS)
        } catch (e: FingerprintSensorException) {
            if (replySent) return
            finishOperation()
            invokeOnMainThread("onCaptureError", "Failed to start capture: ${e.message}")
            safeResultError("CAPTURE_ERROR", e.message, null)
        }
    }

    private fun startEnrollment(finger: String, result: MethodChannel.Result) {
        Log.d(TAG, "startEnrollment called: isBusy=${isBusy()}, isRegistering=$isRegistering, currentOperation=$currentOperation")
        if (isBusy()) {
            Log.e(TAG, "Enrollment failed: Sensor is busy")
            result.error("BUSY", "Sensor is busy with another operation", null)
            return
        }
        if (!isScannerConnected) {
            Log.e(TAG, "Enrollment failed: Scanner is not connected")
            result.error("NOT_CONNECTED", "Scanner is not connected", null)
            return
        }

        isRegistering = true
        currentOperation = "enroll"
        var replySent = false

        val safeResultSuccess: (Any?) -> Unit = { value ->
            if (!replySent) {
                replySent = true
                result.success(value)
            }
        }
        val safeResultError: (String, String?, Any?) -> Unit = { code, msg, details ->
            if (!replySent) {
                replySent = true
                result.error(code, msg, details)
            }
        }

        invokeOnMainThread("onEnrollStatus", "Starting enrollment for $finger. Place your finger on the scanner.")

        try {
            fingerprintSensor?.open(0)
            fingerprintSensor?.setFingerprintCaptureListener(0, object : FingerprintCaptureListener {
                override fun captureOK(mode: Int, rawImage: ByteArray?, attributes: IntArray?, fpTemplate: ByteArray?) {
                    Log.d(TAG, "captureOK called in enrollment: fpTemplate is null? ${fpTemplate == null}")
                    if (!isRegistering || replySent) return
                    if (fpTemplate != null) {
                        // Convert to WSQ format before sending to Flutter
                        val base64Template = Base64.encodeToString(fpTemplate, Base64.NO_WRAP)
                        invokeOnMainThread("onEnrollProgress", mapOf("finger" to finger, "template" to base64Template))
                        safeResultSuccess(base64Template)
                        finishOperation() // Ensure this is called after sending result
                    } else {
                        Log.e(TAG, "Enrollment failed: Failed to extract template on this attempt.")
                        invokeOnMainThread("onEnrollStatus", "Failed to extract template on this attempt. Please try again.")
                        safeResultError("ENROLL_FAILED", "Failed to extract template", null)
                        finishOperation()
                    }
                }

                override fun captureError(e: FingerprintSensorException) {
                    Log.e(TAG, "Enrollment error: ${e.message}", e)
                    if (!isRegistering || replySent) return
                    finishOperation()
                    invokeOnMainThread("onEnrollStatus", "Enrollment error: ${e.message}")
                    safeResultError("ENROLL_ERROR", e.message, null)
                }
            })

            fingerprintSensor?.startCapture(0)

            mainHandler.postDelayed({
                if (isRegistering && !replySent) {
                    Log.w(TAG, "Enrollment timed out")
                    finishOperation()
                    invokeOnMainThread("onEnrollStatus", "Enrollment timed out")
                    safeResultError("TIMEOUT", "Fingerprint enrollment timed out", null)
                }
            }, CAPTURE_TIMEOUT_MS)

        } catch (e: FingerprintSensorException) {
            Log.e(TAG, "Error starting enrollment: ${e.message}", e)
            if (replySent) return
            finishOperation()
            invokeOnMainThread("onEnrollStatus", "Error starting enrollment: ${e.message}")
            safeResultError("ENROLL_ERROR", e.message, null)
        }
    }

    private fun matchTemplates(storedTemplate: String, scannedTemplate: String, result: MethodChannel.Result) {
        try {
            // Decode Base64 WSQ
            val storedBytes = Base64.decode(storedTemplate, Base64.DEFAULT)
            val scannedBytes = Base64.decode(scannedTemplate, Base64.DEFAULT)
            // Use WSQ matching
            val score = ZKFingerService.verify(storedBytes, scannedBytes)
            Log.d(TAG, "Match score: $score")
            result.success(score > MIN_MATCH_SCORE)
        } catch (e: Exception) {
            Log.e(TAG, "Error matching templates", e)
            result.error("MATCH_ERROR", "Failed to match templates: ${e.message}", null)
        }
    }



    private fun cancelEnrollment(result: MethodChannel.Result?) {
        if (!isRegistering) {
            result?.error("NOT_ENROLLING", "No enrollment in progress to cancel.", null)
            return
        }
        Log.d(TAG, "Cancelling enrollment.")
        finishOperation()
        invokeOnMainThread("onEnrollStatus", "Enrollment cancelled by user.")
        result?.success(true)
    }

    private fun resetSensor(result: MethodChannel.Result) {
        Log.d(TAG, "Resetting sensor...")
        try {
            // Cancel any ongoing operations
            finishOperation()
            
            // Clean up current sensor
            cleanupSensor()
            
            // Wait a moment for cleanup
            mainHandler.postDelayed({
                try {
                    // Reinitialize device
                    initDevice()
                    result.success(true)
                } catch (e: Exception) {
                    Log.e(TAG, "Error during sensor reset", e)
                    result.error("RESET_ERROR", "Failed to reset sensor: ${e.message}", null)
                }
            }, 1000)
        } catch (e: Exception) {
            Log.e(TAG, "Error during sensor reset", e)
            result.error("RESET_ERROR", "Failed to reset sensor: ${e.message}", null)
        }
    }

    private fun finishOperation() {
        Log.d(TAG, "[DEBUG] finishOperation called. Before reset: isRegistering=$isRegistering, isCapturing=$isCapturing, isVerifying=$isVerifying, currentOperation=$currentOperation")
        val op = currentOperation
        isRegistering = false
        isCapturing = false
        isVerifying = false
        currentOperation = null
        this.verificationResult = null // Clear the stored result callback
        Log.d(TAG, "[DEBUG] finishOperation done. After reset: isRegistering=$isRegistering, isCapturing=$isCapturing, isVerifying=$isVerifying, currentOperation=$currentOperation")

        try {
            if (op != null) {
                fingerprintSensor?.stopCapture(0)
            }
            fingerprintSensor?.close(0)
            Log.d(TAG, "Sensor stopped and closed, ready for next operation.")
        } catch (e: FingerprintSensorException) {
            Log.e(TAG, "Error during finishOperation: ${e.message}")
        }
    }

    private fun cleanupSensor() {
        if (!isInitialized.getAndSet(false)) return
        try {
            fingerprintSensor?.stopCapture(0)
            fingerprintSensor?.close(0)
            FingerprintFactory.destroy(fingerprintSensor)
            ZKFingerService.free()
            fingerprintSensor = null
            isScannerConnected = false
            Log.d(TAG, "Fingerprint sensor cleaned up successfully.")
            invokeOnMainThread("onStatusChanged", "Scanner Disconnected")
        } catch (e: FingerprintSensorException) {
            Log.e(TAG, "Error cleaning up sensor: ${e.message}")
        }
    }

    private fun invokeOnMainThread(method: String, arguments: Any?) {
        mainHandler.post {
            try {
                methodChannel.invokeMethod(method, arguments)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to invoke $method on method channel: ${e.message}")
            }
        }
    }

    private fun handleError(errorCode: String, errorMessage: String, result: MethodChannel.Result?) {
        Log.e(TAG, "Error: $errorCode - $errorMessage")
        invokeOnMainThread("onStatusChanged", "Error: $errorMessage")
        result?.error(errorCode, errorMessage, null)
        cleanupSensor()
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy called")
        try {
            cleanupSensor()
            usbReceiver?.let {
                try {
                    unregisterReceiver(it)
                } catch (e: Exception) {
                    Log.e(TAG, "Error unregistering USB receiver", e)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in onDestroy", e)
        }
        super.onDestroy()
        // Clean up Futronic resources
        futronicUsbContext?.let {
            try {
                it.CloseDevice()
                it.Destroy()
            } catch (e: Exception) {
                Log.e(TAG, "Error destroying Futronic USB context: ${e.message}")
            }
        }
        futronicUsbContext = null
    }

    private fun enrollWithFutronic(finger: String, result: MethodChannel.Result) {
        Thread {
            try {
                Log.d(TAG, "Starting Futronic enrollment for finger: $finger")
                
                if (futronicUsbContext == null) {
                    Log.e(TAG, "Futronic USB context is null during enrollment")
                    runOnUiThread { result.error("INIT_FAILED", "Futronic USB context not initialized", null) }
                    return@Thread
                }
                
                // First ensure device is connected
                if (!futronicUsbContext!!.OpenDevice(0, true)) {
                    Log.e(TAG, "Cannot open Futronic USB device for enrollment")
                    runOnUiThread { result.error("DEVICE_OPEN_FAILED", "Cannot open Futronic USB device", null) }
                    return@Thread
                }
                
                try {
                    val ansiLib = AnsiSDKLib()
                    val syncDir = getExternalFilesDir(null)?.toString() ?: ""
                    if (!ansiLib.SetGlobalSyncDir(syncDir)) {
                        Log.e(TAG, "Failed to set global sync dir: ${ansiLib.GetErrorMessage()}")
                        futronicUsbContext!!.CloseDevice()
                        runOnUiThread { result.error("SETUP_FAILED", ansiLib.GetErrorMessage(), null) }
                        return@Thread
                    }
                    
                    Log.d(TAG, "Opening AnsiSDK with pre-opened USB device...")
                    // Now try to use the AnsiSDK with the already opened USB device
                    if (!ansiLib.OpenDeviceCtx(futronicUsbContext)) {
                        Log.e(TAG, "Failed to open AnsiSDK with USB context: ${ansiLib.GetErrorMessage()}")
                        futronicUsbContext!!.CloseDevice()
                        runOnUiThread { result.error("ANSISDK_OPEN_FAILED", ansiLib.GetErrorMessage(), null) }
                        return@Thread
                    }
                    
                    Log.d(TAG, "AnsiSDK opened successfully, filling image size...")
                    if (!ansiLib.FillImageSize()) {
                        ansiLib.CloseDevice()
                        futronicUsbContext!!.CloseDevice()
                        Log.e(TAG, "Failed to fill image size: ${ansiLib.GetErrorMessage()}")
                        runOnUiThread { result.error("IMAGE_SIZE_FAILED", ansiLib.GetErrorMessage(), null) }
                        return@Thread
                    }
                    
                    val imgBuffer = ByteArray(ansiLib.GetImageSize())
                    val template = ByteArray(ansiLib.GetMaxTemplateSize())
                    val templateSize = IntArray(1)
                    val fingerIndex = if (finger == "left") 0 else 1
                    
                    Log.d(TAG, "Starting fingerprint capture loop for finger index: $fingerIndex")
                    var success = false
                    var attempts = 0
                    val maxAttempts = 30 // Reduced for faster enrollment (3 seconds at 100ms intervals)
                    
                    // Retry loop like in the demo - handle empty frames by retrying
                    while (attempts < maxAttempts && !success) {
                        attempts++
                        Log.d(TAG, "Capture attempt $attempts of $maxAttempts")
                        
                        success = ansiLib.CreateTemplate(fingerIndex, imgBuffer, template, templateSize)
                        
                        if (success) {
                            Log.d(TAG, "Template created successfully on attempt $attempts")
                            break
                        } else {
                            val errorCode = ansiLib.GetErrorCode()
                            val errorMessage = ansiLib.GetErrorMessage()
                            Log.d(TAG, "CreateTemplate failed on attempt $attempts - Error code: $errorCode, Message: $errorMessage")
                            
                            // Handle expected errors by retrying (like in the demo)
                            if (errorCode == AnsiSDKLib.FTR_ERROR_EMPTY_FRAME || 
                                errorCode == AnsiSDKLib.FTR_ERROR_NO_FRAME ||
                                errorCode == AnsiSDKLib.FTR_ERROR_MOVABLE_FINGER) {
                                Log.d(TAG, "Expected error (empty/no frame or movable finger), retrying...")
                                try {
                                    Thread.sleep(25) // Ultra-aggressive: 25ms for lightning speed // Wait 100ms like in demo
                                } catch (e: InterruptedException) {
                                    Log.e(TAG, "Sleep interrupted")
                                    break
                                }
                                continue // Retry
                            } else {
                                // Real error - stop trying
                                Log.e(TAG, "Real error occurred, stopping: $errorMessage")
                                break
                            }
                        }
                    }
                    
                    // Close both SDK and USB device
                    ansiLib.CloseDevice()
                    futronicUsbContext!!.CloseDevice()
                    
                    if (success) {
                        // Enforce minimum template size to prevent partial fingerprints during enrollment
                        if (templateSize[0] < MIN_TEMPLATE_SIZE_BYTES) {
                            ansiLib.CloseDevice()
                            futronicUsbContext!!.CloseDevice()
                            Log.e(TAG, "Enrollment template too small: ${templateSize[0]} bytes (min: $MIN_TEMPLATE_SIZE_BYTES)")
                            runOnUiThread { result.error("ENROLL_PARTIAL", "Partial fingerprint captured. Please place full thumb on scanner.", null) }
                            return@Thread
                        }
                        val templateBase64 = android.util.Base64.encodeToString(template, 0, templateSize[0], android.util.Base64.DEFAULT)
                        Log.d(TAG, "Futronic enrollment successful after $attempts attempts, template size: ${templateSize[0]}")
                        runOnUiThread { result.success(templateBase64) }
                    } else {
                        Log.e(TAG, "Futronic enrollment failed after $attempts attempts: ${ansiLib.GetErrorMessage()}")
                        runOnUiThread { result.error("ENROLLMENT_FAILED", ansiLib.GetErrorMessage(), null) }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Exception during AnsiSDK operations: ${e.message}")
                    try {
                        futronicUsbContext!!.CloseDevice()
                    } catch (closeError: Exception) {
                        Log.e(TAG, "Error closing USB device after exception: ${closeError.message}")
                    }
                    runOnUiThread { result.error("ANSISDK_EXCEPTION", e.message, null) }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Exception during Futronic enrollment: ${e.message}")
                runOnUiThread { result.error("ENROLLMENT_EXCEPTION", e.message, null) }
            }
        }.start()
    }

    private fun verifyWithFutronic(finger: String, templateBase64: String, result: MethodChannel.Result) {
        Thread {
            try {
                Log.d(TAG, "Starting Futronic verification for $finger finger")
                
                if (futronicUsbContext == null) {
                    Log.e(TAG, "Futronic USB context not initialized")
                    runOnUiThread { result.error("INIT_FAILED", "Futronic USB context not initialized", null) }
                    return@Thread
                }
                
                // First open the USB device directly
                val openResult = futronicUsbContext!!.OpenDevice(0, true)
                if (!openResult) {
                    Log.e(TAG, "Failed to open Futronic USB device")
                    runOnUiThread { result.error("USB_OPEN_FAILED", "Failed to open USB device", null) }
                    return@Thread
                }
                
                val ansiLib = AnsiSDKLib()
                val syncDir = getExternalFilesDir(null)?.toString() ?: ""
                if (!ansiLib.SetGlobalSyncDir(syncDir)) {
                    futronicUsbContext!!.CloseDevice()
                    Log.e(TAG, "Failed to set sync directory: ${ansiLib.GetErrorMessage()}")
                    runOnUiThread { result.error("SETUP_FAILED", ansiLib.GetErrorMessage(), null) }
                    return@Thread
                }
                
                if (!ansiLib.OpenDeviceCtx(futronicUsbContext)) {
                    futronicUsbContext!!.CloseDevice()
                    Log.e(TAG, "Failed to open device context: ${ansiLib.GetErrorMessage()}")
                    runOnUiThread { result.error("DEVICE_OPEN_FAILED", ansiLib.GetErrorMessage(), null) }
                    return@Thread
                }
                
                if (!ansiLib.FillImageSize()) {
                    ansiLib.CloseDevice()
                    futronicUsbContext!!.CloseDevice()
                    Log.e(TAG, "Failed to fill image size: ${ansiLib.GetErrorMessage()}")
                    runOnUiThread { result.error("IMAGE_SIZE_FAILED", ansiLib.GetErrorMessage(), null) }
                    return@Thread
                }
                
                if (templateBase64.isEmpty()) {
                    ansiLib.CloseDevice()
                    futronicUsbContext!!.CloseDevice()
                    Log.e(TAG, "Empty template provided")
                    runOnUiThread { result.error("VERIFY_FAILED", "Empty template", null) }
                    return@Thread
                }

                Log.d(TAG, "Futronic device initialized, starting verification...")
                
                // Create template from live capture - use same pattern as enrollment
                val imgBuffer = ByteArray(ansiLib.GetImageSize())
                val template = ByteArray(ansiLib.GetMaxTemplateSize())
                val templateSize = IntArray(1)
                val fingerIndex = if (finger == "left") 0 else 1
                
                var success = false
                var attempts = 0
                // Extend attempts to give users more time during clock-out scenarios
                val maxAttempts = 20 // Reduced to 2 seconds for fast 1:1 verification
                
                // Retry loop for capturing fingerprint - same as enrollment
                while (attempts < maxAttempts && !success) {
                    attempts++
                    Log.d(TAG, "Verification capture attempt $attempts of $maxAttempts")
                    
                    success = ansiLib.CreateTemplate(fingerIndex, imgBuffer, template, templateSize)
                    
                    if (success) {
                        Log.d(TAG, "Template created successfully for verification on attempt $attempts")
                        break
                    } else {
                        val errorCode = ansiLib.GetErrorCode()
                        val errorMessage = ansiLib.GetErrorMessage()
                        Log.d(TAG, "CreateTemplate failed on attempt $attempts - Error code: $errorCode, Message: $errorMessage")
                        
                        // Handle expected errors by retrying (like in enrollment)
                        if (errorCode == AnsiSDKLib.FTR_ERROR_EMPTY_FRAME || 
                            errorCode == AnsiSDKLib.FTR_ERROR_NO_FRAME ||
                            errorCode == AnsiSDKLib.FTR_ERROR_MOVABLE_FINGER) {
                            Log.d(TAG, "Expected error (empty/no frame or movable finger), retrying...")
                            try {
                                Thread.sleep(25) // Ultra-aggressive: 25ms for lightning speed // Wait 100ms like in enrollment
                            } catch (e: InterruptedException) {
                                Log.e(TAG, "Sleep interrupted")
                                break
                            }
                            continue // Retry
                        } else {
                            // Real error - stop trying
                            Log.e(TAG, "Real error occurred, stopping: $errorMessage")
                            break
                        }
                    }
                }
                
                if (!success) {
                    ansiLib.CloseDevice()
                    futronicUsbContext!!.CloseDevice()
                    val errorMsg = if (attempts >= maxAttempts) "Timeout waiting for finger placement" else ansiLib.GetErrorMessage()
                    Log.e(TAG, "Failed to capture fingerprint for verification: $errorMsg")
                    runOnUiThread { result.error("CAPTURE_FAILED", errorMsg, null) }
                    return@Thread
                }
                
                // Get the captured template and validate its size to reject partial fingerprints
                val capturedTemplate = template.take(templateSize[0]).toByteArray()
                if (capturedTemplate.size < MIN_TEMPLATE_SIZE_BYTES) {
                    ansiLib.CloseDevice()
                    futronicUsbContext!!.CloseDevice()
                    Log.e(TAG, "Captured template too small: ${capturedTemplate.size} bytes (min: $MIN_TEMPLATE_SIZE_BYTES)")
                    runOnUiThread { result.error("CAPTURE_PARTIAL", "Partial fingerprint captured. Please place full thumb on scanner.", null) }
                    return@Thread
                }
                if (capturedTemplate.isEmpty()) {
                    ansiLib.CloseDevice()
                    futronicUsbContext!!.CloseDevice()
                    Log.e(TAG, "Failed to get captured template")
                    runOnUiThread { result.error("TEMPLATE_FAILED", "Failed to get captured template", null) }
                    return@Thread
                }
                
                // Compare with stored template
                val storedTemplate = android.util.Base64.decode(templateBase64, android.util.Base64.DEFAULT)
                val matchScore = FloatArray(1)
                val matched = ansiLib.MatchTemplates(storedTemplate, capturedTemplate, matchScore)
                // Use ULTRA HIGH security threshold (95%) for 1:N verification to prevent false positives
                // Set threshold to 95% of HIGH score for maximum security matching ZKTeco
                val matchThreshold = AnsiSDKLib.FTR_ANSISDK_MATCH_SCORE_HIGH.toFloat() * 0.92f  // Reduced from 95% for better real-world usability
                
                ansiLib.CloseDevice()
                futronicUsbContext!!.CloseDevice()
                
                val isMatch = matched && matchScore[0] > matchThreshold
                Log.d(TAG, "Verification result: $isMatch (score: ${matchScore[0]}, threshold: $matchThreshold)")
                runOnUiThread { result.success(isMatch) }
                
            } catch (e: Exception) {
                Log.e(TAG, "Exception during Futronic verification: ${e.message}", e)
                // Make sure to close connections in case of exception
                try {
                    futronicUsbContext?.CloseDevice()
                } catch (closeEx: Exception) {
                    Log.e(TAG, "Error closing USB device: ${closeEx.message}")
                }
                runOnUiThread { result.error("VERIFY_EXCEPTION", e.message, null) }
            }
        }.start()
    }

    // Optimized verify that captures once and compares against both left and right templates (if both provided)
    private fun verifyWithFutronicBoth(leftOrRightHint: String, templateBase64Left: String?, templateBase64Right: String?, result: MethodChannel.Result) {
        Thread {
            try {
                Log.d(TAG, "Starting Futronic verification (single capture, both templates). Hint: $leftOrRightHint")

                if (templateBase64Left.isNullOrEmpty() && templateBase64Right.isNullOrEmpty()) {
                    runOnUiThread { result.error("VERIFY_FAILED", "No templates provided", null) }
                    return@Thread
                }

                if (futronicUsbContext == null) {
                    Log.e(TAG, "Futronic USB context not initialized")
                    runOnUiThread { result.error("INIT_FAILED", "Futronic USB context not initialized", null) }
                    return@Thread
                }

                val openResult = futronicUsbContext!!.OpenDevice(0, true)
                if (!openResult) {
                    Log.e(TAG, "Failed to open Futronic USB device")
                    runOnUiThread { result.error("USB_OPEN_FAILED", "Failed to open USB device", null) }
                    return@Thread
                }

                val ansiLib = AnsiSDKLib()
                val syncDir = getExternalFilesDir(null)?.toString() ?: ""
                if (!ansiLib.SetGlobalSyncDir(syncDir)) {
                    futronicUsbContext!!.CloseDevice()
                    Log.e(TAG, "Failed to set sync directory: ${ansiLib.GetErrorMessage()}")
                    runOnUiThread { result.error("SETUP_FAILED", ansiLib.GetErrorMessage(), null) }
                    return@Thread
                }

                if (!ansiLib.OpenDeviceCtx(futronicUsbContext)) {
                    futronicUsbContext!!.CloseDevice()
                    Log.e(TAG, "Failed to open device context: ${ansiLib.GetErrorMessage()}")
                    runOnUiThread { result.error("DEVICE_OPEN_FAILED", ansiLib.GetErrorMessage(), null) }
                    return@Thread
                }

                if (!ansiLib.FillImageSize()) {
                    ansiLib.CloseDevice()
                    futronicUsbContext!!.CloseDevice()
                    Log.e(TAG, "Failed to fill image size: ${ansiLib.GetErrorMessage()}")
                    runOnUiThread { result.error("IMAGE_SIZE_FAILED", ansiLib.GetErrorMessage(), null) }
                    return@Thread
                }

                val imgBuffer = ByteArray(ansiLib.GetImageSize())
                val template = ByteArray(ansiLib.GetMaxTemplateSize())
                val templateSize = IntArray(1)
                var fingerIndex = if (leftOrRightHint == "left") 0 else if (leftOrRightHint == "right") 1 else 0

                var success = false
                var attempts = 0
                val maxAttempts = 8 // Ultra-aggressive for 1:N verification (0.4 seconds)
                // If both templates are present, try up to two finger indices: hint first, then the other
                val tryBothFingers = !templateBase64Left.isNullOrEmpty() && !templateBase64Right.isNullOrEmpty()
                var triedAlternate = false
                while (attempts < maxAttempts && !success) {
                    attempts++
                    Log.d(TAG, "Verification (both) capture attempt $attempts of $maxAttempts (fingerIndex=$fingerIndex)")
                    success = ansiLib.CreateTemplate(fingerIndex, imgBuffer, template, templateSize)
                    if (!success) {
                        val errorCode = ansiLib.GetErrorCode()
                        if (errorCode == AnsiSDKLib.FTR_ERROR_EMPTY_FRAME || errorCode == AnsiSDKLib.FTR_ERROR_NO_FRAME || errorCode == AnsiSDKLib.FTR_ERROR_MOVABLE_FINGER) {
                            Thread.sleep(25) // Ultra-aggressive: 25ms for lightning speed
                            continue
                        } else {
                            break
                        }
                    } else if (success && tryBothFingers) {
                        // If capture succeeded, we will match below. If mismatch, we will re-capture on alternate index.
                    }
                }

                if (!success) {
                    ansiLib.CloseDevice()
                    futronicUsbContext!!.CloseDevice()
                    val errorMsg = if (attempts >= maxAttempts) "Timeout waiting for finger placement" else ansiLib.GetErrorMessage()
                    runOnUiThread { result.error("CAPTURE_FAILED", errorMsg, null) }
                    return@Thread
                }

                val capturedTemplate = template.take(templateSize[0]).toByteArray()
                if (capturedTemplate.size < MIN_TEMPLATE_SIZE_BYTES) {
                    ansiLib.CloseDevice()
                    futronicUsbContext!!.CloseDevice()
                    Log.e(TAG, "Captured template too small: ${capturedTemplate.size} bytes (min: $MIN_TEMPLATE_SIZE_BYTES)")
                    runOnUiThread { result.error("CAPTURE_PARTIAL", "Partial fingerprint captured. Please place full thumb on scanner.", null) }
                    return@Thread
                }

                val matchScoreLeft = FloatArray(1)
                val matchScoreRight = FloatArray(1)
                var matched = false
                if (!templateBase64Left.isNullOrEmpty()) {
                    val storedLeft = android.util.Base64.decode(templateBase64Left, android.util.Base64.DEFAULT)
                    matched = matched || ansiLib.MatchTemplates(storedLeft, capturedTemplate, matchScoreLeft)
                }
                if (!templateBase64Right.isNullOrEmpty()) {
                    val storedRight = android.util.Base64.decode(templateBase64Right, android.util.Base64.DEFAULT)
                    matched = matched || ansiLib.MatchTemplates(storedRight, capturedTemplate, matchScoreRight)
                }

                // Use ULTRA HIGH security threshold (95%) for 1:N verification to prevent false positives
                // Set threshold to 95% of HIGH score for maximum security matching ZKTeco
                val matchThreshold = AnsiSDKLib.FTR_ANSISDK_MATCH_SCORE_HIGH.toFloat() * 0.92f  // Reduced from 95% for better real-world usability
                val score = maxOf(matchScoreLeft[0], matchScoreRight[0])
                var isMatch = matched && score > matchThreshold
                Log.d(TAG, "Verification (both) result: $isMatch (best score: $score, threshold: $matchThreshold)")

                // If both templates exist and the first capture didn't meet threshold, re-attempt on the alternate fingerIndex
                if (!isMatch && tryBothFingers && !triedAlternate) {
                    triedAlternate = true
                    // Switch index: 0 <-> 1
                    fingerIndex = if (fingerIndex == 0) 1 else 0
                    Log.d(TAG, "Re-attempting capture on alternate fingerIndex=$fingerIndex")
                    // Re-open SDK and device for a fresh capture
                    if (!ansiLib.OpenDeviceCtx(futronicUsbContext)) {
                        futronicUsbContext!!.CloseDevice()
                        runOnUiThread { result.error("DEVICE_OPEN_FAILED", ansiLib.GetErrorMessage(), null) }
                        return@Thread
                    }
                    if (!ansiLib.FillImageSize()) {
                        ansiLib.CloseDevice()
                        futronicUsbContext!!.CloseDevice()
                        runOnUiThread { result.error("IMAGE_SIZE_FAILED", ansiLib.GetErrorMessage(), null) }
                        return@Thread
                    }
                    val imgBuffer2 = ByteArray(ansiLib.GetImageSize())
                    val template2 = ByteArray(ansiLib.GetMaxTemplateSize())
                    val templateSize2 = IntArray(1)
                    var success2 = false
                    var attempts2 = 0
                    while (attempts2 < maxAttempts && !success2) {
                        attempts2++
                        success2 = ansiLib.CreateTemplate(fingerIndex, imgBuffer2, template2, templateSize2)
                        if (!success2) {
                            val errorCode2 = ansiLib.GetErrorCode()
                            if (errorCode2 == AnsiSDKLib.FTR_ERROR_EMPTY_FRAME || errorCode2 == AnsiSDKLib.FTR_ERROR_NO_FRAME || errorCode2 == AnsiSDKLib.FTR_ERROR_MOVABLE_FINGER) {
                                Thread.sleep(25) // Ultra-aggressive: 25ms for lightning speed
                                continue
                            } else {
                                break
                            }
                        }
                    }
                    if (success2) {
                        val captured2 = template2.take(templateSize2[0]).toByteArray()
                        val mL = FloatArray(1)
                        val mR = FloatArray(1)
                        var m = false
                        if (!templateBase64Left.isNullOrEmpty()) {
                            val storedLeft = android.util.Base64.decode(templateBase64Left, android.util.Base64.DEFAULT)
                            m = m || ansiLib.MatchTemplates(storedLeft, captured2, mL)
                        }
                        if (!templateBase64Right.isNullOrEmpty()) {
                            val storedRight = android.util.Base64.decode(templateBase64Right, android.util.Base64.DEFAULT)
                            m = m || ansiLib.MatchTemplates(storedRight, captured2, mR)
                        }
                        val score2 = maxOf(mL[0], mR[0])
                        isMatch = m && score2 > matchThreshold
                        Log.d(TAG, "Alternate capture result: $isMatch (best score: $score2, threshold: $matchThreshold)")
                        // Close and return
                        ansiLib.CloseDevice()
                        futronicUsbContext!!.CloseDevice()
                        runOnUiThread { result.success(isMatch) }
                        return@Thread
                    } else {
                        ansiLib.CloseDevice()
                        futronicUsbContext!!.CloseDevice()
                        runOnUiThread { result.success(false) }
                        return@Thread
                    }
                }

                // Close and return final result
                ansiLib.CloseDevice()
                futronicUsbContext!!.CloseDevice()
                runOnUiThread { result.success(isMatch) }
            } catch (e: Exception) {
                Log.e(TAG, "Exception during Futronic verification (both): ${e.message}", e)
                try { futronicUsbContext?.CloseDevice() } catch (_: Exception) {}
                runOnUiThread { result.error("VERIFY_EXCEPTION", e.message, null) }
            }
        }.start()
    }

    private fun isFutronicConnected(result: MethodChannel.Result) {
        Thread {
            try {
                Log.d(TAG, "=== Starting Enhanced Futronic Connection Check ===")
                
                // Enhanced diagnostic information
                logSystemUsbInfo()
                
                if (futronicUsbContext == null) {
                    Log.d(TAG, "Futronic USB context is null, attempting re-initialization...")
                    // Try to reinitialize on main thread
                    runOnUiThread {
                        initializeFutronicUsbContext()
                        // Check again after initialization with retry mechanism
                        Thread {
                            performEnhancedFutronicCheck(result, 1, 3)
                        }.start()
                    }
                    return@Thread
                }
                
                performEnhancedFutronicCheck(result, 1, 3)
            } catch (e: Exception) {
                Log.e(TAG, "Error in isFutronicConnected: ${e.message}", e)
                runOnUiThread { result.success(false) }
            }
        }.start()
    }

    private fun logSystemUsbInfo() {
        try {
            val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
            val deviceList = usbManager.deviceList
            
            Log.d(TAG, "=== USB System Diagnostics ===")
            Log.d(TAG, "USB devices count: ${deviceList.size}")
            Log.d(TAG, "Android version: ${android.os.Build.VERSION.RELEASE}")
            Log.d(TAG, "Device model: ${android.os.Build.MODEL}")
            Log.d(TAG, "Device manufacturer: ${android.os.Build.MANUFACTURER}")
            
            for ((name, device) in deviceList) {
                Log.d(TAG, "USB Device: $name")
                Log.d(TAG, "  VID: ${device.vendorId}, PID: ${device.productId}")
                Log.d(TAG, "  Manufacturer: ${device.manufacturerName}")
                Log.d(TAG, "  Product: ${device.productName}")
                Log.d(TAG, "  Interface count: ${device.interfaceCount}")
                Log.d(TAG, "  Has permission: ${usbManager.hasPermission(device)}")
            }
            Log.d(TAG, "=== End USB Diagnostics ===")
        } catch (e: Exception) {
            Log.e(TAG, "Error logging USB info: ${e.message}")
        }
    }

    private fun performEnhancedFutronicCheck(result: MethodChannel.Result, attempt: Int, maxAttempts: Int) {
        try {
            Log.d(TAG, "Enhanced Futronic check - Attempt $attempt/$maxAttempts")
            
            if (futronicUsbContext == null) {
                Log.e(TAG, "Futronic USB context is null on attempt $attempt")
                if (attempt < maxAttempts) {
                    // Try re-initialization
                    runOnUiThread {
                        initializeFutronicUsbContext()
                        Thread {
                            Thread.sleep(1000) // Wait a bit for initialization
                            performEnhancedFutronicCheck(result, attempt + 1, maxAttempts)
                        }.start()
                    }
                    return
                } else {
                    runOnUiThread { result.success(false) }
                    return
                }
            }

            // Multiple detection strategies
            val strategies = listOf(
                { directUsbCheck() },
                { permissionBasedCheck() },
                { delayedCheck() }
            )
            
            for ((index, strategy) in strategies.withIndex()) {
                Log.d(TAG, "Trying detection strategy ${index + 1}")
                val isConnected = strategy()
                if (isConnected) {
                    Log.d(TAG, "Futronic detected using strategy ${index + 1}")
                    runOnUiThread { result.success(true) }
                    return
                }
            }
            
            // If all strategies failed and we have attempts left, retry
            if (attempt < maxAttempts) {
                Log.d(TAG, "All strategies failed, retrying in 2 seconds...")
                Thread.sleep(2000)
                performEnhancedFutronicCheck(result, attempt + 1, maxAttempts)
            } else {
                Log.d(TAG, "All detection attempts failed")
                runOnUiThread { result.success(false) }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in enhanced Futronic check: ${e.message}", e)
            if (attempt < maxAttempts) {
                Thread.sleep(1000)
                performEnhancedFutronicCheck(result, attempt + 1, maxAttempts)
            } else {
                runOnUiThread { result.success(false) }
            }
        }
    }
    
    private fun directUsbCheck(): Boolean {
        return try {
            Log.d(TAG, "Strategy 1: Direct USB check")
            val isConnected = futronicUsbContext!!.OpenDevice(0, true)
            Log.d(TAG, "Direct USB OpenDevice result: $isConnected")
            
            if (isConnected) {
                try {
                    futronicUsbContext!!.CloseDevice()
                    Log.d(TAG, "Direct USB device closed successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "Error closing device after direct check: ${e.message}")
                }
            }
            isConnected
        } catch (e: Exception) {
            Log.e(TAG, "Direct USB check failed: ${e.message}")
            false
        }
    }
    
    private fun permissionBasedCheck(): Boolean {
        return try {
            Log.d(TAG, "Strategy 2: Permission-based check")
            val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
            val deviceList = usbManager.deviceList
            
            for ((_, device) in deviceList) {
                if (device.vendorId == 1848) { // Futronic VID
                    Log.d(TAG, "Found Futronic device: VID=${device.vendorId}, PID=${device.productId}")
                    val hasPermission = usbManager.hasPermission(device)
                    Log.d(TAG, "Futronic device permission: $hasPermission")
                    
                    if (hasPermission) {
                        // Try opening with permission
                        val isConnected = futronicUsbContext!!.OpenDevice(0, true)
                        if (isConnected) {
                            try {
                                futronicUsbContext!!.CloseDevice()
                            } catch (e: Exception) {
                                Log.e(TAG, "Error closing device after permission check: ${e.message}")
                            }
                        }
                        return isConnected
                    } else {
                        Log.d(TAG, "Requesting USB permission for Futronic device")
                        requestUsbPermissionForFutronic(device)
                        return false // Will retry later
                    }
                }
            }
            
            Log.d(TAG, "No Futronic device found in USB device list")
            false
        } catch (e: Exception) {
            Log.e(TAG, "Permission-based check failed: ${e.message}")
            false
        }
    }
    
    private fun delayedCheck(): Boolean {
        return try {
            Log.d(TAG, "Strategy 3: Delayed check with timeout")
            Thread.sleep(1500) // Wait for USB to stabilize
            
            val isConnected = futronicUsbContext!!.OpenDevice(0, true)
            Log.d(TAG, "Delayed check OpenDevice result: $isConnected")
            
            if (isConnected) {
                try {
                    futronicUsbContext!!.CloseDevice()
                } catch (e: Exception) {
                    Log.e(TAG, "Error closing device after delayed check: ${e.message}")
                }
            } else {
                // Check pending status
                try {
                    val isPending = futronicUsbContext!!.IsPendingOpen()
                    Log.d(TAG, "Delayed check pending status: $isPending")
                } catch (e: Exception) {
                    Log.e(TAG, "Error checking pending status: ${e.message}")
                }
            }
            
            isConnected
        } catch (e: Exception) {
            Log.e(TAG, "Delayed check failed: ${e.message}")
            false
        }
    }
    
    private fun requestUsbPermissionForFutronic(device: UsbDevice) {
        try {
            val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
            val intent = Intent(ACTION_USB_PERMISSION).apply {
                setPackage(packageName)
            }
            val permissionIntent = PendingIntent.getBroadcast(
                this,
                0,
                intent,
                PendingIntent.FLAG_IMMUTABLE
            )
            Log.d(TAG, "Requesting USB permission for Futronic device")
            usbManager.requestPermission(device, permissionIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting USB permission: ${e.message}")
        }
    }

    private fun checkFutronicConnectionInternal(result: MethodChannel.Result) {
        // This method is kept for backward compatibility but now uses enhanced checking
        performEnhancedFutronicCheck(result, 1, 1)
    }
}
package com.shirsh.flutter_doc_scanner

import android.app.Activity
import android.content.Intent
import android.content.IntentSender
import android.net.Uri
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import androidx.core.app.ActivityCompat.startIntentSenderForResult
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import android.os.Handler
import android.os.Looper

class FlutterDocScannerPlugin : MethodCallHandler, ActivityResultListener,
    FlutterPlugin, ActivityAware {
    private var channel: MethodChannel? = null
    private var activityBinding: ActivityPluginBinding? = null
    private val CHANNEL = "flutter_doc_scanner"
    @Volatile private var activity: Activity? = null
    @Volatile private var pendingResult: MethodChannel.Result? = null

    companion object {
        private const val REQUEST_CODE_SCAN = 213312
        private const val REQUEST_CODE_SCAN_URI = 214412
        private const val REQUEST_CODE_SCAN_IMAGES = 215512
        private const val REQUEST_CODE_SCAN_PDF = 216612
        private const val DEFAULT_PAGE_LIMIT = 10
        private val TAG = FlutterDocScannerPlugin::class.java.simpleName
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.d(TAG, "onMethodCall: ${call.method}")
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "getScanDocuments" -> startDocumentScan(
                result,
                call.arguments as? Map<*, *>,
                REQUEST_CODE_SCAN,
                intArrayOf(
                    GmsDocumentScannerOptions.RESULT_FORMAT_JPEG,
                    GmsDocumentScannerOptions.RESULT_FORMAT_PDF
                )
            )
            "getScannedDocumentAsImages" -> startDocumentScan(
                result,
                call.arguments as? Map<*, *>,
                REQUEST_CODE_SCAN_IMAGES,
                intArrayOf(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            )
            "getScannedDocumentAsPdf" -> startDocumentScan(
                result,
                call.arguments as? Map<*, *>,
                REQUEST_CODE_SCAN_PDF,
                intArrayOf(GmsDocumentScannerOptions.RESULT_FORMAT_PDF)
            )
            "getScanDocumentsUri" -> startDocumentScan(
                result,
                call.arguments as? Map<*, *>,
                REQUEST_CODE_SCAN_URI,
                intArrayOf(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            )
            else -> result.notImplemented()
        }
    }

    private fun startDocumentScan(
        result: Result,
        arguments: Map<*, *>?,
        requestCode: Int,
        resultFormats: IntArray
    ) {
        val currentActivity = activity
        if (currentActivity == null) {
            Log.e(TAG, "startDocumentScan: No activity")
            result.error("NO_ACTIVITY", "Document scanner requires a foreground activity.", null)
            return
        }

        synchronized(this) {
            if (pendingResult != null) {
                Log.w(TAG, "startDocumentScan: Scan already in progress")
                result.error("SCAN_IN_PROGRESS", "Another scan is already running.", null)
                return
            }
            pendingResult = result
        }

        val pageLimit = (arguments?.get("page") as? Int)?.coerceAtLeast(1) ?: DEFAULT_PAGE_LIMIT
        Log.d(TAG, "startDocumentScan: pageLimit=$pageLimit, requestCode=$requestCode")
        launchDocumentScanner(currentActivity, pageLimit, requestCode, resultFormats)
    }

    private fun launchDocumentScanner(
        currentActivity: Activity,
        pageLimit: Int,
        requestCode: Int,
        resultFormats: IntArray
    ) {
        Log.d(TAG, "launchDocumentScanner: preparing options")
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true)
            .setPageLimit(pageLimit)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
        if (resultFormats.isNotEmpty()) {
            val firstFormat = resultFormats.first()
            val remainingFormats = resultFormats.drop(1).toIntArray()
            options.setResultFormats(firstFormat, *remainingFormats)
        }
        val builtOptions = options.build()

        Log.d(TAG, "launchDocumentScanner: getting intent")
        GmsDocumentScanning.getClient(builtOptions)
            .getStartScanIntent(currentActivity)
            .addOnSuccessListener { intentSender: IntentSender ->
                Log.d(TAG, "launchDocumentScanner: got intent sender, starting activity")
                try {
                    startIntentSenderForResult(
                        currentActivity,
                        intentSender,
                        requestCode,
                        null,
                        0,
                        0,
                        0,
                        null
                    )
                } catch (e: IntentSender.SendIntentException) {
                    Log.e(TAG, "Unable to launch document scanner", e)
                    finishWithError("SCAN_FAILED", "Unable to launch document scanner", e)
                } catch (e: Exception) {
                    Log.e(TAG, "Unable to launch document scanner", e)
                    finishWithError("SCAN_FAILED", "Unable to launch document scanner", e)
                }
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Unable to start document scanner", e)
                finishWithError("SCAN_FAILED", "Unable to start document scanner", e)
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        // Guard: if pendingResult is null this is a duplicate/stale callback — ignore it.
        if (pendingResult == null) {
            Log.w(TAG, "onActivityResult: pendingResult is null, ignoring (requestCode=$requestCode)")
            return requestCode == REQUEST_CODE_SCAN ||
                   requestCode == REQUEST_CODE_SCAN_URI ||
                   requestCode == REQUEST_CODE_SCAN_IMAGES ||
                   requestCode == REQUEST_CODE_SCAN_PDF
        }

        return when (requestCode) {
            REQUEST_CODE_SCAN, REQUEST_CODE_SCAN_PDF -> {
                handlePdfResult(resultCode, data)
                true
            }

            REQUEST_CODE_SCAN_IMAGES, REQUEST_CODE_SCAN_URI -> {
                handleImageResult(resultCode, data)
                true
            }

            else -> false
        }
    }

    private fun handlePdfResult(resultCode: Int, data: Intent?) {
        Log.d(TAG, "handlePdfResult: resultCode=$resultCode")
        when (resultCode) {
            Activity.RESULT_OK -> {
                val scanResult = GmsDocumentScanningResult.fromActivityResultIntent(data)
                if (scanResult == null) {
                    finishWithError("SCAN_FAILED", "Failed to parse scan result from intent")
                    return
                }
                val pdf = scanResult.getPdf()
                if (pdf != null) {
                    val rawUri = pdf.getUri()
                    val pageCount = pdf.getPageCount()
                    Log.d(TAG, "PDF scanned: pages=$pageCount, uri=$rawUri")

                    Thread {
                        try {
                            val pdfUriForDart = materializeUri(rawUri, "pdf").toString()
                            Handler(Looper.getMainLooper()).post {
                                finishWithSuccess(
                                    mapOf(
                                        "pdfUri" to pdfUriForDart,
                                        "pageCount" to pageCount,
                                    )
                                )
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "materializeUri failed for PDF", e)
                            Handler(Looper.getMainLooper()).post {
                                finishWithSuccess(
                                    mapOf(
                                        "pdfUri" to rawUri.toString(),
                                        "pageCount" to pageCount,
                                    )
                                )
                            }
                        }
                    }.start()
                } else {
                    finishWithError("SCAN_FAILED", "No PDF result returned from scanner")
                }
            }

            Activity.RESULT_CANCELED -> {
                Log.d(TAG, "Scan cancelled by user")
                finishWithSuccess(null)
            }
            else -> finishWithError("SCAN_FAILED", "Failed to scan document (resultCode=$resultCode)")
        }
    }

    private fun handleImageResult(resultCode: Int, data: Intent?) {
        Log.d(TAG, "handleImageResult: resultCode=$resultCode")
        when (resultCode) {
            Activity.RESULT_OK -> {
                val scanResult = GmsDocumentScanningResult.fromActivityResultIntent(data)
                if (scanResult == null) {
                    finishWithError("SCAN_FAILED", "Failed to parse scan result from intent")
                    return
                }
                val pages = scanResult.getPages()
                if (pages.isNullOrEmpty()) {
                    finishWithError("SCAN_FAILED", "No image results returned from scanner")
                    return
                }

                val rawUris = pages.mapNotNull { it.getImageUri() }
                Log.d(TAG, "Images scanned: count=${rawUris.size}")

                Thread {
                    try {
                        val materializedUris = rawUris.map { uri ->
                            materializeUri(uri, "jpg").toString()
                        }
                        Handler(Looper.getMainLooper()).post {
                            finishWithSuccess(
                                mapOf(
                                    "images" to materializedUris,
                                    "count" to materializedUris.size,
                                )
                            )
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "materializeUri failed for images", e)
                        val originalUris = rawUris.map { it.toString() }
                        Handler(Looper.getMainLooper()).post {
                            finishWithSuccess(
                                mapOf(
                                    "images" to originalUris,
                                    "count" to originalUris.size,
                                )
                            )
                        }
                    }
                }.start()
            }

            Activity.RESULT_CANCELED -> {
                Log.d(TAG, "Scan cancelled by user")
                finishWithSuccess(null)
            }
            else -> finishWithError("SCAN_FAILED", "Failed to scan document (resultCode=$resultCode)")
        }
    }

    /**
     * Returns a file:// URI string pointing at a readable file on local storage.
     */
    private fun materializeUri(uri: Uri, extension: String): Uri {
        val act = activity
            ?: return uri
        return when (uri.scheme) {
            "file" -> {
                val path = uri.path
                if (!path.isNullOrEmpty() && File(path).exists()) {
                    Uri.fromFile(File(path))
                } else {
                    uri
                }
            }
            "content" -> {
                val outFile = File(act.cacheDir, "mlkit_doc_scan_${System.currentTimeMillis()}_${(0..1000).random()}.$extension")
                act.contentResolver.openInputStream(uri)?.use { input ->
                    FileOutputStream(outFile).use { output -> input.copyTo(output) }
                } ?: throw IllegalStateException("openInputStream returned null for $uri")
                if (!outFile.exists() || outFile.length() == 0L) {
                    throw IllegalStateException("Cached file empty or missing")
                }
                Uri.fromFile(outFile)
            }
            else -> {
                // Plain path or unknown — try as filesystem path
                val raw = uri.toString().removePrefix("file://").removePrefix("file:")
                val f = File(raw)
                if (f.exists()) Uri.fromFile(f) else uri
            }
        }
    }

    private fun finishWithSuccess(payload: Any?) {
        synchronized(this) {
            pendingResult?.success(payload)
            pendingResult = null
        }
    }

    private fun finishWithError(code: String, message: String, throwable: Throwable? = null) {
        synchronized(this) {
            pendingResult?.error(code, message, throwable?.localizedMessage)
            pendingResult = null
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        activity = binding.activity
        activityBinding?.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
        // pendingResult is intentionally NOT cleared here so the scan
        // can still complete after a config change (e.g. device rotation).
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
        activity = binding.activity
        activityBinding?.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
        // Do NOT clear pendingResult or call error() here.
        // If the OS kills the Activity for memory while the Scanner is open,
        // we want the result to be delivered when the Activity is recreated
        // and reattached, assuming the FlutterEngine/Process is still alive.
    }
}

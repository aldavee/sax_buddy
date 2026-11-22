package com.aldavelabs.sax_buddy

import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.aldavelabs.sax_buddy/app_updater"
    private val connectivityChannelName = "com.aldavelabs.sax_buddy/connectivity"

    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingInstallApkPath: String? = null
    private var connectivitySink: EventChannel.EventSink? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var lastReportedOnline: Boolean? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAppVersion" -> {
                        try {
                            val pInfo: PackageInfo = packageManager.getPackageInfo(packageName, 0)
                            val versionName = pInfo.versionName ?: "1.0.0"
                            val rawVersionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                pInfo.longVersionCode
                            } else {
                                @Suppress("DEPRECATION")
                                pInfo.versionCode.toLong()
                            }
                            val versionCode = if (rawVersionCode > 1000L) {
                                rawVersionCode % 1000L
                            } else {
                                rawVersionCode
                            }
                            result.success(
                                mapOf(
                                    "versionName" to versionName,
                                    "versionCode" to versionCode,
                                    "rawVersionCode" to rawVersionCode,
                                    "fullVersion" to "$versionName+$versionCode",
                                    "abis" to Build.SUPPORTED_ABIS.toList(),
                                    "cacheDir" to cacheDir.absolutePath
                                )
                            )
                        } catch (e: Exception) {
                            result.error("VERSION_ERROR", e.message, null)
                        }
                    }

                    "installApk" -> {
                        val filePath = call.argument<String>("filePath")
                        if (filePath.isNullOrBlank()) {
                            result.error("INVALID_PATH", "APK file path is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val apkFile = File(filePath)
                            if (!apkFile.exists()) {
                                result.error("FILE_NOT_FOUND", "APK file not found at $filePath", null)
                                return@setMethodCallHandler
                            }

                            if (hasSignatureConflict(apkFile)) {
                                try {
                                    apkFile.delete()
                                } catch (_: Exception) {
                                }
                                result.success("SIGNATURE_CONFLICT")
                                return@setMethodCallHandler
                            }

                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                                !packageManager.canRequestPackageInstalls()
                            ) {
                                pendingInstallApkPath = filePath
                                val settingsIntent = Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName")
                                ).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(settingsIntent)
                                result.success("PERMISSION_REQUIRED")
                            } else {
                                pendingInstallApkPath = null
                                launchPackageInstaller(apkFile)
                                result.success("INSTALL_STARTED")
                            }
                        } catch (e: Exception) {
                            result.error("INSTALL_ERROR", e.message, null)
                        }
                    }

                    "cleanDownloads" -> {
                        try {
                            val updatesDir = File(cacheDir, "updates")
                            if (updatesDir.exists() && updatesDir.isDirectory) {
                                updatesDir.listFiles()?.forEach { file ->
                                    if (file.isFile && (file.name.endsWith(".apk") || file.name.endsWith(".part"))) {
                                        file.delete()
                                    }
                                }
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("CLEAN_ERROR", e.message, null)
                        }
                    }

                    "isEmulator" -> result.success(isEmulatorDevice())
                    "isOnline" -> result.success(checkIsOnline())
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, connectivityChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    connectivitySink = events
                    registerConnectivityCallback()
                    dispatchConnectivityState()
                }

                override fun onCancel(arguments: Any?) {
                    unregisterConnectivityCallback()
                    connectivitySink = null
                    lastReportedOnline = null
                }
            })
    }

    private fun checkIsOnline(): Boolean {
        return try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                ?: return false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val network = cm.activeNetwork ?: return false
                val caps = cm.getNetworkCapabilities(network) ?: return false
                caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                    (caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) ||
                        caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                        caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ||
                        caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET))
            } else {
                @Suppress("DEPRECATION")
                cm.activeNetworkInfo?.isConnected == true
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun dispatchConnectivityState() {
        mainHandler.post {
            val online = checkIsOnline()
            if (lastReportedOnline != online) {
                lastReportedOnline = online
                connectivitySink?.success(online)
            }
        }
    }

    private fun registerConnectivityCallback() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N || networkCallback != null) return
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return
            val cb = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) = dispatchConnectivityState()
                override fun onLost(network: Network) = dispatchConnectivityState()
                override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) =
                    dispatchConnectivityState()
            }
            cm.registerDefaultNetworkCallback(cb)
            networkCallback = cb
        } catch (_: Exception) {
        }
    }

    private fun unregisterConnectivityCallback() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        val cb = networkCallback ?: return
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            cm?.unregisterNetworkCallback(cb)
        } catch (_: Exception) {
        } finally {
            networkCallback = null
        }
    }

    private fun isEmulatorDevice(): Boolean {
        return (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))
            || Build.FINGERPRINT.startsWith("generic")
            || Build.FINGERPRINT.startsWith("unknown")
            || Build.HARDWARE.contains("goldfish")
            || Build.HARDWARE.contains("ranchu")
            || Build.MODEL.contains("google_sdk")
            || Build.MODEL.contains("Emulator")
            || Build.MODEL.contains("Android SDK built for x86")
            || Build.MANUFACTURER.contains("Genymotion")
            || Build.PRODUCT.startsWith("sdk_")
            || Build.PRODUCT.contains("google_sdk")
            || Build.PRODUCT.contains("sdk_gphone")
            || Build.PRODUCT.contains("vbox86p")
            || Build.PRODUCT.contains("emulator")
            || Build.PRODUCT.contains("simulator")
    }

    private fun hasSignatureConflict(apkFile: File): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val installedInfo = packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES
                )
                val archiveInfo = packageManager.getPackageArchiveInfo(
                    apkFile.absolutePath,
                    PackageManager.GET_SIGNING_CERTIFICATES
                ) ?: return false

                val installedSigs = installedInfo.signingInfo?.apkContentsSigners
                    ?.map { it.toByteArray().contentHashCode() }
                    ?.toSet() ?: emptySet()
                val archiveSigs = archiveInfo.signingInfo?.apkContentsSigners
                    ?.map { it.toByteArray().contentHashCode() }
                    ?.toSet() ?: emptySet()

                installedSigs.isNotEmpty() && archiveSigs.isNotEmpty() &&
                    installedSigs.intersect(archiveSigs).isEmpty()
            } else {
                false
            }
        } catch (_: Exception) {
            false
        }
    }

    override fun onResume() {
        super.onResume()
        val path = pendingInstallApkPath
        if (path != null &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.canRequestPackageInstalls()
        ) {
            pendingInstallApkPath = null
            val apkFile = File(path)
            if (apkFile.exists()) {
                try {
                    launchPackageInstaller(apkFile)
                } catch (_: Exception) {
                }
            }
        }
    }

    private fun launchPackageInstaller(apkFile: File) {
        val apkUri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            apkFile
        )
        val installIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(installIntent)
    }

    override fun onDestroy() {
        unregisterConnectivityCallback()
        connectivitySink = null
        super.onDestroy()
    }
}

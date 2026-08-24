package com.proxyapp.app

import android.app.Activity
import android.app.ActivityManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ResultReceiver
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.proxyapp.app/vpn"
        private const val VPN_PERMISSION_REQUEST = 1989
    }

    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "prepare" -> prepareVpn(result)
                    "establish" -> sendServiceCommand(
                        ProxyVpnService.ACTION_ESTABLISH,
                        result,
                        call.arguments as? Map<*, *>,
                    )
                    "commitFd" -> sendServiceCommand(
                        ProxyVpnService.ACTION_COMMIT_FD,
                        result,
                        mapOf(ProxyVpnService.EXTRA_TUN_FD to call.argument<Int>(ProxyVpnService.EXTRA_TUN_FD)),
                    )
                    "stop" -> sendServiceCommand(ProxyVpnService.ACTION_STOP, result)
                    "updateTraffic" -> sendServiceCommand(
                        ProxyVpnService.ACTION_UPDATE_TRAFFIC,
                        result,
                        call.arguments as? Map<*, *>,
                    )
                    "appBehavior" -> applyAppBehavior(
                        call.argument<Boolean>("hideLauncher") == true,
                        call.argument<Boolean>("hideRecents") == true,
                        result,
                    )
                    "status" -> result.success(statusMap())
                    else -> result.notImplemented()
                }
            }
    }

    private fun prepareVpn(result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent == null) {
            result.success(okMap("permission_already_granted"))
            return
        }
        if (pendingPermissionResult != null) {
            result.error("permission_pending", "VPN permission request is already active", null)
            return
        }
        pendingPermissionResult = result
        startActivityForResult(intent, VPN_PERMISSION_REQUEST)
    }

    @Deprecated("Deprecated in Android API")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != VPN_PERMISSION_REQUEST) return
        val result = pendingPermissionResult ?: return
        pendingPermissionResult = null
        if (resultCode == Activity.RESULT_OK) {
            result.success(okMap("permission_granted"))
        } else {
            result.error("permission_denied", "VPN permission was denied", null)
        }
    }

    private fun applyAppBehavior(
        hideLauncher: Boolean,
        hideRecents: Boolean,
        result: MethodChannel.Result,
    ) {
        runCatching {
            val launcher = ComponentName(packageName, "$packageName.LauncherActivity")
            packageManager.setComponentEnabledSetting(
                launcher,
                if (hideLauncher) PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                else PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP,
            )
            getSystemService(ActivityManager::class.java).appTasks
                .firstOrNull { it.taskInfo.taskId == taskId }
                ?.setExcludeFromRecents(hideRecents)
        }.onSuccess {
            result.success(okMap("app_behavior_updated"))
        }.onFailure {
            result.error("app_behavior_failed", it.message, null)
        }
    }

    private fun sendServiceCommand(
        action: String,
        result: MethodChannel.Result,
        arguments: Map<*, *>? = null,
    ) {
        val receiver = object : ResultReceiver(Handler(Looper.getMainLooper())) {
            override fun onReceiveResult(resultCode: Int, resultData: Bundle?) {
                val data = resultData ?: Bundle()
                if (resultCode == 0 && data.getBoolean("ok", false)) {
                    result.success(bundleToMap(data))
                } else {
                    result.error(
                        data.getString("code") ?: "vpn_service_error",
                        data.getString("message") ?: "VPN service command failed",
                        null,
                    )
                }
            }
        }

        val intent = Intent(this, ProxyVpnService::class.java).apply {
            this.action = action
            putExtra(ProxyVpnService.EXTRA_RECEIVER, receiver)
            arguments?.forEach { (rawKey, value) ->
                val key = rawKey?.toString() ?: return@forEach
                when (value) {
                    is Boolean -> putExtra(key, value)
                    is Int -> putExtra(key, value)
                    is Long -> putExtra(key, value)
                    is String -> putExtra(key, value)
                    is List<*> -> putStringArrayListExtra(
                        key,
                        ArrayList(value.mapNotNull { it?.toString() }),
                    )
                }
            }
        }
        if (action == ProxyVpnService.ACTION_ESTABLISH && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun statusMap(): Map<String, Any> = mapOf(
        "ok" to true,
        "permissionGranted" to (VpnService.prepare(this) == null),
        "serviceRunning" to ProxyVpnService.serviceRunning,
    )

    private fun okMap(message: String): Map<String, Any> = mapOf(
        "ok" to true,
        "message" to message,
    )

    private fun bundleToMap(bundle: Bundle): Map<String, Any> {
        val result = mutableMapOf<String, Any>()
        for (key in bundle.keySet()) bundle.get(key)?.let { result[key] = it }
        return result
    }
}

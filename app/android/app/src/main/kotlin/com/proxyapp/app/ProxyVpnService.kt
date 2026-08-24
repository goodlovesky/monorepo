package com.proxyapp.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ProxyInfo
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.os.ResultReceiver
import android.util.Log
import androidx.core.app.NotificationCompat

class ProxyVpnService : VpnService() {
    companion object {
        const val ACTION_ESTABLISH = "com.proxyapp.app.vpn.ESTABLISH"
        const val ACTION_COMMIT_FD = "com.proxyapp.app.vpn.COMMIT_FD"
        const val ACTION_STOP = "com.proxyapp.app.vpn.STOP"
        const val ACTION_UPDATE_TRAFFIC = "com.proxyapp.app.vpn.UPDATE_TRAFFIC"
        const val EXTRA_RECEIVER = "receiver"
        const val EXTRA_TUN_FD = "tunFd"

        private const val CHANNEL_ID = "proxy_vpn"
        private const val NOTIFICATION_ID = 1989
        private const val TAG = "ProxyVpnService"

        @Volatile
        var serviceRunning: Boolean = false
            private set
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var pendingTunFd: Int = -1
    private var showTraffic = true
    private var trafficBytes = 0L

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val receiver = intent?.resultReceiver()
        when (intent?.action) {
            ACTION_ESTABLISH -> establish(intent, receiver)
            ACTION_COMMIT_FD -> commitFd(intent.getIntExtra(EXTRA_TUN_FD, -1), receiver)
            ACTION_UPDATE_TRAFFIC -> updateTraffic(
                intent.getLongExtra("bytes", 0L),
                intent.getBooleanExtra("showTraffic", true),
                receiver,
            )
            ACTION_STOP -> stopVpn(receiver)
            else -> receiver?.failure("unknown_action", "Unknown VPN service action")
        }
        return Service.START_NOT_STICKY
    }

    override fun onRevoke() {
        stopVpn(null)
        super.onRevoke()
    }

    override fun onDestroy() {
        closeResources()
        super.onDestroy()
    }

    private fun establish(intent: Intent, receiver: ResultReceiver?) {
        if (vpnInterface != null && pendingTunFd >= 0) {
            receiver?.success(Bundle().apply { putInt(EXTRA_TUN_FD, pendingTunFd) })
            return
        }

        try {
            showTraffic = true
            startAsForeground()
            val systemProxyRequested =
                intent.getBooleanExtra("systemProxy", true) &&
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
            var systemProxyApplied = false
            var systemProxyWarning: String? = null
            val established = establishWithSystemProxyFallback(
                systemProxyRequested = systemProxyRequested,
                establish = { includeSystemProxy ->
                    createBuilder(intent, includeSystemProxy).establish()
                        ?: error("VpnService.Builder.establish returned null")
                },
                onFallback = { error ->
                    systemProxyWarning = error.message ?: error.javaClass.simpleName
                    Log.w(
                        TAG,
                        "System proxy was rejected; retrying VPN without HTTP proxy",
                        error,
                    )
                },
            ).also {
                systemProxyApplied = systemProxyRequested && systemProxyWarning == null
            }
            vpnInterface = established
            pendingTunFd = ParcelFileDescriptor.dup(established.fileDescriptor).detachFd()
            serviceRunning = true
            receiver?.success(Bundle().apply {
                putInt(EXTRA_TUN_FD, pendingTunFd)
                putBoolean("systemProxyApplied", systemProxyApplied)
                systemProxyWarning?.let { putString("systemProxyWarning", it) }
            })
        } catch (error: Throwable) {
            closeResources()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            receiver?.failure("establish_failed", error.message ?: error.javaClass.simpleName)
        }
    }

    private fun createBuilder(intent: Intent, includeSystemProxy: Boolean): Builder {
        val autoRoute = intent.getBooleanExtra("autoRoute", true)
        val bypassPrivate = intent.getBooleanExtra("bypassPrivate", true)
        val allowBypass = intent.getBooleanExtra("allowBypass", true)
        val ipv6 = intent.getBooleanExtra("ipv6", false)
        val accessMode = intent.getStringExtra("accessMode") ?: "all"
        val accessPackages = intent.getStringArrayListExtra("accessPackages") ?: arrayListOf()
        val builder = Builder()
            .setSession("Clash RS")
            .setMtu(1500)
            .addAddress("198.18.0.1", 24)
            .addDnsServer("1.1.1.1")
            .addDnsServer("8.8.8.8")
            .setConfigureIntent(mainActivityPendingIntent())

        if (autoRoute) {
            if (bypassPrivate) addPublicIpv4Routes(builder)
            else builder.addRoute("0.0.0.0", 0)
        }
        if (ipv6) {
            builder.addAddress("fdfe:dcba:9876::1", 126)
            if (autoRoute) builder.addRoute("::", 0)
            builder.addDnsServer("2606:4700:4700::1111")
        }
        if (allowBypass) builder.allowBypass()
        when (accessMode) {
            "allow" -> accessPackages.forEach { allowed ->
                runCatching { builder.addAllowedApplication(allowed) }
            }
            "deny" -> {
                builder.addDisallowedApplication(packageName)
                accessPackages.forEach { blocked ->
                    runCatching { builder.addDisallowedApplication(blocked) }
                }
            }
            else -> builder.addDisallowedApplication(packageName)
        }
        if (includeSystemProxy) {
            val mixedPort = intent.getIntExtra("mixedPort", 17892).coerceIn(1, 65535)
            builder.setHttpProxy(ProxyInfo.buildDirectProxy("127.0.0.1", mixedPort))
        }
        return builder
    }

    private fun commitFd(fd: Int, receiver: ResultReceiver?) {
        if (fd <= 0 || pendingTunFd != fd) {
            receiver?.failure("fd_mismatch", "TUN file descriptor does not match pending descriptor")
            return
        }
        pendingTunFd = -1
        receiver?.success()
    }

    private fun addPublicIpv4Routes(builder: Builder) {
        // Complement of RFC1918, loopback and link-local ranges. Using include
        // routes works on Android builds that reject Builder.excludeRoute().
        listOf(
            "1.0.0.0" to 8, "2.0.0.0" to 7, "4.0.0.0" to 6, "8.0.0.0" to 7,
            "11.0.0.0" to 8, "12.0.0.0" to 6, "16.0.0.0" to 4,
            "32.0.0.0" to 3, "64.0.0.0" to 3, "96.0.0.0" to 4,
            "112.0.0.0" to 5, "120.0.0.0" to 6, "124.0.0.0" to 7,
            "126.0.0.0" to 8, "128.0.0.0" to 3, "160.0.0.0" to 5,
            "168.0.0.0" to 8, "169.0.0.0" to 16, "169.128.0.0" to 18,
            "169.192.0.0" to 19, "169.224.0.0" to 20, "169.240.0.0" to 21,
            "169.248.0.0" to 22, "169.252.0.0" to 23, "169.255.0.0" to 24,
            "170.0.0.0" to 7, "172.0.0.0" to 12, "172.32.0.0" to 11,
            "172.64.0.0" to 10, "172.128.0.0" to 9, "173.0.0.0" to 8,
            "174.0.0.0" to 7, "176.0.0.0" to 4, "192.0.0.0" to 9,
            "192.128.0.0" to 11, "192.160.0.0" to 13, "192.169.0.0" to 16,
            "192.170.0.0" to 15, "192.172.0.0" to 14, "192.176.0.0" to 12,
            "192.192.0.0" to 10, "193.0.0.0" to 8, "194.0.0.0" to 7,
            "196.0.0.0" to 6, "200.0.0.0" to 5, "208.0.0.0" to 4,
        ).forEach { (address, prefix) -> builder.addRoute(address, prefix) }
    }

    private fun updateTraffic(bytes: Long, show: Boolean, receiver: ResultReceiver?) {
        showTraffic = show
        trafficBytes = bytes.coerceAtLeast(0L)
        if (serviceRunning) {
            getSystemService(NotificationManager::class.java)
                .notify(NOTIFICATION_ID, buildNotification())
        }
        receiver?.success()
    }

    private fun stopVpn(receiver: ResultReceiver?) {
        closeResources()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        receiver?.success()
    }

    private fun closeResources() {
        if (pendingTunFd >= 0) {
            runCatching { ParcelFileDescriptor.adoptFd(pendingTunFd).close() }
            pendingTunFd = -1
        }
        runCatching { vpnInterface?.close() }
        vpnInterface = null
        serviceRunning = false
    }

    private fun startAsForeground() {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "代理 VPN", NotificationManager.IMPORTANCE_LOW),
            )
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                buildNotification(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, buildNotification())
        }
    }

    private fun buildNotification(): Notification {
        val text = if (showTraffic) "${formatBytes(trafficBytes)} 已转发" else "全设备流量已由 VPN 接管"
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Clash RS 正在运行")
            .setContentText(text)
            .setContentIntent(mainActivityPendingIntent())
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun formatBytes(bytes: Long): String {
        if (bytes < 1024) return "$bytes B"
        val units = arrayOf("KiB", "MiB", "GiB", "TiB")
        var value = bytes.toDouble() / 1024.0
        var unit = 0
        while (value >= 1024 && unit < units.lastIndex) {
            value /= 1024.0
            unit++
        }
        return "%.2f %s".format(value, units[unit])
    }

    private fun mainActivityPendingIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    @Suppress("DEPRECATION")
    private fun Intent.resultReceiver(): ResultReceiver? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            getParcelableExtra(EXTRA_RECEIVER, ResultReceiver::class.java)
        } else {
            getParcelableExtra(EXTRA_RECEIVER)
        }

    private fun ResultReceiver.success(data: Bundle = Bundle()) {
        data.putBoolean("ok", true)
        send(0, data)
    }

    private fun ResultReceiver.failure(code: String, message: String) {
        send(1, Bundle().apply {
            putBoolean("ok", false)
            putString("code", code)
            putString("message", message)
        })
    }
}

package com.proxyapp.app

/**
 * Some Android/OEM builds reject the HTTP proxy attached to a VPN even after
 * the user has granted the normal VpnService consent. Keep the VPN usable by
 * retrying once without that optional proxy hint.
 */
internal inline fun <T> establishWithSystemProxyFallback(
    systemProxyRequested: Boolean,
    establish: (includeSystemProxy: Boolean) -> T,
    onFallback: (Throwable) -> Unit = {},
): T {
    if (!systemProxyRequested) return establish(false)

    return try {
        establish(true)
    } catch (proxyError: Throwable) {
        onFallback(proxyError)
        try {
            establish(false)
        } catch (fallbackError: Throwable) {
            fallbackError.addSuppressed(proxyError)
            throw fallbackError
        }
    }
}

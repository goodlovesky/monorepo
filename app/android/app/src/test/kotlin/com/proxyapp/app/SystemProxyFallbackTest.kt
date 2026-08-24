package com.proxyapp.app

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertSame
import kotlin.test.assertTrue

class SystemProxyFallbackTest {
    @Test
    fun `keeps system proxy when the platform accepts it`() {
        val attempts = mutableListOf<Boolean>()

        val result = establishWithSystemProxyFallback(true, { includeProxy ->
            attempts += includeProxy
            "vpn-with-proxy"
        })

        assertEquals("vpn-with-proxy", result)
        assertEquals(listOf(true), attempts)
    }

    @Test
    fun `retries without system proxy after an admin rejection`() {
        val attempts = mutableListOf<Boolean>()
        var fallbackObserved = false

        val result = establishWithSystemProxyFallback(
            systemProxyRequested = true,
            establish = { includeProxy ->
                attempts += includeProxy
                if (includeProxy) throw SecurityException("not allowed by admin")
                "vpn-without-proxy"
            },
            onFallback = { fallbackObserved = true },
        )

        assertEquals("vpn-without-proxy", result)
        assertEquals(listOf(true, false), attempts)
        assertTrue(fallbackObserved)
    }

    @Test
    fun `does not try a proxy when the setting is disabled`() {
        var includedProxy = true

        establishWithSystemProxyFallback(false, { includeProxy ->
            includedProxy = includeProxy
        })

        assertFalse(includedProxy)
    }

    @Test
    fun `preserves both failures when the retry also fails`() {
        val adminError = SecurityException("not allowed by admin")
        val vpnError = IllegalStateException("VPN establish failed")

        val thrown = assertFailsWith<IllegalStateException> {
            establishWithSystemProxyFallback(true, { includeProxy ->
                if (includeProxy) throw adminError
                throw vpnError
            })
        }

        assertSame(vpnError, thrown)
        assertSame(adminError, thrown.suppressed.single())
    }
}

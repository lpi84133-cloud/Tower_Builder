package bc.greenfggames.towerbuilder

import android.content.Context
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Reads the Google Play Install Referrer string via a local IPC call to
 * the Play Store process. No internet access is required — the referrer
 * data is written to the device during install and is served from the
 * Play Store's local storage.
 *
 * The classification helps the loading screen decide what to show when
 * the device is offline on the very first launch:
 *
 *   • [Verdict.Attributed] — the install referrer string contains
 *     AppsFlyer / OneLink markers. The user tapped a tracked link before
 *     installing; they need internet to reach the web content →
 *     show the no-wi-fi screen.
 *
 *   • [Verdict.Organic] — the referrer is empty or carries only a plain
 *     Google Play source tag. The user found the app organically; the
 *     native game works fully offline → open the game immediately.
 *
 *   • [Verdict.Unknown] — the Play Store service did not respond in time
 *     (rare). We treat unknown as organic to avoid showing a dead-end
 *     no-wi-fi screen to someone who just wants to play.
 */
internal object ReferrerScout {

    sealed interface Verdict {
        data class Attributed(val raw: String) : Verdict
        data object Organic : Verdict
        data object Unknown : Verdict
    }

    // These token patterns are AppsFlyer / OneLink specific.
    // A referrer string containing ANY of them is treated as paid traffic.
    private val PAID_TOKENS = listOf(
        "af_tranid=",
        "af_click_lookback=",
        "af_prt=",
        "shortlink=",
        "onelink",
        "af_c_id=",
        "af_adset_id=",
    )

    // Play Store referrer for a direct organic install. Strings that
    // match this pattern (or are blank) are classified as Organic.
    private val ORGANIC_SOURCES = listOf(
        "utm_source=google-play",
        "utm_source=organic",
    )

    /**
     * Reads the Play Store referrer synchronously (via coroutine).
     * Waits at most [timeoutMs] milliseconds before returning [Verdict.Unknown].
     */
    suspend fun classify(context: Context, timeoutMs: Long = 4_000L): Verdict {
        val raw = withTimeoutOrNull(timeoutMs) { fetchReferrer(context) }
            ?: return Verdict.Unknown

        if (raw.isBlank()) return Verdict.Organic

        val lower = raw.lowercase()
        if (PAID_TOKENS.any { lower.contains(it) }) {
            return Verdict.Attributed(raw)
        }
        if (ORGANIC_SOURCES.any { lower.contains(it) }) {
            return Verdict.Organic
        }
        // Non-empty but no recognised marker — could be another tracker.
        // Treat as attributed to be safe (shows no-wi-fi rather than game).
        return Verdict.Attributed(raw)
    }

    private suspend fun fetchReferrer(context: Context): String? =
        suspendCancellableCoroutine { cont ->
            val client = InstallReferrerClient.newBuilder(context).build()

            cont.invokeOnCancellation { runCatching { client.endConnection() } }

            client.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(code: Int) {
                    val ref = when (code) {
                        InstallReferrerClient.InstallReferrerResponse.OK ->
                            runCatching { client.installReferrer.installReferrer }
                                .getOrNull() ?: ""
                        else -> null
                    }
                    runCatching { client.endConnection() }
                    if (cont.isActive) cont.resume(ref)
                }

                override fun onInstallReferrerServiceDisconnected() {
                    if (cont.isActive) cont.resume(null)
                }
            })
        }
}

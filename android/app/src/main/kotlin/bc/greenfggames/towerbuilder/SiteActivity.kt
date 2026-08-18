package bc.greenfggames.towerbuilder

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Single entry point for the build-site simulation.
 *
 * Hosts two MethodChannels:
 *
 *  1. "bc.greenfg/hoister/v2" — WebView file-upload bridge. The WebView's
 *     `<input type="file">` triggers the "pick" method; the activity runs
 *     the system chooser and returns content:// URIs to Dart. Avoids the
 *     file_picker 10.x Kotlin mismatch (gray_part_pitfalls.md §1).
 *
 *  2. "bc.greenfg/referral/v1" — Play Store Install Referrer bridge.
 *     Called by HoistRouter on the first offline launch to classify the
 *     install as paid (OneLink) or organic without needing internet.
 *     The referrer string is stored locally by the Play Store and
 *     returned via a local IPC call — no network round-trip needed.
 */
class SiteActivity : FlutterActivity() {
    // Keep in sync with lib/hoist_veil/webshell.dart → MethodChannel(...)
    private val channelName = "bc.greenfg/hoister/v2"
    private val referralChannel = "bc.greenfg/referral/v1"
    private val pickRequest = 0x8B32
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── File-pick bridge ──────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "pick") {
                    val multiple = call.argument<Boolean>("multiple") ?: false
                    val mimes = call.argument<List<String>>("mimeTypes") ?: emptyList()
                    launchChooser(multiple, mimes, result)
                } else {
                    result.notImplemented()
                }
            }

        // ── Install Referrer bridge ───────────────────────────────────
        // Dart calls "classify" on the first offline launch. We read the
        // Play Store's local referrer cache and return one of three strings:
        //   "attributed" — paid / OneLink install
        //   "organic"    — direct Play Store install
        //   "unknown"    — Play Store service unavailable (treated as organic)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, referralChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "classify") {
                    CoroutineScope(Dispatchers.IO).launch {
                        val verdict = ReferrerScout.classify(applicationContext)
                        val label = when (verdict) {
                            is ReferrerScout.Verdict.Attributed -> "attributed"
                            is ReferrerScout.Verdict.Organic    -> "organic"
                            is ReferrerScout.Verdict.Unknown    -> "unknown"
                        }
                        CoroutineScope(Dispatchers.Main).launch {
                            result.success(label)
                        }
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun launchChooser(
        multiple: Boolean,
        mimes: List<String>,
        result: MethodChannel.Result,
    ) {
        // Any orphaned result from an earlier abandoned pick collapses to
        // an empty list before starting the new one.
        pendingResult?.success(emptyList<String>())
        pendingResult = result

        val valid = mimes.filter { it.contains("/") }
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
            when {
                valid.isEmpty() -> type = "*/*"
                valid.size == 1 -> type = valid[0]
                else -> {
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, valid.toTypedArray())
                }
            }
        }

        try {
            startActivityForResult(Intent.createChooser(intent, null), pickRequest)
        } catch (e: Exception) {
            pendingResult = null
            result.success(emptyList<String>())
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickRequest) return

        val result = pendingResult
        pendingResult = null
        if (result == null) return

        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<String>())
            return
        }

        val picked = ArrayList<String>()
        val clip = data.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) {
                picked.add(clip.getItemAt(i).uri.toString())
            }
        } else {
            data.data?.let { picked.add(it.toString()) }
        }
        result.success(picked)
    }
}

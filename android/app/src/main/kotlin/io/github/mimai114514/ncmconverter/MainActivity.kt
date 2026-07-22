package io.github.mimai114514.ncmconverter

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "io.github.mimai114514.ncmconverter/folder"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openFolder" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "path is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(openFolder(path))
                        } catch (e: Exception) {
                            result.error("OPEN_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * 在系统文件管理器中打开指定目录。
     * 优先使用 DocumentsUI 的 content URI，失败时再尝试 resource/folder 兼容方案。
     */
    private fun openFolder(path: String): Boolean {
        val directory = File(path)
        if (!directory.exists()) {
            return false
        }

        val absolutePath = directory.absolutePath

        // 方案 1：DocumentsUI content URI（Android 官方文件管理器）
        val documentUri = pathToDocumentUri(absolutePath)
        if (documentUri != null && tryStartViewIntent(documentUri, DocumentsContract.Document.MIME_TYPE_DIR)) {
            return true
        }

        // 方案 2：部分第三方文件管理器支持的 resource/folder
        if (tryStartViewIntent(Uri.fromFile(directory), "resource/folder")) {
            return true
        }

        // 方案 3：file:// URI + 目录 MIME
        if (tryStartViewIntent(Uri.fromFile(directory), DocumentsContract.Document.MIME_TYPE_DIR)) {
            return true
        }

        return false
    }

    private fun tryStartViewIntent(uri: Uri, mimeType: String): Boolean {
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        // 部分设备在 package visibility 下 resolveActivity 会返回 null，仍直接尝试启动
        return try {
            startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        } catch (_: Exception) {
            false
        }
    }

    /**
     * 将本地绝对路径转换为 DocumentsProvider 的 document URI。
     * 例如：/storage/emulated/0/Music -> content://.../document/primary%3AMusic
     */
    private fun pathToDocumentUri(path: String): Uri? {
        val primaryRoot = Environment.getExternalStorageDirectory().absolutePath
        if (path == primaryRoot || path.startsWith("$primaryRoot/")) {
            val relative = path.removePrefix(primaryRoot).trimStart('/')
            val docId = if (relative.isEmpty()) "primary:" else "primary:$relative"
            return DocumentsContract.buildDocumentUri(EXTERNAL_STORAGE_AUTHORITY, docId)
        }

        // 外置 SD 卡等：/storage/XXXX-XXXX/path
        val storageMatch = STORAGE_VOLUME_REGEX.find(path) ?: return null
        val volumeId = storageMatch.groupValues[1]
        val relative = storageMatch.groupValues[2]
        if (volumeId.equals("emulated", ignoreCase = true)) {
            return null
        }
        val docId = if (relative.isEmpty()) "$volumeId:" else "$volumeId:$relative"
        return DocumentsContract.buildDocumentUri(EXTERNAL_STORAGE_AUTHORITY, docId)
    }

    companion object {
        private const val EXTERNAL_STORAGE_AUTHORITY = "com.android.externalstorage.documents"
        private val STORAGE_VOLUME_REGEX = Regex("^/storage/([^/]+)(?:/(.*))?$")
    }
}

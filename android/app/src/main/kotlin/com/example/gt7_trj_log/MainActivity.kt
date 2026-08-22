package com.example.gt7_trj_log

import android.content.ContentResolver
import android.content.ContentUris
import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// ダウンロードフォルダ配下の1ファイルにログを追記していくためのネイティブ実装。
// MediaStore経由なので、特別な権限なしにDownload/GT7LapAnalyzer/配下へ書き込める。
// Appends log text into a single file under the public Downloads folder, via
// MediaStore — no special storage permission is required for this.
class MainActivity : FlutterActivity() {
    private val channelName = "gt7_trj_log/downloads_log"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "appendToDownloadsLog") {
                    try {
                        val folderName = call.argument<String>("folderName")!!
                        val fileName = call.argument<String>("fileName")!!
                        val text = call.argument<String>("text")!!
                        appendToDownloadsLog(folderName, fileName, text)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("APPEND_FAILED", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun appendToDownloadsLog(folderName: String, fileName: String, text: String) {
        val bytes = text.toByteArray(Charsets.UTF_8)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = contentResolver
            val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
            val relativePath = "${Environment.DIRECTORY_DOWNLOADS}/$folderName/"

            val existingUri = findExisting(resolver, collection, relativePath, fileName)
            val targetUri = existingUri ?: run {
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                    put(MediaStore.Downloads.MIME_TYPE, "text/plain")
                    put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
                }
                resolver.insert(collection, values)
                    ?: throw IllegalStateException("MediaStore insert failed")
            }
            val mode = if (existingUri != null) "wa" else "w"
            resolver.openOutputStream(targetUri, mode)?.use { it.write(bytes) }
        } else {
            // Android 9以前はレガシーなファイルアクセスで書き込む
            // Pre-Q devices fall back to direct legacy file access
            val dir = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                folderName,
            )
            if (!dir.exists()) dir.mkdirs()
            File(dir, fileName).appendBytes(bytes)
        }
    }

    private fun findExisting(
        resolver: ContentResolver,
        collection: Uri,
        relativePath: String,
        fileName: String,
    ): Uri? {
        val projection = arrayOf(MediaStore.Downloads._ID)
        val selection =
            "${MediaStore.Downloads.RELATIVE_PATH}=? AND ${MediaStore.Downloads.DISPLAY_NAME}=?"
        val selectionArgs = arrayOf(relativePath, fileName)
        resolver.query(collection, projection, selection, selectionArgs, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Downloads._ID))
                return ContentUris.withAppendedId(collection, id)
            }
        }
        return null
    }
}

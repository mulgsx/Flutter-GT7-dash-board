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
            if (existingUri != null) {
                resolver.openOutputStream(existingUri, "wa")?.use { it.write(bytes) }
                return
            }

            try {
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                    put(MediaStore.Downloads.MIME_TYPE, "text/plain")
                    put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
                }
                val insertedUri = resolver.insert(collection, values)
                    ?: throw IllegalStateException("MediaStore insert failed")
                resolver.openOutputStream(insertedUri, "w")?.use { it.write(bytes) }
            } catch (e: Exception) {
                // MediaStoreの一意ファイル名生成がまれに失敗することがある(端末上に
                // 名前解決できない孤立レコードが残っている場合など)。ここで失敗すると
                // 走行データが丸ごと失われるため、タイムスタンプ付きの別名で
                // フォールバック保存し、ログ自体は必ず残るようにする
                // MediaStore's unique-name generation can occasionally fail (e.g. stale
                // orphaned records it can't resolve against). Failing here would lose
                // the whole lap's data, so fall back to a timestamped alternate name so
                // the log is never silently dropped.
                val fallbackName = fileNameWithSuffix(fileName, System.currentTimeMillis().toString())
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, fallbackName)
                    put(MediaStore.Downloads.MIME_TYPE, "text/plain")
                    put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
                }
                val fallbackUri = resolver.insert(collection, values)
                    ?: throw e
                resolver.openOutputStream(fallbackUri, "w")?.use { it.write(bytes) }
            }
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

    private fun fileNameWithSuffix(fileName: String, suffix: String): String {
        val dotIndex = fileName.lastIndexOf('.')
        return if (dotIndex == -1) {
            "${fileName}_$suffix"
        } else {
            "${fileName.substring(0, dotIndex)}_$suffix${fileName.substring(dotIndex)}"
        }
    }

    // DISPLAY_NAMEのみで広く検索し、RELATIVE_PATHはKotlin側で正規化してから照合する。
    // SQL側の完全一致(末尾スラッシュの有無など)で本来存在するはずのレコードを
    // 見逃すと、insert()が同名ファイルの一意化に失敗して丸ごとクラッシュする
    // (実機で "Failed to build unique file" として発生した不具合)
    // Searches broadly by DISPLAY_NAME alone, then normalizes and compares
    // RELATIVE_PATH in Kotlin. Missing an existing row due to an exact SQL
    // string mismatch (e.g. a trailing slash) leads insert() to fail unique-
    // naming the file, crashing the whole call (seen on-device as "Failed to
    // build unique file").
    private fun findExisting(
        resolver: ContentResolver,
        collection: Uri,
        relativePath: String,
        fileName: String,
    ): Uri? {
        val projection = arrayOf(MediaStore.Downloads._ID, MediaStore.Downloads.RELATIVE_PATH)
        val selection = "${MediaStore.Downloads.DISPLAY_NAME}=?"
        val selectionArgs = arrayOf(fileName)
        val normalizedTarget = relativePath.trim('/')
        resolver.query(collection, projection, selection, selectionArgs, null)?.use { cursor ->
            val pathIndex = cursor.getColumnIndexOrThrow(MediaStore.Downloads.RELATIVE_PATH)
            val idIndex = cursor.getColumnIndexOrThrow(MediaStore.Downloads._ID)
            while (cursor.moveToNext()) {
                val candidatePath = (cursor.getString(pathIndex) ?: "").trim('/')
                if (candidatePath.equals(normalizedTarget, ignoreCase = true)) {
                    return ContentUris.withAppendedId(collection, cursor.getLong(idIndex))
                }
            }
        }
        return null
    }
}

package com.guitarpal.guitar_pal

import android.app.Activity
import android.content.Intent
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class LocalVideoImportPlugin(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private var pendingPickerResult: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickVideo" -> pickVideo(call.argument<String>("source"), result)
            "commitDraft" -> commitDraft(
                call.argument<String>("draftPath"),
                call.argument<String>("sourceId"),
                result,
            )
            "discardDraft" -> deleteValidatedFile(
                call.argument<String>("path"),
                draftDirectory(),
                result,
            )
            "deleteManagedVideo" -> deleteValidatedFile(
                call.argument<String>("path"),
                managedDirectory(),
                result,
            )
            else -> result.notImplemented()
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_VIDEO_REQUEST) return false
        val result = pendingPickerResult ?: return true
        pendingPickerResult = null

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }

        Thread {
            var draftFile: File? = null
            try {
                val displayName = queryDisplayName(uri) ?: "本地视频.mp4"
                val extension = safeExtension(displayName, uri)
                val directory = draftDirectory().apply { mkdirs() }
                val targetFile = File(directory, "${UUID.randomUUID()}.$extension")
                draftFile = targetFile
                val input = activity.contentResolver.openInputStream(uri)
                    ?: throw IllegalStateException("无法打开所选视频")
                input.use { source ->
                    targetFile.outputStream().use { target -> source.copyTo(target) }
                }
                if (targetFile.length() <= 0L) {
                    throw IllegalStateException("所选视频是空文件")
                }
                val info = readVideoInfo(targetFile, displayName)
                activity.runOnUiThread { result.success(info) }
            } catch (error: Throwable) {
                draftFile?.delete()
                activity.runOnUiThread {
                    result.error(
                        "video_copy_failed",
                        error.message ?: "无法复制所选视频",
                        null,
                    )
                }
            }
        }.start()
        return true
    }

    fun dispose() {
        pendingPickerResult?.error(
            "picker_closed",
            "视频选择器已关闭",
            null,
        )
        pendingPickerResult = null
        channel.setMethodCallHandler(null)
    }

    private fun pickVideo(source: String?, result: MethodChannel.Result) {
        if (pendingPickerResult != null) {
            result.error("picker_busy", "已有视频选择器正在打开", null)
            return
        }

        val intent = when (source) {
            "gallery" -> galleryIntent()
            "files" -> documentIntent()
            else -> {
                result.error("invalid_source", "未知的视频来源", null)
                return
            }
        }

        pendingPickerResult = result
        try {
            activity.startActivityForResult(intent, PICK_VIDEO_REQUEST)
        } catch (error: Throwable) {
            pendingPickerResult = null
            result.error(
                "picker_unavailable",
                error.message ?: "系统中没有可用的视频选择器",
                null,
            )
        }
    }

    private fun galleryIntent(): Intent {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return Intent(MediaStore.ACTION_PICK_IMAGES).apply {
                type = "video/*"
            }
        }
        return documentIntent()
    }

    private fun documentIntent(): Intent {
        return Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "video/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
    }

    private fun commitDraft(
        draftPath: String?,
        sourceId: String?,
        result: MethodChannel.Result,
    ) {
        if (draftPath.isNullOrBlank() || sourceId.isNullOrBlank()) {
            result.error("invalid_draft", "导入草稿信息不完整", null)
            return
        }
        if (!sourceId.matches(Regex("^[A-Za-z0-9_-]+$"))) {
            result.error("invalid_source_id", "练习来源 ID 无效", null)
            return
        }

        Thread {
            var destination: File? = null
            try {
                val draft = File(draftPath)
                if (!isInside(draft, draftDirectory()) || !draft.isFile) {
                    throw IllegalArgumentException("视频草稿已经失效")
                }
                val extension = draft.extension.ifBlank { "mp4" }
                val directory = managedDirectory().apply { mkdirs() }
                val targetFile = File(directory, "$sourceId.$extension")
                destination = targetFile
                if (!draft.renameTo(targetFile)) {
                    draft.inputStream().use { source ->
                        targetFile.outputStream().use { target -> source.copyTo(target) }
                    }
                    if (!draft.delete()) {
                        throw IllegalStateException("无法清理视频草稿")
                    }
                }
                val info = readVideoInfo(targetFile, targetFile.name)
                activity.runOnUiThread { result.success(info) }
            } catch (error: Throwable) {
                destination?.delete()
                activity.runOnUiThread {
                    result.error(
                        "commit_failed",
                        error.message ?: "无法保存本地视频",
                        null,
                    )
                }
            }
        }.start()
    }

    private fun deleteValidatedFile(
        path: String?,
        root: File,
        result: MethodChannel.Result,
    ) {
        if (path.isNullOrBlank()) {
            result.success(null)
            return
        }
        Thread {
            try {
                val file = File(path)
                if (isInside(file, root) && file.exists() && !file.delete()) {
                    throw IllegalStateException("无法删除本地视频文件")
                }
                activity.runOnUiThread { result.success(null) }
            } catch (error: Throwable) {
                activity.runOnUiThread {
                    result.error(
                        "delete_failed",
                        error.message ?: "无法清理本地视频",
                        null,
                    )
                }
            }
        }.start()
    }

    private fun queryDisplayName(uri: Uri): String? {
        return activity.contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (!cursor.moveToFirst()) return@use null
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index < 0) null else cursor.getString(index)
        }
    }

    private fun safeExtension(displayName: String, uri: Uri): String {
        val fromName = displayName.substringAfterLast('.', "")
            .lowercase()
            .takeIf { it.matches(Regex("^[a-z0-9]{1,8}$")) }
        if (fromName != null) return fromName

        val mime = activity.contentResolver.getType(uri)
        return MimeTypeMap.getSingleton().getExtensionFromMimeType(mime)
            ?.lowercase()
            ?.takeIf { it.matches(Regex("^[a-z0-9]{1,8}$")) }
            ?: "mp4"
    }

    private fun readVideoInfo(file: File, displayName: String): Map<String, Any> {
        val retriever = MediaMetadataRetriever()
        var duration = 0L
        var width = 0
        var height = 0
        try {
            retriever.setDataSource(file.absolutePath)
            duration = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull() ?: 0L
            width = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                ?.toIntOrNull() ?: 0
            height = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                ?.toIntOrNull() ?: 0
        } finally {
            retriever.release()
        }
        return mapOf(
            "path" to file.absolutePath,
            "displayName" to displayName,
            "sizeBytes" to file.length(),
            "durationMilliseconds" to duration,
            "width" to width,
            "height" to height,
        )
    }

    private fun isInside(file: File, root: File): Boolean {
        val rootPath = root.canonicalFile.path + File.separator
        return file.canonicalFile.path.startsWith(rootPath)
    }

    private fun draftDirectory() = File(activity.cacheDir, "guitarpal_video_drafts")

    private fun managedDirectory() = File(activity.filesDir, "guitarpal_videos")

    companion object {
        private const val CHANNEL_NAME = "com.guitarpal/local_video_import"
        private const val PICK_VIDEO_REQUEST = 42061
    }
}

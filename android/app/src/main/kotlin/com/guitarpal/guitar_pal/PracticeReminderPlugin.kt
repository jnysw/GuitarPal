package com.guitarpal.guitar_pal

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class PracticeReminderPlugin(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, channelName)
    private var pendingPermissionResult: MethodChannel.Result? = null

    init {
        PracticeReminderScheduler.initialize(activity.applicationContext)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestPermission" -> requestPermission(result)
            "synchronize" -> {
                val values = call.argument<List<Map<*, *>>>("reminders").orEmpty()
                PracticeReminderScheduler.synchronize(activity.applicationContext, values)
                result.success(null)
            }
            "cancelAll" -> {
                PracticeReminderScheduler.cancelAll(activity.applicationContext)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != notificationPermissionRequestCode) return false
        val result = pendingPermissionResult ?: return true
        pendingPermissionResult = null
        val granted = permissions.indices.any { index ->
            permissions[index] == Manifest.permission.POST_NOTIFICATIONS &&
                grantResults.getOrNull(index) == PackageManager.PERMISSION_GRANTED
        }
        result.success(granted)
        return true
    }

    fun dispose() {
        pendingPermissionResult?.error(
            "permission_request_closed",
            "通知权限请求已关闭",
            null,
        )
        pendingPermissionResult = null
        channel.setMethodCallHandler(null)
    }

    private fun requestPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        if (
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("permission_request_busy", "通知权限正在请求中", null)
            return
        }
        pendingPermissionResult = result
        activity.requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            notificationPermissionRequestCode,
        )
    }

    companion object {
        private const val channelName = "com.guitarpal/practice_reminders"
        private const val notificationPermissionRequestCode = 7412
    }
}

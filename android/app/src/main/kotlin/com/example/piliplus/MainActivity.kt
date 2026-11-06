package com.example.piliplus

import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.view.WindowManager.LayoutParams
import io.flutter.embedding.android.FlutterActivity

/**
 * 主 Activity。
 *
 * 原件继承的是 `com.ryanheise.audioservice.AudioServiceActivity`，但 pubspec 里
 * 并没有 `audio_service` / `just_audio` 这两个依赖（作者是从 PiliPlus 抄过来忘改了），
 * 导致 Android 端 `:app:compileReleaseKotlin` 直接报
 * `Unresolved reference 'ryanheise'`，整个 APK 编不出来。
 *
 * 这里换回 Flutter 官方的 FlutterActivity。播放用它自己的原生实现
 * （media_kit / libmpv），不依赖 audio_service 的前台 Service。
 * 原来 onDestroy 里那句 stopService(AudioService) 也一并去掉。
 */
class MainActivity : FlutterActivity() {
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (AndroidHelper.isFoldable) {
            AndroidHelper.ToDart.onConfigurationChanged?.run()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 刘海屏铺满：播放页要贴到屏幕四边
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        AndroidHelper.ToDart.onUserLeaveHint?.run()
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration?
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        AndroidHelper.isPipMode = isInPictureInPictureMode
    }
}

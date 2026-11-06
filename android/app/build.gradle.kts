import com.android.build.gradle.internal.api.ApkVariantOutputImpl
import org.jetbrains.kotlin.konan.properties.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.piliplus"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.piliplus"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // libnode 预编译产物有 arm64-v8a / armeabi-v7a / x86_64 三个 ABI。
        // 这里不设 abiFilters —— jniLibs 里放哪个 ABI 就打哪个，
        // 配合 CI 的 --split-per-abi 按 ABI 拆成独立 APK：
        //   arm64-v8a    真机
        //   x86_64       MuMu/雷电等模拟器（它们的 ARM 转译层跑不动
        //                libnode 这种 60MB 的 V8 引擎，起 node 必崩）
        // externalNativeBuild 的 CMake 对缺失 ABI 已改为跳过不报错。
        externalNativeBuild {
            cmake {
                // libnode.so 是用 c++_shared 编的，必须同一个 STL
                arguments.add("-DANDROID_STL=c++_shared")
                cppFlags.add("-std=c++17")
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    packagingOptions.jniLibs.useLegacyPackaging = true

    val keyProperties = Properties().also {
        val properties = rootProject.file("key.properties")
        if (properties.exists())
            it.load(properties.inputStream())
    }

    val config = keyProperties.getProperty("storeFile")?.let {
        signingConfigs.create("release") {
            storeFile = file(it)
            storePassword = keyProperties.getProperty("storePassword")
            keyAlias = keyProperties.getProperty("keyAlias")
            keyPassword = keyProperties.getProperty("keyPassword")
            enableV1Signing = true
            enableV2Signing = true
        }
    }

    buildFeatures {
        if (project.hasProperty("dev")) {
            resValues = true
        }
    }

    buildTypes {
        all {
            signingConfig = config ?: signingConfigs["debug"]
        }
        release {
            if (project.hasProperty("dev")) {
                applicationIdSuffix = ".dev"
                resValue(
                    type = "string",
                    name = "app_name",
                    value = "PiliPlus dev",
                )
            }
//            proguardFiles(
//                getDefaultProguardFile("proguard-android-optimize.txt"),
//                "proguard-rules.pro"
//            )
        }
        debug {
            applicationIdSuffix = ".debug"
        }
    }

    applicationVariants.all {
        val variant = this
        variant.outputs.forEach { output ->
            (output as ApkVariantOutputImpl).versionCodeOverride = flutter.versionCode
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// ---------------------------------------------------------------------------
// 把 Flutter 侧的 assets/nodejs-project 复制进 Android assets。
// node 不能直接读 APK 里的 assets，运行时由 NodeBridge.ensureProject()
// 再从 assets 解到 filesDir 下。
// ---------------------------------------------------------------------------
val copyNodeProject by tasks.registering(Copy::class) {
    from(rootProject.file("../assets/nodejs-project")) {
        exclude("node_modules/**")
        exclude("**/*.map")
    }
    into(layout.projectDirectory.dir("src/main/assets/nodejs-project"))
}

tasks.matching { it.name.startsWith("preBuild") }.configureEach {
    dependsOn(copyNodeProject)
}

plugins {
    id("com.android.application")
    kotlin("android")
    kotlin("plugin.compose")
}

// Numéro de build : celui de la CI (versionCode croissant pour Google Play), 1 en local.
val buildNumber = (System.getenv("BRAINLIX_BUILD_NUMBER") ?: "1").toInt()

android {
    namespace = "app.brainlix.android"
    compileSdk = 36

    defaultConfig {
        applicationId = "app.brainlix.android"
        minSdk = 26
        targetSdk = 36
        versionCode = buildNumber
        versionName = "1.0"
        // Même serveur que l'iPhone (ios/Config/App.xcconfig) ; la clé « anon » est publique par nature (RLS côté serveur).
        buildConfigField("String", "SUPABASE_URL", "\"https://sibpncsjsdtjcjxbfryk.supabase.co\"")
        buildConfigField(
            "String", "SUPABASE_ANON_KEY",
            "\"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNpYnBuY3Nqc2R0amNqeGJmcnlrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU1MjQ1NTcsImV4cCI6MjEwMTEwMDU1N30.Baac4bYs7lFxQ5JrMydCEMqx7uifKSBz2dtKlmXZK2M\"",
        )
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }
}

kotlin { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) } }

dependencies {
    implementation(project(":core"))

    val composeBom = platform("androidx.compose:compose-bom:2025.06.00")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-text")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")

    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.9.1")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.9.1")

    testImplementation(kotlin("test"))
}

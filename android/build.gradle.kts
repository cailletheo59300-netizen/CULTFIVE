// Le plugin Android (dépôt Maven de Google) n'est chargé que si le module `app` est inclus : `-PcoreOnly` s'en passe.
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        if (!gradle.startParameter.projectProperties.containsKey("coreOnly")) {
            classpath("com.android.tools.build:gradle:8.11.1")
        }
    }
}

plugins {
    kotlin("jvm") version "2.2.0" apply false
    kotlin("android") version "2.2.0" apply false
    kotlin("plugin.serialization") version "2.2.0" apply false
    kotlin("plugin.compose") version "2.2.0" apply false
}

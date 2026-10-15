plugins {
    kotlin("jvm")
    kotlin("plugin.serialization")
}

// Bytecode Java 17 (compatible Android), compilé avec n'importe quel JDK récent.
java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}
kotlin { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) } }

dependencies {
    api("org.jetbrains.kotlinx:kotlinx-serialization-json:1.9.0")
    api("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
    api("com.squareup.okhttp3:okhttp:4.12.0")
    testImplementation(kotlin("test"))
    testImplementation("com.squareup.okhttp3:mockwebserver:4.12.0")
}

// Les tests de contrat lisent les mêmes réponses d'exemple que l'app iPhone.
tasks.test {
    systemProperty("fixtures", rootProject.file("../ios/Packages/CultFiveCore/Tests/CultFiveCoreTests/Fixtures").absolutePath)
}

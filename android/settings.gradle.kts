// Brainlix Android : `core` (Kotlin pur : modèles, API, correcteur, Elo — testable partout) et `app` (écrans Compose).
// En local sans le dépôt Maven de Google : `gradle -PcoreOnly :core:test`.
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "brainlix"
include(":core")
if (providers.gradleProperty("coreOnly").orNull == null) include(":app")

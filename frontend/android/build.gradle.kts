allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    plugins.withId("com.android.library") {
        val android = extensions.findByName("android")
        if (android != null) {
            val ext = (android as? org.gradle.api.plugins.ExtensionAware)?.extensions?.findByName("ext") as? org.gradle.api.plugins.ExtraPropertiesExtension
            ext?.set("flutter", mapOf(
                "compileSdkVersion" to 34,
                "minSdkVersion" to 21,
                "targetSdkVersion" to 34
            ))
        }
        project.dependencies.add("implementation", "androidx.core:core-ktx:1.12.0")
    }
    plugins.withId("com.android.application") {
        val android = extensions.findByName("android")
        if (android != null) {
            val ext = (android as? org.gradle.api.plugins.ExtensionAware)?.extensions?.findByName("ext") as? org.gradle.api.plugins.ExtraPropertiesExtension
            if (ext != null && !ext.has("flutter")) {
                ext.set("flutter", mapOf(
                    "compileSdkVersion" to 34,
                    "minSdkVersion" to 21,
                    "targetSdkVersion" to 34
                ))
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

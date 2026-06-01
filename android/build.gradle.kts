allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    val p = this
    if (p.state.executed) {
        configureNamespace(p)
    } else {
        p.afterEvaluate {
            configureNamespace(p)
        }
    }
}

fun configureNamespace(p: Project) {
    if (p.extensions.findByName("android") != null) {
        val androidExtension = p.extensions.getByType<com.android.build.gradle.BaseExtension>()
        if (androidExtension.namespace == null || androidExtension.namespace!!.isEmpty()) {
            val groupStr = p.group.toString()
            androidExtension.namespace = if (groupStr.isNotEmpty() && groupStr != "unspecified") {
                groupStr
            } else {
                "com.example.${p.name.replace("-", "_").replace(" ", "_")}"
            }
        }
    }
}


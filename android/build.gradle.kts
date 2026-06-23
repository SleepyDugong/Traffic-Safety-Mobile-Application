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

    if (project.name != "app") {
        afterEvaluate {
            if (extensions.findByName("android") != null) {
                val android = extensions.getByName("android") as com.android.build.gradle.BaseExtension
                android.compileSdkVersion(36)

                android.compileOptions.sourceCompatibility = org.gradle.api.JavaVersion.VERSION_17
                android.compileOptions.targetCompatibility = org.gradle.api.JavaVersion.VERSION_17

                tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                    compilerOptions {
                        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

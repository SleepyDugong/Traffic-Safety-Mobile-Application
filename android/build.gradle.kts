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
    if (project.name != "app") {
        afterEvaluate {
            if (hasProperty("android")) {
                val android = extensions.getByName("android") as com.android.build.gradle.BaseExtension
                android.compileSdkVersion(36)
                
                tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                    val targetJavaVersion = android.compileOptions.targetCompatibility
                    val targetKotlinVersion = when (targetJavaVersion) {
                        JavaVersion.VERSION_1_8 -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
                        JavaVersion.VERSION_11 -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
                        JavaVersion.VERSION_17 -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
                        else -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
                    }
                    compilerOptions {
                        jvmTarget.set(targetKotlinVersion)
                    }
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

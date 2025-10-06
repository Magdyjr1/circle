buildscript {
    val kotlinVersion by extra("1.9.23")
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.4.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:${kotlinVersion}")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = file("../build")
subprojects {
    project.buildDir = File("${rootProject.buildDir}/${project.name}")
}


tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}

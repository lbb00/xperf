plugins {
    java
    application
}

group = "com.jvmperf"

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(21))
    }
}

repositories { mavenCentral() }

dependencies {
    implementation("io.github.bonede:tree-sitter:0.26.3")
    implementation("io.github.bonede:tree-sitter-java:0.23.5")
    implementation("io.github.bonede:tree-sitter-kotlin:0.3.8.1")
    implementation("com.google.code.gson:gson:2.13.1")
    testImplementation("org.junit.jupiter:junit-jupiter:5.12.2")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

application {
    mainClass.set("com.jvmperf.lint.Main")
}

tasks.test {
    useJUnitPlatform()
    workingDir = projectDir
}

tasks.named<Jar>("jar") {
    manifest {
        attributes["Main-Class"] = "com.jvmperf.lint.Main"
    }
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE
    from(configurations.runtimeClasspath.get().map { if (it.isDirectory) it else zipTree(it) })
}

tasks.register<JavaExec>("runLint") {
    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("com.jvmperf.lint.Main")
    workingDir = projectDir
    args = project.findProperty("args")?.toString()?.split(" ") ?: emptyList()
}

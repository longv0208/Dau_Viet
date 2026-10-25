allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// E: drive đầy — build output ghi sang ổ C:. Khi ổ E: còn chỗ, có thể đổi
// lại "../../build" cho giữ nguyên trong project.
// Lưu ý: đường dẫn cuối phải là .../dau-viet-mobile-build/build để junction
// <project>/build -> C:\...\dau-viet-mobile-build\build khớp với path Flutter tool
// tra cứu (<project>/build/app/outputs/apk/...).
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("C:/Users/FPTSHOP/AppData/Local/dau-viet-mobile-build/build")
        .get()
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

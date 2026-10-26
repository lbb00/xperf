# R8 full mode is the default since AGP 8.0. Keep only classes accessed through reflection or JNI.
# Avoid -keep class com.example.** { *; }; it prevents removal, inlining, and class merging.
-keep class com.example.app.jni.NativeBridge { native <methods>; }
-keepclassmembers class com.example.app.model.** {
    @com.squareup.moshi.Json <fields>;
}
# Remove verbose/debug log calls from release builds only when their arguments have no side effects.
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
}

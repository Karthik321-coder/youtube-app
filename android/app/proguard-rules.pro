# Keep YouTube player WebView bridge
-keep class com.google.android.youtube.** { *; }
-keep class com.pierfrancescosoffritti.androidyoutubeplayer.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
-keepattributes *Annotation*
-keepclassmembers class * {
	@com.google.gson.annotations.SerializedName <fields>;
}

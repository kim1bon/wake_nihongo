# Gson generic type information
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Gson
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken { *; }

# Flutter Local Notifications
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin$* { *; }

# Android notification related classes used by framework/plugins
-keep class androidx.core.app.NotificationCompat** { *; }
-keep class android.app.Notification** { *; }
-keep class android.app.PendingIntent** { *; }

# Keep Kotlin metadata annotation
-keep class kotlin.Metadata { *; }

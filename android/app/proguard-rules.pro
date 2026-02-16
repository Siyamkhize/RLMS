# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google Play Core - Keep classes that R8 is complaining about
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator *;
}

# Keep Serializable classes
-keepnames class * implements java.io.Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep fingerprint SDK classes
-keep class com.zkteco.** { *; }
-keep class com.futronic.** { *; }

# Keep HTTP and networking classes
-keep class okhttp3.** { *; }
-keep class retrofit2.** { *; }
-dontwarn okhttp3.**
-dontwarn retrofit2.**

# Keep image processing classes
-keep class com.bumptech.glide.** { *; }
-dontwarn com.bumptech.glide.**

# Keep camera and image picker classes
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# Keep PDF viewer classes
-keep class com.github.barteksc.** { *; }
-dontwarn com.github.barteksc.**

# Keep signature classes
-keep class com.github.gcacace.** { *; }
-dontwarn com.github.gcacace.**

# Keep database classes
-keep class androidx.sqlite.** { *; }
-keep class androidx.room.** { *; }
-dontwarn androidx.sqlite.**
-dontwarn androidx.room.**

# Keep location services
-keep class com.google.android.gms.location.** { *; }
-dontwarn com.google.android.gms.location.**

# Keep notification classes
-keep class androidx.core.app.NotificationCompat** { *; }
-dontwarn androidx.core.app.NotificationCompat**

# General Android rules
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
-keep public class * extends android.app.backup.BackupAgentHelper
-keep public class * extends android.preference.Preference
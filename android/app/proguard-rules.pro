# Proguard rules for Traffic Safety App

# Keep TensorFlow Lite and LiteRT classes to prevent R8 from stripping them
-keep class org.tensorflow.lite.** { *; }
-keep class com.google.ai.edge.litert.** { *; }

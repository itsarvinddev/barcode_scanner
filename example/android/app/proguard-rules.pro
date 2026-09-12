# mobile_scanner ships its own consumer rules, these are here as a belt-and-braces
# reference for apps that enable R8 full mode (the default since AGP 8.0).
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

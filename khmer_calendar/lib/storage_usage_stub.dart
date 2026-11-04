Future<int> cacheBytes() async => 0;

Future<int> clearCacheFiles() async => 0;

/// Bytes of files the user saved on disk (not cache, never cleared by "Clear cache").
Future<int> userFilesBytes() async => 0;

import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:io';

class VideoCacheManager {
  static final VideoCacheManager _instance = VideoCacheManager._internal();
  factory VideoCacheManager() => _instance;
  VideoCacheManager._internal();

  // Increase cache size for more persistent storage
  final CacheManager _cacheManager = CacheManager(
    Config(
      'videoCache',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 50,
      repo: JsonCacheInfoRepository(databaseName: 'videoCache'),
      fileService: HttpFileService(),
    ),
  );

  Future<FileInfo?> getFileFromCache(String url) async {
    print('\x1B[43m[VideoCacheManager] Checking cache for $url\x1B[0m');
    return _cacheManager.getFileFromCache(url);
  }

  Future<FileInfo> downloadFile(String url) async {
    print('\x1B[44m[VideoCacheManager] Downloading $url\x1B[0m');
    return _cacheManager.downloadFile(url, key: url);
  }

  /// Returns the local file if cached, or null if not cached.
  Future<File?> getLocalFileIfCached(String url) async {
    final cached = await getFileFromCache(url);
    if (cached != null && cached.file.existsSync()) {
      print('\x1B[42m[VideoCacheManager] getLocalFileIfCached: Cache hit for $url\x1B[0m');
      return cached.file;
    }
    print('\x1B[41m[VideoCacheManager] getLocalFileIfCached: Cache miss for $url\x1B[0m');
    return null;
  }

  /// Always returns a file, downloads if not cached.
  Future<File> getFile(String url) async {
    final cached = await getFileFromCache(url);
    if (cached != null && cached.file.existsSync()) {
      print('\x1B[42m[VideoCacheManager] Cache hit for $url\x1B[0m');
      return cached.file;
    }
    print('\x1B[41m[VideoCacheManager] Cache miss for $url\x1B[0m');
    final downloaded = await downloadFile(url);
    return downloaded.file;
  }

  /// Prefetches and persists videos in the background.
  Future<void> prefetchVideos(List<String> urls) async {
    for (final url in urls) {
      // Only download if not already cached
      final cached = await getFileFromCache(url);
      if (cached == null || !cached.file.existsSync()) {
        print('\x1B[45m[VideoCacheManager] Prefetching $url\x1B[0m');
        try {
          await downloadFile(url);
        } catch (e) {
          print('\x1B[41m[VideoCacheManager] Prefetch failed for $url: $e\x1B[0m');
        }
      } else {
        print('\x1B[42m[VideoCacheManager] Already prefetched $url\x1B[0m');
      }
    }
  }
}

class VideoControllerResult {
  final VideoPlayerController controller;
  final String source; // "cache" or "network"
  VideoControllerResult(this.controller, this.source);
}

class VideoControllerManager {
  static final VideoControllerManager _instance = VideoControllerManager._internal();

  factory VideoControllerManager() => _instance;

  VideoControllerManager._internal();

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, String> _controllerSources = {}; // url -> source
  final List<String> _usageOrder = [];

  final int _maxActiveControllers = 4;

  Future<VideoControllerResult> getControllerWithSource(String url, bool isMuted) async {
    print('\x1B[46m[VideoControllerManager] getController for $url\x1B[0m');
    // Only reuse controller if it is still initialized and not disposed
    if (_controllers.containsKey(url)) {
      final ctrl = _controllers[url];
      if (ctrl != null && ctrl.value.isInitialized && !ctrl.value.hasError) {
        print('\x1B[42m[VideoControllerManager] Controller cache hit for $url\x1B[0m');
        _markUsed(url);
        final source = _controllerSources[url] ?? "cache";
        print('\x1B[46m[VideoControllerManager] Returning cached controller for $url (source: $source)\x1B[0m');
        return VideoControllerResult(ctrl, source);
      } else {
        // Remove broken/disposed controller
        print('\x1B[41m[VideoControllerManager] Removing broken/disposed controller for $url\x1B[0m');
        _controllers.remove(url);
        _controllerSources.remove(url);
        _usageOrder.remove(url);
      }
    }

    // Remove least recently used if exceeding max
    if (_controllers.length >= _maxActiveControllers) {
      final oldestKey = _usageOrder.removeAt(0);
      print('\x1B[41m[VideoControllerManager] Disposing LRU controller for $oldestKey\x1B[0m');
      try {
        await _controllers[oldestKey]?.dispose();
      } catch (_) {}
      _controllers.remove(oldestKey);
      _controllerSources.remove(oldestKey);
    }

    VideoPlayerController controller;
    String source;

    // Only cache/play files for .mp4 URLs
    if (url.endsWith('.mp4')) {
      try {
        final file = await VideoCacheManager().getLocalFileIfCached(url);
        if (file != null) {
          print('\x1B[42m[VideoControllerManager] Using cached file for $url\x1B[0m');
          controller = VideoPlayerController.file(file);
          await controller.initialize();
          source = "cache";
        } else {
          print('\x1B[41m[VideoControllerManager] No cached file, downloading for $url\x1B[0m');
          final downloadedFile = await VideoCacheManager().getFile(url);
          controller = VideoPlayerController.file(downloadedFile);
          await controller.initialize();
          source = "network";
        }
      } catch (e) {
        print('\x1B[41m[VideoControllerManager] Cache/file failed for $url, falling back to network. Error: $e\x1B[0m');
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
        try {
          await controller.initialize();
          source = "network";
        } catch (err) {
          print('\x1B[41m[VideoControllerManager] Network initialize failed for $url: $err\x1B[0m');
          rethrow;
        }
      }
    } else {
      // For non-mp4, always use network and never cache
      print('\x1B[41m[VideoControllerManager] Non-mp4 video, using network for $url\x1B[0m');
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
      try {
        await controller.initialize();
        source = "network";
      } catch (err) {
        print('\x1B[41m[VideoControllerManager] Network initialize failed for $url: $err\x1B[0m');
        rethrow;
      }
    }

    controller.setLooping(true);
    controller.setVolume(isMuted ? 0.0 : 1.0);

    _controllers[url] = controller;
    _controllerSources[url] = source;
    _markUsed(url);

    print('\x1B[42m[VideoControllerManager] Controller ready for $url (source: $source)\x1B[0m');
    return VideoControllerResult(controller, source);
  }

  // For backward compatibility
  Future<VideoPlayerController> getController(String url, bool isMuted) async {
    final result = await getControllerWithSource(url, isMuted);
    return result.controller;
  }

  String? getControllerSource(String url) => _controllerSources[url];

  void _markUsed(String url) {
    _usageOrder.remove(url);
    _usageOrder.add(url);
  }

  void pauseAllExcept(String url) {
    _controllers.forEach((key, controller) {
      if (key != url && controller.value.isInitialized) {
        try {
          controller.pause();
        } catch (_) {
          print("\x1B[41m[VideoControllerManager] Already Paused $key\x1B[0m");
        }
      }
    });
  }

  Future<void> disposeController(String url) async {
    print('\x1B[41m[VideoControllerManager] Disposing controller for $url\x1B[0m');
    if (_controllers.containsKey(url)) {
      final controller = _controllers[url];
      if (controller != null) {
        try {
          await controller.pause();
          await controller.dispose();
        } catch (_) {
          print("\x1B[41m[VideoControllerManager] Already Disposed $url\x1B[0m");
        }
      }
      _controllers.remove(url);
      _controllerSources.remove(url); // <-- Ensure source is removed too
      _usageOrder.remove(url);
    }
  }

  Future<void> disposeAll() async {
    print('\x1B[41m[VideoControllerManager] Disposing ALL controllers\x1B[0m');
    for (final controller in _controllers.values) {
      await controller.dispose();
    }
    _controllers.clear();
    _controllerSources.clear();
    _usageOrder.clear();
  }
}

class VideoMuteManager {
  static final VideoMuteManager _instance = VideoMuteManager._internal();
  factory VideoMuteManager() => _instance;
  VideoMuteManager._internal();

  bool _globalMuted = true;
  final List<void Function(bool)> _listeners = [];

  bool get isMuted => _globalMuted;

  void toggleMuteAll(bool mute) {
    print('\x1B[45m[VideoMuteManager] toggleMuteAll: $mute\x1B[0m');
    _globalMuted = mute;
    for (var listener in _listeners) {
      listener(mute);
    }
  }

  void addListener(void Function(bool) listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function(bool) listener) {
    _listeners.remove(listener);
  }
}


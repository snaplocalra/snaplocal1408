import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snap_local/common/social_media/post/post_details/models/post_state_update/update_post_state.dart';
import 'package:snap_local/common/utils/widgets/media_handing_widget/video_full_view.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:http/http.dart' as http;

import '../../../social_media/post/post_details/logic/post_details_controller/post_details_controller_cubit.dart';
import 'logic/video_player_manager.dart';

class BaseVideoVisibilityWidget extends StatefulWidget {
  final String videoUrl;
  final String thumbnailUrl;
  final String views;
  final bool muted;
  final double height;
  final bool showControls;
  final void Function()? onVideoViewCount;

  const BaseVideoVisibilityWidget({
    super.key,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.views,
    required this.onVideoViewCount,
    this.muted = true,
    this.height = 300,
    this.showControls = true,
  });

  @override
  State<BaseVideoVisibilityWidget> createState() => _BaseVideoVisibilityWidgetState();
}

class _BaseVideoVisibilityWidgetState extends State<BaseVideoVisibilityWidget> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  String _controllerSource = ""; // "cache" or "network"
  bool _isVisible = false;
  bool _isLoading = false;
  bool _hasError = false;
  bool _isMuted = true;
  bool _hasReportedView = false;
  String views="0";

  @override
  void initState() {
    super.initState();
    views=widget.views;
    _isMuted = VideoMuteManager().isMuted;
    VideoMuteManager().addListener(_handleGlobalMuteChange);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_videoProgressListener);
    VideoControllerManager().disposeController(widget.videoUrl);
    VideoMuteManager().removeListener(_handleGlobalMuteChange);
    _controller = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isUsableController(_controller)) return;

    if (state == AppLifecycleState.paused) {
      _controller?.pause();
    } else if (state == AppLifecycleState.resumed && _isVisible) {
      _controller?.play();
    }
  }

  Future<void> _initializeController() async {
    print('\x1B[46m[BaseVideoVisibilityWidget] Initializing controller for ${widget.videoUrl}\x1B[0m');
    setState(() {
      _isLoading = true;
      _hasError = false;
      _controllerSource = "";
    });

    try {
      final result = await VideoControllerManager().getControllerWithSource(widget.videoUrl, _isMuted);

      if (!mounted) return;

      setState(() {
        _controller = result.controller;
        _controllerSource = result.source;
        _hasError = false;
        _hasReportedView = false;
      });

      _controller?.addListener(_videoProgressListener);

      VideoControllerManager().pauseAllExcept(widget.videoUrl);
      _controller?.setVolume(_isMuted ? 0.0 : 1.0);
      _controller?.play(); // <-- Ensure autoplay
      print('\x1B[42m[BaseVideoVisibilityWidget] Controller initialized and playing for ${widget.videoUrl} (source: $_controllerSource)\x1B[0m');
    } catch (e) {
      print('\x1B[41m[BaseVideoVisibilityWidget] Error initializing controller for ${widget.videoUrl}: $e\x1B[0m');
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _videoProgressListener() {
    if (!_hasReportedView && _controller != null && _controller!.value.isInitialized) {
      final position = _controller!.value.position;
      if (position.inSeconds >= 3) {
        _hasReportedView = true;
        // if(int.tryParse(views)!=null){
        //   views=(int.tryParse(views)!+1).toString();
        // }
        //_reportVideoView();
        //views="10";

        setState(() {});
        if(widget.onVideoViewCount!=null) {
          widget.onVideoViewCount!();
        }
      }
    }
  }

  Future<void> _reportVideoView() async {
    try {

      // context
      //     .read<PostDetailsControllerCubit>()
      //     .postStateUpdate();
      // // Replace the URL and body with your actual API
      // const String endpoint = "https://your-api.com/video/view";
      // final response = await http.post(
      //   Uri.parse(endpoint),
      //   headers: {
      //     "Authorization": "Bearer YOUR_ACCESS_TOKEN",
      //     "Content-Type": "application/json",
      //   },
      //   body: '{"video_url": "${widget.videoUrl}"}',
      // );
      //
      // if (response.statusCode == 200) {
      //   debugPrint("View count reported successfully.");
      // } else {
      //   debugPrint("Failed to report view. Status: ${response.statusCode}");
      // }
    } catch (e) {
      debugPrint("Error reporting view: $e");
    }
  }

  void _handleVisibility(VisibilityInfo info) async {
    final visible = info.visibleFraction > 0.6;
    print('\x1B[46m[BaseVideoVisibilityWidget] Visibility for ${widget.videoUrl}: $visible (${info.visibleFraction})\x1B[0m');

    if (visible && !_isVisible) {
      _isVisible = true;

      if (!_isUsableController(_controller)) {
        await _initializeController();
      } else {
        VideoControllerManager().pauseAllExcept(widget.videoUrl);
        _controller?.setVolume(_isMuted ? 0.0 : 1.0);
        _controller?.play(); // <-- Ensure autoplay on visible
      }
    } else if (!visible && _isVisible) {
      _isVisible = false;
      try {
        _controller?.pause();
      } catch (_) {}
    }
  }

  bool _isUsableController(VideoPlayerController? c) {
    return c != null &&
        c.value.isInitialized &&
        !c.value.hasError &&
        c.value.isPlaying != null;
  }

  // void _toggleMute() {
  //   setState(() {
  //     _isMuted = !_isMuted;
  //     _controller?.setVolume(_isMuted ? 0.0 : 1.0);
  //   });
  // }

  void _handleGlobalMuteChange(bool mute) {
    if (mounted) {
      setState(() {
        _isMuted = mute;
        _controller?.setVolume(_isMuted ? 0.0 : 1.0);
      });
    }
  }

  void _toggleMute() {
    VideoMuteManager().toggleMuteAll(!_isMuted);
    // If currently muted, unmute all
    // if (_isMuted) {
    //   VideoMuteManager().toggleMuteAll(false);
    // } else {
    //   // If already unmuted, just mute this one
    //   setState(() {
    //     _isMuted = true;
    //     _controller?.setVolume(0.0);
    //   });
    // }
  }


  void _openFullScreen() {
    if (_isUsableController(_controller)) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VideoFullScreenPage(videoUrl: widget.videoUrl),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final usable = _isUsableController(_controller);

    print('\x1B[46m[BaseVideoVisibilityWidget] build usable=$usable, hasError=$_hasError, isLoading=$_isLoading for ${widget.videoUrl} (source: $_controllerSource)\x1B[0m');

    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: _handleVisibility,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_hasError)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      "Video failed to load",
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _hasError = false;
                        });
                        _initializeController();
                      },
                      child: Text("Retry"),
                    ),
                  ],
                ),
              )
            else if (usable)
              VideoPlayer(_controller!)
            else
              CachedNetworkImage(
                imageUrl: widget.thumbnailUrl,
                fit: BoxFit.cover,
                errorWidget: (context, _, __) => const Icon(Icons.error),
              ),
            // Show spinner while loading/buffering
            if (_isLoading)
              Container(
                color: Colors.black26,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),
            if (usable && widget.showControls) ...[
              Positioned(
                top: 10,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.remove_red_eye, color: Colors.white, size: 20),
                      const SizedBox(width: 5),
                      Text(
                        views,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _toggleMute,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      _isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _openFullScreen,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.fullscreen,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
            // Show source indicator
            if (_controllerSource.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _controllerSource == "cache" ? Colors.green : Colors.red,
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(8)),
                  ),
                  child: Text(
                    _controllerSource == "cache" ? "CACHE" : "NETWORK",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

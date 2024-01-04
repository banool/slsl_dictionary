import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:dictionarylib/common.dart';
import 'package:dictionarylib/globals.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dictionarylib/dictionarylib.dart' show DictLibLocalizations;
import 'package:slsl_dictionary/common.dart';
import 'package:video_player/video_player.dart';

enum PlaybackSpeed {
  PointFiveZero,
  PointSevenFive,
  One,
  OneTwoFive,
  OneFiveZero,
}

String getPlaybackSpeedString(PlaybackSpeed playbackSpeed) {
  switch (playbackSpeed) {
    case PlaybackSpeed.PointFiveZero:
      return "0.5x";
    case PlaybackSpeed.PointSevenFive:
      return "0.75x";
    case PlaybackSpeed.One:
      return "1x";
    case PlaybackSpeed.OneTwoFive:
      return "1.25x";
    case PlaybackSpeed.OneFiveZero:
      return "1.5x";
  }
}

double getDoubleFromPlaybackSpeed(PlaybackSpeed playbackSpeed) {
  switch (playbackSpeed) {
    case PlaybackSpeed.One:
      return 1.0;
    case PlaybackSpeed.PointSevenFive:
      return 0.75;
    case PlaybackSpeed.PointFiveZero:
      return 0.5;
    case PlaybackSpeed.OneFiveZero:
      return 1.5;
    case PlaybackSpeed.OneTwoFive:
      return 1.25;
  }
}

Widget getPlaybackSpeedDropdownWidget(void Function(PlaybackSpeed?) onChanged,
    {bool enabled = true}) {
  Color? color;
  if (!enabled) {
    color = APP_BAR_DISABLED_COLOR;
  }
  return Container(
      child: Align(
          alignment: Alignment.center,
          child: PopupMenuButton<PlaybackSpeed>(
            icon: Icon(
              Icons.slow_motion_video,
              color: color,
            ),
            enabled: enabled,
            itemBuilder: (BuildContext context) {
              return PlaybackSpeed.values.map((PlaybackSpeed value) {
                return PopupMenuItem<PlaybackSpeed>(
                  value: value,
                  child: Text(getPlaybackSpeedString(value)),
                );
              }).toList();
            },
            onSelected: enabled ? onChanged : null,
          )));
}

class InheritedPlaybackSpeed extends InheritedWidget {
  const InheritedPlaybackSpeed(
      {super.key, required this.child, required this.playbackSpeed})
      : super(child: child);

  final PlaybackSpeed playbackSpeed;
  @override
  final Widget child;

  static InheritedPlaybackSpeed? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<InheritedPlaybackSpeed>();
  }

  @override
  bool updateShouldNotify(InheritedPlaybackSpeed oldWidget) {
    return oldWidget.playbackSpeed != playbackSpeed;
  }
}

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.mediaLinks});

  final List<String> mediaLinks;

  @override
  _VideoPlayerScreenState createState() =>
      _VideoPlayerScreenState(mediaLinks: mediaLinks);
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  _VideoPlayerScreenState({required this.mediaLinks});

  final List<String> mediaLinks;

  Map<int, VideoPlayerController> videoControllers = {};
  Map<int, VideoPlayerController> imageControllers = {};
  Map<int, Widget> errorWidgets = {};

  List<Future<void>> initializePlayerFutures = [];

  CarouselController? carouselController;

  int currentPage = 0;

  @override
  void initState() {
    int idx = 0;
    for (String mediaLink in mediaLinks) {
      var future = initSingleVideo(mediaLink, idx);
      initializePlayerFutures.add(future);
      idx += 1;
    }
    // Make carousel slider controller.
    carouselController = CarouselController();
    super.initState();
  }

  Future<void> initSingleVideo(String mediaLink, int idx) async {
    bool shouldCache = sharedPreferences.getBool(KEY_SHOULD_CACHE) ?? true;

    VideoPlayerOptions videoPlayerOptions =
        VideoPlayerOptions(mixWithOthers: true);

    try {
      late VideoPlayerController controller;
      // Don't cache .bak files. They're rare and tricky to handle. In short,
      // the underlying video players depend on the extension to figure out
      // what kind of file we're working with. We need to remove the .bak
      // extension for the video player to work correctly.
      if (mediaLink.endsWith(".bak")) {
        shouldCache = false;
      }
      // We should only download directly if the user has disabled caching or
      // if we're in a web environment, in which case the web player cannot
      // use a file system based cache.
      bool shouldDownloadDirectly = !shouldCache || kIsWeb;
      if (shouldCache) {
        try {
          printAndLog(
              "Attempting to pull video $mediaLink from the cache / internet");
          File file = await myCacheManager.getSingleFile(mediaLink);
          controller = VideoPlayerController.file(file,
              videoPlayerOptions: videoPlayerOptions);
        } catch (e) {
          // I believe this never triggers now, getSingleFile internally handles
          // either pulling from the cache or the internet.
          printAndLog(
              "Failed to use cache for $mediaLink despite caching being enabled, just trying to download directly: $e");
          shouldDownloadDirectly = true;
        }
      }
      if (shouldDownloadDirectly) {
        if (!shouldCache) {
          printAndLog(
              "Caching is disabled, pulling $mediaLink from the network");
        }
        controller = VideoPlayerController.network(mediaLink,
            videoPlayerOptions: videoPlayerOptions);
      }

      // Use the controller to loop the video.
      await controller.setLooping(true);

      // Turn off the sound (some videos have sound for some reason).
      await controller.setVolume(0.0);

      // Start the video paused.
      await controller.pause();

      // Initialize the controller.
      await controller.initialize();

      // Store the controller for later. We check mounted in case the user
      // navigated away before the video loading, in which case calling setState
      // would be invalid.
      if (mounted) {
        setState(() {
          videoControllers[idx] = controller;
        });
      } else {
        printAndLog("Not calling setState because not mounted");
      }
    } catch (e) {
      printAndLog("Error loading video: $e");
      errorWidgets[idx] = createErrorWidget(e, mediaLink);
    }
  }

  Widget createErrorWidget(Object error, String mediaLink) {
    Column out;
    if ("$error".contains("Socket")) {
      out = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Failed to load video. Please confirm your device is connected to the internet. If it is, the servers may be having issues. This is not an issue with the app itself.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
          const Padding(padding: EdgeInsets.only(top: 10)),
          Text(
            "$mediaLink: $error",
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      out = Column(children: [
        Text(
          "${DictLibLocalizations.of(context)!.unexpectedErrorLoadingVideo} $mediaLink: $error",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        )
      ]);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Center(child: out),
    );
  }

  void onPageChanged(BuildContext context, int newPage) {
    setState(() {
      for (VideoPlayerController c in videoControllers.values) {
        c.pause();
      }
      currentPage = newPage;
      videoControllers[currentPage]?.play();
    });
  }

  @override
  void dispose() {
    super.dispose();
    // Ensure disposing of the VideoPlayerController to free up resources.
    for (VideoPlayerController c in videoControllers.values) {
      c.dispose();
    }
  }

  void setPlaybackSpeed(
      BuildContext context, VideoPlayerController controller) {
    if (mounted) {
      double playbackSpeedDouble = getDoubleFromPlaybackSpeed(
          InheritedPlaybackSpeed.of(context)!.playbackSpeed);
      controller.setPlaybackSpeed(playbackSpeedDouble);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get height of screen to ensure that the video only takes up
    // a certain proportion of it.
    List<Widget> items = [];
    for (int idx = 0; idx < mediaLinks.length; idx++) {
      var mediaLink = mediaLinks[idx];
      Widget item;
      if (mediaLink.endsWith(".jpg")) {
        item = Padding(
            padding: const EdgeInsets.all(10),
            child: CachedNetworkImage(
                imageUrl: mediaLink,
                cacheManager: myCacheManager,
                progressIndicatorBuilder: (context, url, downloadProgress) =>
                    Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: SizedBox(
                          height: 100.0,
                          width: 100.0,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: downloadProgress.progress,
                            ),
                          ),
                        )),
                errorWidget: (context, url, error) =>
                    createErrorWidget(error, mediaLink)));
      } else {
        item = FutureBuilder(
            future: initializePlayerFutures[idx],
            builder: (context, snapshot) {
              var waitingWidget = const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ));
              if (snapshot.connectionState != ConnectionState.done) {
                return waitingWidget;
              }
              if (errorWidgets.containsKey(idx)) {
                return errorWidgets[idx]!;
              }
              if (!videoControllers.containsKey(idx)) {
                return waitingWidget;
              }
              var controller = videoControllers[idx]!;

              // Set playback speed here, since we need the context.
              setPlaybackSpeed(context, controller);

              // Set it again repeatedly since there can be a weird race.
              // I have confirmed that even from within video_player.dart, it is
              // trying to set the correct value but the video still plays at
              // the wrong playback speed.
              Future.delayed(const Duration(milliseconds: 100),
                  () => setPlaybackSpeed(context, controller));
              Future.delayed(const Duration(milliseconds: 250),
                  () => setPlaybackSpeed(context, controller));
              Future.delayed(const Duration(milliseconds: 500),
                  () => setPlaybackSpeed(context, controller));
              Future.delayed(const Duration(milliseconds: 1000),
                  () => setPlaybackSpeed(context, controller));
              Future.delayed(const Duration(milliseconds: 2000),
                  () => setPlaybackSpeed(context, controller));
              Future.delayed(const Duration(milliseconds: 4000),
                  () => setPlaybackSpeed(context, controller));
              Future.delayed(const Duration(milliseconds: 6000),
                  () => setPlaybackSpeed(context, controller));
              Future.delayed(const Duration(milliseconds: 8000),
                  () => setPlaybackSpeed(context, controller));

              // Play or pause the video based on whether this is the first video.
              if (idx == currentPage) {
                controller.play();
              } else {
                controller.pause();
              }

              var player = VideoPlayer(controller);
              var videoContainer = Container(
                  padding: const EdgeInsets.only(top: 15), child: player);
              return videoContainer;
            });
      }
      items.add(item);
    }
    double aspectRatio;
    if (videoControllers.containsKey(currentPage)) {
      aspectRatio = videoControllers[currentPage]!.value.aspectRatio;
    } else {
      // This is a fallback value for if the video hasn't loaded yet.
      aspectRatio = 16 / 12;
    }
    var slider = CarouselSlider(
      carouselController: carouselController,
      items: items,
      options: CarouselOptions(
        aspectRatio: aspectRatio,
        autoPlay: false,
        viewportFraction: 0.8,
        enableInfiniteScroll: false,
        onPageChanged: (index, reason) => onPageChanged(context, index),
        enlargeCenterPage: true,
      ),
    );

    var size = MediaQuery.of(context).size;
    var screenWidth = size.width;
    var screenHeight = size.height;
    var shouldUseHorizontalDisplay = getShouldUseHorizontalLayout(context);
    BoxConstraints boxConstraints;
    if (shouldUseHorizontalDisplay) {
      boxConstraints = BoxConstraints(
          maxWidth: screenWidth * 0.55, maxHeight: screenHeight * 0.67);
    } else {
      boxConstraints = BoxConstraints(maxHeight: screenHeight * 0.46);
    }

    // Ensure that the video doesn't take up the whole screen.
    // This only applies a maximum bound.
    var sliderContainer = Container(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: boxConstraints,
          child: slider,
        ));

    return sliderContainer;
  }
}

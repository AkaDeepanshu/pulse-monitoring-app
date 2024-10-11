import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request necessary permissions
  await _requestPermissions();

  runApp(const MyApp());
}

Future<void> _requestPermissions() async {
  await [
    Permission.camera,
    Permission.microphone,
    Permission.storage,
  ].request();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Video Recorder',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const HomePage());
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

enum CameraLens { front, back }

class _HomePageState extends State<HomePage> {
  bool _showCameraOptions = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Recorder Home'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Stack(
              alignment: Alignment.center,
              children: [
                // Circular Start Button
                FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const CameraViewPage()));
                    });
                  },
                  backgroundColor: Colors.red,
                  tooltip: 'Start Recording',
                  child: const Icon(Icons.videocam),
                ),
                // Camera Options
              ],
            ),
            const SizedBox(height: 50),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const RecordingsPage()));
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('View Recordings'),
            ),
          ],
        ),
      ),
    );
  }
}

class CameraViewPage extends StatefulWidget {
  const CameraViewPage({super.key});

  @override
  State<CameraViewPage> createState() => _CameraViewPageState();
}

class _CameraViewPageState extends State<CameraViewPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Camera View'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  _navigateToCamera(CameraLens.front);
                },
                icon: const Icon(Icons.camera_front),
                label: const Text('Front Camera'),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  _navigateToCamera(CameraLens.back);
                },
                icon: const Icon(Icons.camera_rear),
                label: const Text('Back Camera'),
              ),
            ],
          ),
        ));
  }

  void _navigateToCamera(CameraLens lens) async {
    final cameras = await availableCameras();
    CameraDescription selectedCamera;

    if (lens == CameraLens.front) {
      selectedCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first);
    } else {
      selectedCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first);
    }

    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CameraPage(camera: selectedCamera)));
  }
}

class CameraPage extends StatefulWidget {
  final CameraDescription camera;

  const CameraPage({super.key, required this.camera});

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.high,
        enableAudio: true);
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String> _getVideoPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final videoDir = Directory('${directory.path}/Videos');
    if (!await videoDir.exists()) {
      await videoDir.create(recursive: true);
    }
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return '${videoDir.path}/VIDEO_$timestamp.mp4';
  }

  void _startRecording() async {
    try {
      await _initializeControllerFuture;
      final path = await _getVideoPath();
      await _controller.startVideoRecording();
      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      print(e);
    }
  }

  void _stopRecording() async {
    try {
      final video = await _controller.stopVideoRecording();
      setState(() {
        _isRecording = false;
      });
      // Save the video to the desired path
      final path = await _getVideoPath();
      await video.saveTo(path);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Video Saved')));
      Navigator.pop(context);
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Recording...'),
        ),
        body: FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return Stack(
                children: [
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: FloatingActionButton(
                        onPressed:
                            _isRecording ? _stopRecording : _startRecording,
                        backgroundColor:
                            _isRecording ? Colors.red : Colors.green,
                        child: Icon(_isRecording ? Icons.stop : Icons.videocam),
                      ),
                    ),
                  )
                ],
              );
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        ));
  }
}

class RecordingsPage extends StatefulWidget {
  const RecordingsPage({super.key});

  @override
  _RecordingsPageState createState() => _RecordingsPageState();
}

class _RecordingsPageState extends State<RecordingsPage> {
  List<FileSystemEntity> _videos = [];

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    final directory = await getApplicationDocumentsDirectory();
    final videoDir = Directory('${directory.path}/Videos');
    if (await videoDir.exists()) {
      setState(() {
        _videos = videoDir
            .listSync()
            .where((item) => item.path.endsWith('.mp4'))
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Recordings'),
        ),
        body: _videos.isEmpty
            ? const Center(child: Text('No recordings found'))
            : ListView.builder(
                itemCount: _videos.length,
                itemBuilder: (context, index) {
                  final file = _videos[index];
                  return ListTile(
                    leading: const Icon(Icons.video_library),
                    title: Text('Video ${index + 1}'),
                    subtitle: Text(file.path.split('/').last),
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  VideoPlayerPage(videoFile: File(file.path))));
                    },
                  );
                },
              ));
  }
}

class VideoPlayerPage extends StatefulWidget {
  final File videoFile;

  const VideoPlayerPage({super.key, required this.videoFile});

  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _videoController;
  Future<void>? _initializeVideoPlayerFuture;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.file(widget.videoFile);
    _initializeVideoPlayerFuture = _videoController.initialize().then((_) {
      setState(() {}); // Update the UI when the video is loaded
    });
    _videoController.setLooping(true);
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Play Video'),
        ),
        body: Center(
          child: _initializeVideoPlayerFuture != null
              ? FutureBuilder(
                  future: _initializeVideoPlayerFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return AspectRatio(
                        aspectRatio: _videoController.value.aspectRatio,
                        child: VideoPlayer(_videoController),
                      );
                    } else {
                      return const CircularProgressIndicator();
                    }
                  },
                )
              : const CircularProgressIndicator(),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            setState(() {
              _videoController.value.isPlaying
                  ? _videoController.pause()
                  : _videoController.play();
            });
          },
          child: Icon(_videoController.value.isPlaying
              ? Icons.pause
              : Icons.play_arrow),
        ));
  }
}

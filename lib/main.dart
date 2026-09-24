import 'package:package_info_plus/package_info_plus.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';

// Supplied at build time: flutter run --dart-define-from-file=secrets.json
const String scriptUrl = String.fromEnvironment('SCRIPT_URL');
const String secretKey = String.fromEnvironment('SECRET_KEY');
const String camStream = String.fromEnvironment('CAM_STREAM');

const Color brandBlue = Color(0xFF0090E2);
const Color brandRed = Color(0xFFFF0000);
const Color dough100 = Color(0xFFFEFAF6);
const Color lava1000 = Color(0xFF603913);
const Color lava1000Shadow = Color(0x80603913);
const Color lava1000Shadow25 = Color(0x40603913);
const Color lava1000Shadow50 = Color(0x80603913);
const TextStyle countdownNumTextStyle = TextStyle(
  height: 1.0,
  fontSize: 90.0,
  fontFamily: 'Dominos Sans Header 1',
  color: brandRed,
  shadows: [
    Shadow(color: lava1000Shadow50, blurRadius: 8, offset: Offset(0, 1)),
    Shadow(color: lava1000Shadow25, blurRadius: 16, offset: Offset(0, 2)),
  ],
);
const TextStyle countdownTextStyle = TextStyle(
  height: 1.0,
  fontSize: 70.0,
  fontFamily: 'Dominos Sans Header 1',
  color: dough100,
  shadows: [
    Shadow(color: lava1000Shadow50, blurRadius: 8, offset: Offset(0, 1)),
    Shadow(color: lava1000Shadow25, blurRadius: 16, offset: Offset(0, 2)),
  ],
);
const TextStyle buttonTextStyle = TextStyle(
  fontSize: 35.0,
  fontFamily: 'Dominos Sans Subhead 1',
);
const TextStyle blueTextStyle = TextStyle(
  height: 1.0,
  fontSize: 60.0,
  fontFamily: 'Dominos Sans Header 1',
  color: brandBlue,
);
const TextStyle redTextStyle = TextStyle(
  height: 1.0,
  fontSize: 60.0,
  fontFamily: 'Dominos Sans Header 1',
  color: brandRed,
);
const TextStyle versionTextStyle = TextStyle(fontSize: 12.0, color: lava1000);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(
    MaterialApp(
      title: 'Uniform Check-In',
      home: HomeScreen(),
      theme: ThemeData(
        fontFamily: 'Dominos Sans Body',
        scaffoldBackgroundColor: dough100,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandBlue,
          primary: brandBlue,
          onPrimary: dough100,
        ),
      ),
    ),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<String> get version async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image(
                  image: const AssetImage('assets/Locally_Owned.png'),
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: MediaQuery.of(context).size.height * 0.6,
                ),
                FilledButton(
                  onPressed: () async {
                    final cameras = await availableCameras();
                    final firstCamera = cameras.firstWhere(
                      (camera) =>
                          camera.lensDirection == CameraLensDirection.front,
                    );
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      buildPageRoute(TakePictureScreen(camera: firstCamera)),
                    );
                  },
                  child: const Text('Begin Check-In', style: buttonTextStyle),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            width: MediaQuery.of(context).size.width,
            child: FutureBuilder<String>(
              future: version,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(
                    'App Version: ${snapshot.data}\nCreated by William Disman',
                    style: versionTextStyle,
                    textAlign: TextAlign.center,
                  );
                } else {
                  return const Text(
                    'App Version: Unknown\nCreated by William Disman',
                    style: versionTextStyle,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({super.key, required this.camera});
  final CameraDescription camera;

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController controller;
  late Future<void> initializeControllerFuture;
  int countdownSeconds = 0;
  bool countdownStarted = false;
  late final camPlayer = Player();
  late final camController = VideoController(camPlayer);

  InlineSpan getCountdownText() {
    if (countdownSeconds > 5) {
      return TextSpan(
        text: 'Move\nbehind\nthe line.',
        style: countdownTextStyle,
      );
    }
    if (countdownSeconds < 0) {
      return TextSpan(text: 'Processing.', style: countdownTextStyle);
    }
    if (countdownSeconds < 1) {
      return TextSpan(text: '', style: countdownTextStyle);
    }
    return TextSpan(text: '$countdownSeconds', style: countdownNumTextStyle);
  }

  @override
  void initState() {
    super.initState();
    controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    initializeControllerFuture = controller.initialize();
    camPlayer.setVolume(0.0);
    camPlayer.open(Media(camStream));
  }

  @override
  void dispose() {
    controller.dispose();
    camPlayer.dispose();
    super.dispose();
  }

  void startCountdown() async {
    try {
      for (int i = 8; i > 0; i--) {
        setState(() => countdownSeconds = i);
        await Future.delayed(const Duration(seconds: 1));
      }

      setState(() => countdownSeconds = 0);
      await initializeControllerFuture;
      final image = await controller.takePicture();
      controller.pausePreview();
      setState(() => countdownSeconds = -1);
      final tempDir = await getTemporaryDirectory();
      final Uint8List? cam = await camPlayer.screenshot();
      final File camFile = File("${tempDir.path}/camCapture.png");
      final File imageFile = File(image.path);
      if (cam != null) {
        await camFile.writeAsBytes(cam);
      } else {
        final bytes = await imageFile.readAsBytes();
        await camFile.writeAsBytes(bytes);
      }

      if (!mounted) return;
      Navigator.push(
        context,
        buildPageRoute(DisplayPictureScreen(image: imageFile, cam: camFile)),
      );
    } catch (e) {
      if (!mounted) return;
      navigateToHomeScreen(context);
      showErrorSnackBar(context, 'Camera Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FutureBuilder<void>(
          future: initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (!countdownStarted) {
                countdownStarted = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  startCountdown();
                });
              }
              return Stack(
                alignment: Alignment.center,
                children: [
                  Video(controller: camController, width: 0, height: 0),
                  CameraPreview(controller),
                  RichText(text: getCountdownText()),
                ],
              );
            } else {
              return const SizedBox.shrink();
            }
          },
        ),
      ),
    );
  }
}

class DisplayPictureScreen extends StatelessWidget {
  const DisplayPictureScreen({
    super.key,
    required this.image,
    required this.cam,
  });
  final File image;
  final File cam;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        navigateToHomeScreen(context);
      },
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 20.0,
            children: [
              Image.file(image),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 20.0,
                children: [
                  FilledButton(
                    onPressed: () {
                      navigateToHomeScreen(context);
                    },
                    style: FilledButton.styleFrom(backgroundColor: brandRed),
                    child: const Text('Discard', style: buttonTextStyle),
                  ),
                  FilledButton(
                    onPressed: () => handleSubmit(context, image, cam),
                    child: const Text('Submit', style: buttonTextStyle),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        body: Center(
          child: RichText(
            text: TextSpan(
              text: 'Your\nCheck-In is\nuploading.\n',
              style: blueTextStyle,
              children: [TextSpan(text: 'Please wait.', style: redTextStyle)],
            ),
          ),
        ),
      ),
    );
  }
}

PageRoute<T> buildPageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        child,
  );
}

void navigateToHomeScreen(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    buildPageRoute(const HomeScreen()),
    (Route<dynamic> route) => false,
  );
}

void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: brandRed,
      duration: const Duration(seconds: 10),
    ),
  );
}

Future<void> handleSubmit(BuildContext context, File image, File cam) async {
  Navigator.push(context, buildPageRoute(LoadingScreen()));

  List<int> imageFileBytes = await image.readAsBytes();
  String imageBase64String = base64Encode(imageFileBytes);
  List<int> camFileBytes = await cam.readAsBytes();
  String camBase64String = base64Encode(camFileBytes);
  String fileName = DateTime.now()
      .toIso8601String()
      .replaceAll(':', '_')
      .substring(0, 19);

  try {
    var request = Request('POST', Uri.parse(scriptUrl));
    request.body = jsonEncode({
      'filename': fileName,
      'mimeType': 'image/jpeg',
      'image': imageBase64String,
      'cam': camBase64String,
      'secretKey': secretKey,
    });
    request.followRedirects = false;

    var stream = await request.send();
    var response = await Response.fromStream(stream);

    if (response.statusCode == 302) {
      var redirectUrl = response.headers['location'];
      if (redirectUrl != null) {
        var resultResponse = await get(Uri.parse(redirectUrl));
        if (!context.mounted) return;
        parseResponse(context, resultResponse.body);
      }
    } else if (response.statusCode == 200) {
      if (!context.mounted) return;
      parseResponse(context, response.body);
    } else {
      if (!context.mounted) return;
      showErrorSnackBar(
        context,
        'HTTP Error (${response.statusCode}): ${response.body}',
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    showErrorSnackBar(context, 'Upload Error: $e');
  }
  if (!context.mounted) return;
  image.delete();
  cam.delete();
  navigateToHomeScreen(context);
}

void parseResponse(BuildContext context, String responseBody) {
  try {
    var jsonResponse = jsonDecode(responseBody);
    if (jsonResponse['status'] != 'success') {
      showErrorSnackBar(context, 'Server Error: ${jsonResponse['message']}');
    }
  } catch (e) {
    showErrorSnackBar(context, 'Upload Error: $e');
  }
}

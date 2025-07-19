import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'package:animations/animations.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Will's LEDs",
      theme: ThemeData(
        primaryColor: const Color(0xFF0A0A0A),
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: TextTheme(
          bodyMedium: GoogleFonts.montserrat(
              color: const Color(0xFF00E5FF), fontSize: 16),
          headlineSmall: GoogleFonts.montserrat(
              color: const Color(0xFF39FF14),
              fontSize: 24,
              fontWeight: FontWeight.bold,
              shadows: const [Shadow(color: Color(0xFFD81B60), blurRadius: 8)]),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color>((states) =>
                states.contains(WidgetState.disabled)
                    ? Colors.grey.withOpacity(0.5)
                    : const Color(0xFFFF00FF)),
            foregroundColor: WidgetStateProperty.all(const Color(0xFF0A0A0A)),
            padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            textStyle: WidgetStateProperty.all(GoogleFonts.montserrat(
                fontSize: 14, fontWeight: FontWeight.w600)),
            shape: WidgetStateProperty.all(RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
            elevation: WidgetStateProperty.all(8),
            overlayColor: WidgetStateProperty.all(const Color(0x3339FF14)),
          ),
        ),
      ),
      home: const LedControlScreen(),
    );
  }
}

class LedControlScreen extends StatefulWidget {
  const LedControlScreen({super.key});

  @override
  State<LedControlScreen> createState() => _LedControlScreenState();
}

class _LedControlScreenState extends State<LedControlScreen>
    with SingleTickerProviderStateMixin {
  final String serverUrl = 'http://192.168.1.126:5000';
  final List<Map<String, String>> modes = [
    {'name': 'off', 'image': 'assets/modes/off.png'},
    {'name': 'rainbow-flow', 'image': 'assets/modes/rainbow-flow.png'},
    {'name': 'constant-red', 'image': 'assets/modes/constant-red.png'},
    {
      'name': 'proletariat-crackle',
      'image': 'assets/modes/proletariat-crackle.png'
    },
    {
      'name': 'bourgeois-brilliance',
      'image': 'assets/modes/bourgeois-brilliance.png'
    },
    {
      'name': 'austere-enlightenment',
      'image': 'assets/modes/austere-enlightenment.png'
    },
    {
      'name': 'zaphod-galactic-groove',
      'image': 'assets/modes/zaphod-galactic-groove.png'
    },
    {
      'name': 'max-aquarian-flow',
      'image': 'assets/modes/max-aquarian-flow.png'
    },
    {
      'name': 'lunar-rebellion-pulse',
      'image': 'assets/modes/lunar-rebellion-pulse.png'
    },
    {
      'name': 'proletariat-pulse',
      'image': 'assets/modes/proletariat-pulse.png'
    },
    {'name': 'bourgeois-blaze', 'image': 'assets/modes/bourgeois-blaze.png'},
  ];
  String currentMode = 'off';
  bool isLoading = true;
  bool isUpdating = false;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  final ScrollController _scrollController = ScrollController();
  final List<Color> neonColors = const [
    Color(0xFF00E5FF), // Cyan
    Color(0xFFFF00FF), // Magenta
    Color(0xFF39FF14), // Lime
    Color(0xFFD81B60), // Electric Purple
  ];
  final List<AnimationController> _starControllers = [];
  final List<Animation<double>> _starAnimations = [];

  @override
  void initState() {
    super.initState();
    fetchCurrentMode();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    // Initialize twinkling stars
    for (int i = 0; i < 30; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 1000 + Random().nextInt(2000)),
      )..repeat(reverse: true);
      _starControllers.add(controller);
      _starAnimations.add(Tween<double>(begin: 0.3, end: 1.0).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeInOut)));
    }
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent) {
        _scrollController.jumpTo(0);
      } else if (_scrollController.position.pixels <=
          _scrollController.position.minScrollExtent) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (var controller in _starControllers) {
      controller.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchCurrentMode() async {
    setState(() => isLoading = true);
    try {
      print('Fetching mode from $serverUrl/mode');
      final response = await http.get(Uri.parse('$serverUrl/mode')).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('Fetch mode timeout');
          return http.Response('Timeout', 408);
        },
      );
      if (!mounted) return;
      print('Raw response: ${response.body} (status: ${response.statusCode})');
      if (response.statusCode == 200) {
        if (modes.any((mode) => mode['name'] == response.body.trim())) {
          setState(() => currentMode = response.body.trim());
        } else {
          print('Invalid mode received: ${response.body}');
          showSnackBar('Invalid mode received from server');
        }
      } else {
        print('Fetch mode failed: ${response.statusCode}');
        showSnackBar('Failed to fetch mode: ${response.statusCode}');
      }
    } catch (e) {
      print('Fetch mode error: $e');
      if (mounted) showSnackBar('Failed to connect: $e');
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      try {
        final retryResponse =
            await http.get(Uri.parse('$serverUrl/mode')).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('Fetch mode retry timeout');
            return http.Response('Timeout', 408);
          },
        );
        print(
            'Retry response: ${retryResponse.body} (status: ${retryResponse.statusCode})');
        if (retryResponse.statusCode == 200 &&
            modes.any((mode) => mode['name'] == retryResponse.body.trim())) {
          setState(() => currentMode = retryResponse.body.trim());
        } else {
          showSnackBar('Retry failed: ${retryResponse.statusCode}');
        }
      } catch (retryError) {
        print('Fetch mode retry error: $retryError');
        if (mounted) showSnackBar('Retry failed: $retryError');
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> updateMode(String newMode) async {
    setState(() => isUpdating = true);
    final body = jsonEncode({'mode': newMode});
    try {
      print('Updating mode to $newMode at $serverUrl/update');
      final response = await http
          .post(
        Uri.parse('$serverUrl/update'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('Update mode timeout');
          return http.Response('Timeout', 408);
        },
      );
      if (!mounted) return;
      print('Raw response: ${response.body} (status: ${response.statusCode})');
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['message'] != null) {
            setState(() => currentMode = newMode);
            showSnackBar(
                'Mode set to ${titleCase(newMode.replaceAll('-', ' '))}!');
          } else {
            print('Update mode error: ${data['error']}');
            showSnackBar('Error: ${data['error']}');
          }
        } catch (e) {
          print('JSON parse error: $e');
          showSnackBar('Invalid response from server');
        }
      } else {
        print('Update mode failed: ${response.statusCode}');
        showSnackBar('Failed to update: ${response.statusCode}');
      }
    } catch (e) {
      print('Update mode error: $e');
      if (mounted) showSnackBar('Failed to connect: $e');
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      try {
        final retryResponse = await http
            .post(
          Uri.parse('$serverUrl/update'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'mode': newMode}),
        )
            .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('Update mode retry timeout');
            return http.Response('Timeout', 408);
          },
        );
        print(
            'Retry response: ${retryResponse.body} (status: ${retryResponse.statusCode})');
        if (retryResponse.statusCode == 200) {
          final retryData = jsonDecode(retryResponse.body);
          if (retryData['message'] != null) {
            setState(() => currentMode = newMode);
            showSnackBar(
                'Mode set to ${titleCase(newMode.replaceAll('-', ' '))}!');
          } else {
            showSnackBar('Retry failed: ${retryData['error']}');
          }
        } else {
          showSnackBar('Retry failed: ${retryResponse.statusCode}');
        }
      } catch (retryError) {
        print('Update mode retry error: $retryError');
        if (mounted) showSnackBar('Retry failed: $retryError');
      }
    } finally {
      if (mounted) setState(() => isUpdating = false);
    }
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          style: GoogleFonts.montserrat(color: const Color(0xFF39FF14))),
      backgroundColor: const Color(0xFF0A0A0A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
    ));
  }

  String titleCase(String text) {
    return text.replaceAllMapped(
        RegExp(r'\b\w'), (match) => match.group(0)!.toUpperCase());
  }

  void showInfoDialog() {
    showAboutDialog(
      context: context,
      applicationName: "Will's LEDs",
      applicationVersion: '1.0.0',
      applicationLegalese:
          'Developed by Willoh and Preston Brubaker\nControl your LED strips with cosmic flair!',
      applicationIcon: Image.asset('assets/icon.png', width: 50, height: 50),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0A0A), Color(0xFF0F172A)],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Twinkling starfield background
              ...List.generate(
                  30,
                  (index) => Positioned(
                        left: Random().nextDouble() *
                            MediaQuery.of(context).size.width,
                        top: Random().nextDouble() *
                            MediaQuery.of(context).size.height,
                        child: AnimatedBuilder(
                          animation: _starAnimations[index],
                          builder: (context, child) => Opacity(
                            opacity: _starAnimations[index].value,
                            child: Container(
                              width: 2 + Random().nextDouble() * 4,
                              height: 2 + Random().nextDouble() * 4,
                              decoration: BoxDecoration(
                                color: neonColors[index % neonColors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      )),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isLoading
                              ? 'Initializing...'
                              : 'Current Mode: ${titleCase(currentMode.replaceAll('-', ' '))}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline,
                              color: Color(0xFF00E5FF)),
                          onPressed: showInfoDialog,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: fetchCurrentMode,
                      color: const Color(0xFF39FF14),
                      backgroundColor: const Color(0xFF0A0A0A),
                      child: GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.8,
                        ),
                        itemBuilder: (context, index) {
                          final mode = modes[index % modes.length];
                          return PageTransitionSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, primary, secondary) =>
                                SharedAxisTransition(
                                    animation: primary,
                                    secondaryAnimation: secondary,
                                    transitionType:
                                        SharedAxisTransitionType.scaled,
                                    child: child),
                            child: GestureDetector(
                              key: ValueKey(mode['name']),
                              onTap: isUpdating
                                  ? null
                                  : () => updateMode(mode['name']!),
                              child: AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, child) => Transform.scale(
                                  scale: currentMode == mode['name']
                                      ? _pulseAnimation.value
                                      : 1.0,
                                  child: Card(
                                    color: Colors.transparent,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                            color: neonColors[
                                                index % neonColors.length],
                                            width: 2)),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          mode['image']!,
                                          width: 150,
                                          height: 150,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Icon(
                                                      Icons.image_not_supported,
                                                      color: Color(0xFF00E5FF),
                                                      size: 150),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          titleCase(mode['name']!
                                              .replaceAll('-', ' ')),
                                          style: GoogleFonts.montserrat(
                                              color: neonColors[
                                                  index % neonColors.length],
                                              fontSize: 12),
                                          textAlign: TextAlign.center,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
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

name: speed_converter_pro
description: "تطبيق احترافي لتحسين الجودة ورفع معدل الإطارات"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  ffmpeg_kit_flutter: ^6.0.3
  file_picker: ^8.0.0
  path_provider: ^2.1.2
  permission_handler: ^11.3.0
  gal: ^2.3.0
  video_player: ^2.8.2
  url_launcher: ^6.2.5

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:ffmpeg_kit_flutter/statistics.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const SpeedConverterProApp());
}

class SpeedConverterProApp extends StatelessWidget {
  const SpeedConverterProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speed Converter Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0E15),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C5CE7),
          surface: Color(0xFF161824),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedVideoPath;
  VideoPlayerController? _videoController;

  // إعدادات المعالجة
  int _selectedFps = 60;
  String _selectedResolution = '1080p';
  double _speedValue = 1.0;
  bool _enableMotionBlur = true;
  bool _enhanceQuality = true;
  bool _enhanceColors = true;

  // حالات التشغيل
  bool _isProcessing = false;
  double _progressPercentage = 0.0;
  double _totalDurationMs = 0.0;
  String _statusMessage = '';

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  // فتح رابط التلجرام الخاص براعي التطبيق
  Future<void> _openTelegramChannel() async {
    final Uri url = Uri.parse('https://t.me/Ronaldoclips5');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _showDialog('خطأ', 'تعذر فتح القناة، يرجى التأكد من تثبيت تطبيق تلجرام.');
    }
  }

  // اختيار الفيديو وتجهيز المشغل
  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (result != null && result.files.single.path != null) {
      String path = result.files.single.path!;
      
      _videoController?.dispose();
      _videoController = VideoPlayerController.file(File(path))
        ..initialize().then((_) {
          setState(() {
            _selectedVideoPath = path;
            _totalDurationMs = _videoController!.value.duration.inMilliseconds.toDouble();
            _statusMessage = 'تم تحميل الفيديو بنجاح';
            _progressPercentage = 0.0;
          });
        });
    }
  }

  // بناء سلسلة فلاتر FFmpeg
  String _buildFFmpegFilter() {
    List<String> filters = [];

    if (_selectedResolution == '1080p') {
      filters.add('scale=1920:1080:flags=bicubic');
    } else if (_selectedResolution == '4K') {
      filters.add('scale=3840:2160:flags=bicubic');
    } else if (_selectedResolution == '720p') {
      filters.add('scale=1280:720:flags=bicubic');
    }

    if (_speedValue != 1.0) {
      double pts = 1.0 / _speedValue;
      filters.add('setpts=$pts*PTS');
    }

    filters.add('fps=$_selectedFps');

    if (_enableMotionBlur) {
      filters.add('tblend=all_mode=average');
    }

    if (_enhanceQuality) {
      filters.add('unsharp=luma_msize_x=5:luma_msize_y=5:luma_amount=1.5');
    }

    if (_enhanceColors) {
      filters.add('eq=contrast=1.1:saturation=1.2:brightness=0.02');
    }

    return filters.join(',');
  }

  // معالجة الفيديو وتصديره
  Future<void> _processVideo() async {
    if (_selectedVideoPath == null) return;

    await [Permission.storage, Permission.videos].request();

    setState(() {
      _isProcessing = true;
      _progressPercentage = 0.0;
      _statusMessage = 'جاري المعالجة والتحسين...';
    });

    final Directory tempDir = await getTemporaryDirectory();
    final String outputPath =
        '${tempDir.path}/SR_PRO_${DateTime.now().millisecondsSinceEpoch}.mp4';

    String filterChain = _buildFFmpegFilter();
    
    String ffmpegCommand =
        '-i "$_selectedVideoPath" -filter:v "$filterChain" -c:v libx264 -crf 17 -preset medium -c:a copy "$outputPath"';

    FFmpegKit.executeAsync(
      ffmpegCommand,
      (session) async {
        final returnCode = await session.getReturnCode();

        setState(() {
          _isProcessing = false;
        });

        if (ReturnCode.isSuccess(returnCode)) {
          await Gal.putVideo(outputPath);
          setState(() {
            _statusMessage = 'تم حفظ الفيديو في الاستوديو بنجاح!';
            _progressPercentage = 100.0;
          });
          _showDialog('تم التصدير بنجاح 🎉', 'تم معالجة الفيديو بالدقة والجودة العالية وحفظه في المعرض.');
        } else {
          setState(() {
            _statusMessage = 'حدث خطأ أثناء معالجة الفيديو';
          });
          _showDialog('خطأ', 'فشلت معالجة الفيديو، تأكد من وجود مساحة كافية وحاول مجدداً.');
        }
      },
      (log) {},
      (Statistics statistics) {
        if (_totalDurationMs > 0) {
          double timeInMs = statistics.getTime().toDouble();
          double progress = (timeInMs / _totalDurationMs) * 100;
          setState(() {
            _progressPercentage = progress.clamp(0.0, 99.0);
          });
        }
      },
    );
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161824),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(content, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق', style: TextStyle(color: Color(0xFF6C5CE7))),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161824),
        elevation: 0,
        centerTitle: true,
        title: const Text('Speed Converter PRO', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.telegram, color: Color(0xFF29B6F6), size: 28),
            tooltip: 'قناة المطور',
            onPressed: _openTelegramChannel,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // بطاقة التلجرام الخاصة بالمالك/الراعي
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF29B6F6), Color(0xFF0288D1)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.telegram, color: Colors.white, size: 32),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'قناة المطور والراعي',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          '@Ronaldoclips5',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _openTelegramChannel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0288D1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('انضمام', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            // معاينة الفيديو / زر الاختيار
            GestureDetector(
              onTap: _isProcessing ? null : _pickVideo,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFF161824),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF6C5CE7).withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: _videoController != null && _videoController!.value.isInitialized
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        ),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_library_rounded, size: 50, color: Color(0xFF6C5CE7)),
                          SizedBox(height: 12),
                          Text('اضغط لاختيار فيديو لمعالجته', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // خيارات الدقة
            const Text('الدقة المكتسبة (Resolution)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: ['Original', '720p', '1080p', '4K'].map((res) {
                final isSelected = _selectedResolution == res;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Center(child: Text(res, style: const TextStyle(fontSize: 12))),
                      selected: isSelected,
                      selectedColor: const Color(0xFF6C5CE7),
                      backgroundColor: const Color(0xFF161824),
                      onSelected: (val) {
                        if (val) setState(() => _selectedResolution = res);
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // خيارات FPS
            const Text('معدل الإطارات (FPS)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [30, 60, 120].map((fps) {
                final isSelected = _selectedFps == fps;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Center(child: Text('$fps FPS')),
                      selected: isSelected,
                      selectedColor: const Color(0xFF6C5CE7),
                      backgroundColor: const Color(0xFF161824),
                      onSelected: (val) {
                        if (val) setState(() => _selectedFps = fps);
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // التبديل بين الخيارات
            _buildToggleOption(
              title: 'توضيح وتنعيم التفاصيل (HD Sharpening)',
              subtitle: 'زيادة حدة الحواف وتوضيح الإطارات الضبابية',
              value: _enhanceQuality,
              onChanged: (val) => setState(() => _enhanceQuality = val),
            ),
            const SizedBox(height: 10),
            _buildToggleOption(
              title: 'تحسين الألوان والتباين (Color Boost)',
              subtitle: 'إشباع الألوان وضبط مستوى التباين تلقائياً',
              value: _enhanceColors,
              onChanged: (val) => setState(() => _enhanceColors = val),
            ),
            const SizedBox(height: 10),
            _buildToggleOption(
              title: 'ضبابية الحركة (Motion Blur)',
              subtitle: 'تنعيم الحركة بين الإطارات لمظهر سينمائي',
              value: _enableMotionBlur,
              onChanged: (val) => setState(() => _enableMotionBlur = val),
            ),
            const SizedBox(height: 20),

            // السرعة
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('سرعة الفيديو', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text('${_speedValue.toStringAsFixed(1)}x', style: const TextStyle(color: Color(0xFF6C5CE7), fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: _speedValue,
              min: 0.25,
              max: 2.0,
              divisions: 7,
              activeColor: const Color(0xFF6C5CE7),
              onChanged: (val) => setState(() => _speedValue = val),
            ),

            const SizedBox(height: 15),

            if (_isProcessing) ...[
              LinearProgressIndicator(
                value: _progressPercentage / 100,
                color: const Color(0xFF6C5CE7),
                backgroundColor: Colors.white10,
              ),
              const SizedBox(height: 8),
              Text(
                '${_progressPercentage.toStringAsFixed(0)}% مكتمل',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6C5CE7)),
              ),
              const SizedBox(height: 8),
            ],

            if (_statusMessage.isNotEmpty)
              Text(_statusMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),

            const SizedBox(height: 20),

            // زر التصدير والمعالجة
            ElevatedButton(
              onPressed: (_selectedVideoPath == null || _isProcessing) ? null : _processVideo,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('بدء المعالجة والتصدير للغاليري', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleOption({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161824),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        value: value,
        activeColor: const Color(0xFF6C5CE7),
        onChanged: onChanged,
      ),
    );
  }
}

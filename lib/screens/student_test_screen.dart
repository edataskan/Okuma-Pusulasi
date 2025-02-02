import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:just_audio/just_audio.dart';
import 'package:okuma_pusulasi_3/screens/word_test_screen.dart';
import 'package:path_provider/path_provider.dart';

import 'package:permission_handler/permission_handler.dart';

class StudentTestScreen extends StatefulWidget {
  final String classId;
  final String studentId;
  final String testId;

  const StudentTestScreen({
    Key? key,
    required this.classId,
    required this.studentId,
    required this.testId,
  }) : super(key: key);

  @override
  _StudentTestScreenState createState() => _StudentTestScreenState();
}

class _StudentTestScreenState extends State<StudentTestScreen> {
  bool _isLetterSoundPlayed =
      false; // Harf sesinin çalıp çalmadığını takip etmek için bir bayrak

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  final PageController _pageController = PageController();

  bool _isWordTest = false;
  bool _isPlaying = false;
  bool _isAudioPlaying = false;
  int? _currentLetterIndex;
  String _currentLetter = '';
  int _currentPage = 0;
  Timer? _recordingTimer;
  bool _isRecording = false;
  bool _isRecorderInitialized = false;

  @override
  void initState() {
    super.initState();
    _listenToTestChanges();
    _initializeRecorder();
    _playLocalAudioAndStartRecording();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.closeRecorder();
    _audioPlayer.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeRecorder() async {
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw Exception('Microphone permission not granted');
      }

      // Initialize the recorder only if permission is granted
      await _audioRecorder.openRecorder();
      _isRecorderInitialized = true;
      print("Recorder başarıyla açıldı.");
    } catch (e) {
      print("Recorder açılırken hata oluştu: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mikrofon izni gerekli: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _playLocalAudioAndStartRecording() async {
    try {
      setState(() {
        _isAudioPlaying = true;
      });

      await _audioPlayer.setAsset('assets/deneme.mp3');
      await _audioPlayer.play();

      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          setState(() {
            _isAudioPlaying = false;
          });
          _startRecording(widget.studentId);

          // 5 saniye sonra kaydı durdur
          _recordingTimer = Timer(const Duration(seconds: 5), () {
            _stopRecordingAndSave();
          });
        }
      });
    } catch (e) {
      setState(() {
        _isAudioPlaying = false;
      });

    }
  }

  Future<void> _startRecording(String studentId) async {
    final permissionStatus = await Permission.microphone.status;
    if (permissionStatus != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mikrofon izni gerekli'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    if (_isRecorderInitialized && !_audioRecorder.isRecording) {
      try {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.aac';
        final String filePath = '${appDir.path}/$fileName';



        await _audioRecorder.startRecorder(
          toFile: filePath,
          codec: Codec.aacADTS,
        );

        setState(() {
          _isRecording = true;
        });

      } catch (e) {

      }
    }
  }

  Future<void> _stopRecordingAndSave() async {
    if (_isRecorderInitialized && _audioRecorder.isRecording) {
      try {
        final String? filePath = await _audioRecorder.stopRecorder();

        setState(() {
          _isRecording = false;
        });

        if (filePath != null) {
          final File recordingFile = File(filePath);

          if (await recordingFile.exists()) {
            print("Dosya başarıyla oluşturuldu: ${await recordingFile.length()} bytes");

            // Firestore'a kaydetme
            await _firestore
                .collection('classes')
                .doc(widget.classId)
                .collection('students')
                .doc(widget.studentId)
                .collection('recordings')
                .add({
              'filePath': filePath,
              'timestamp': FieldValue.serverTimestamp(),
              'studentId': widget.studentId,
              'testId': widget.testId,
            });


          } else {
            throw Exception('Kayıt dosyası oluşturulamadı');
          }
        }
      } catch (e) {

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ses kaydı kaydedilemedi: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _listenToTestChanges() {
    // Mevcut test dinleyicisi
    _firestore
        .collection('classes')
        .doc(widget.classId)
        .collection('students')
        .doc(widget.studentId)
        .collection('tests')
        .doc(widget.testId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists) {
        final bool isWordTest = snapshot.data()?['isWordTest'] ?? false;
        final bool isAdvancedTest = snapshot.data()?['isAdvancedTest'] ?? false;
        final String letters = snapshot.data()?['letters'] ?? '';

        // 29 harflik teste geçiş kontrolü
        if (isAdvancedTest && letters.length == 29 && !_isLetterSoundPlayed) {
          _playLetterSound();
          setState(() {
            _isLetterSoundPlayed = true;
          });
        }

        // Kelime testine geçiş kontrolü
        if (isWordTest && !_isWordTest) {
          setState(() {
            _isWordTest = true;
          });

          // En son oluşturulan word test dokümanını bul
          final wordTestsSnapshot = await _firestore
              .collection('classes')
              .doc(widget.classId)
              .collection('students')
              .doc(widget.studentId)
              .collection('word_tests')
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();

          if (wordTestsSnapshot.docs.isNotEmpty) {
            final latestWordTest = wordTestsSnapshot.docs.first;
            _navigateToWordTest(latestWordTest.id);
          }
        }
      }
    });
  }

  void _navigateToWordTest(String wordTestId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WordTestScreen(
          classId: widget.classId,
          studentId: widget.studentId,
          testId: wordTestId,
          isTeacher: false, // Öğrenci olduğunu belirt
        ),
      ),
    );
  }

// Yeni ses çalma metodu
  Future<void> _playLetterSound() async {
    try {
      setState(() {
        _isAudioPlaying = true;
      });

      await _audioPlayer.setAsset('assets/letter_sound.mp3');
      await _audioPlayer.play();

      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          setState(() {
            _isAudioPlaying = false;
          });
        }
      });
    } catch (e) {
      setState(() {
        _isAudioPlaying = false;
      });
      print("Ses çalma hatası: $e");
    }
  }

  Future<void> _playSound(String letter, int index) async {
    if (_isPlaying) return;

    setState(() {
      _isPlaying = true;
      _currentLetterIndex = index;
      _currentLetter = letter;
    });

    try {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
    } catch (e) {
      setState(() {
        _isPlaying = false;
        _currentLetterIndex = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ses çalınırken hata oluştu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildLetterCard(String letter) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            letter,
            style: const TextStyle(
              fontFamily:
                  'TemelYazi', // Burada Temelyazi ismi font ailesinin adı.
              fontSize: 96, // Boyutunu istediğiniz gibi ayarlayabilirsiniz.
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Öğrenci Testi'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore
            .collection('classes')
            .doc(widget.classId)
            .collection('students')
            .doc(widget.studentId)
            .collection('tests')
            .doc(widget.testId)
            .snapshots(),
        builder: (context, snapshot) {
          if (_isAudioPlaying) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/listening.png',
                    width: 400,
                    height: 400,
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(height: 10),
                  const CircularProgressIndicator(),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final testData = snapshot.data!.data() as Map<String, dynamic>;
          final letters = testData['letters'] as String? ?? '';
          final bool completed = testData['completed'] ?? false;

          if (completed) {
            return const Center(
              child: Text(
                'Test tamamlandı.\nSonuçlar öğretmeniniz tarafından değerlendirilecek.\n😊',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22),
              ),
            );
          }

          return Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: (letters.length / 4).ceil(),
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, pageIndex) {
                  // Her sayfada 3 harf göster
                  final startIndex =
                      pageIndex * 4; // Her sayfada 4 harf gösterilecek.
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        if (startIndex < letters.length)
                          _buildLetterCard(letters[startIndex]),
                        if (startIndex + 1 < letters.length)
                          _buildLetterCard(letters[startIndex + 1]),
                        if (startIndex + 2 < letters.length)
                          _buildLetterCard(letters[startIndex + 2]),
                        if (startIndex + 3 < letters.length)
                          _buildLetterCard(letters[startIndex + 3]),
                        // Eğer son sayfada 4'ten az harf varsa, boş Expanded widget ekle
                        if (startIndex + 1 >= letters.length)
                          const Expanded(child: SizedBox()),
                        if (startIndex + 2 >= letters.length)
                          const Expanded(child: SizedBox()),
                        if (startIndex + 3 >= letters.length)
                          const Expanded(child: SizedBox()),
                      ],
                    ),
                  );
                },
              ),
              // Sol Ok
              if (_currentPage > 0)
                Positioned(
                  left: 10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 40),
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ),
                ),
              // Sağ Ok
              if (_currentPage < (letters.length / 4).ceil() - 1)
                Positioned(
                  right: 10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 40),
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

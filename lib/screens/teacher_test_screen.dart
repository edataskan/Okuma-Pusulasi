import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:okuma_pusulasi_3/screens/word_test_screen.dart';
import 'test_results_screen.dart';
import 'class_screen.dart';
import 'utils.dart'; // Yeni import

class TeacherTestScreen extends StatefulWidget {
  final String classId;
  final String studentId;
  final String testId;

  const TeacherTestScreen({
    Key? key,
    required this.classId,
    required this.studentId,
    required this.testId,
  }) : super(key: key);

  @override
  _TeacherTestScreenState createState() => _TeacherTestScreenState();
}

class _TeacherTestScreenState extends State<TeacherTestScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  int? _currentLetterIndex;
  bool _isSubmitting = false;
  bool _loading = true;
  String _studentName = '';

  int _currentWordIndex = 0; // Kelime listesindeki mevcut konum

  @override
  void initState() {
    super.initState();
    _loadStudentName();
  }

  Future<void> _loadNextWords() async {
    try {
      final String wordData = await rootBundle.loadString('assets/word.txt');
      final List<String> allWords = wordData
          .split('\n')
          .where((word) => word.trim().isNotEmpty)
          .map((word) => word.trim())
          .toList();

      // Calculate next index
      final nextIndex = _currentWordIndex + 10;

      // Check if we have enough words
      if (nextIndex >= allWords.length) {
        throw Exception('Tüm kelimeler tamamlandı');
      }

      // Get next batch of words
      final nextWords = allWords.sublist(
        nextIndex,
        min(nextIndex + 10, allWords.length),
      );

      // Update Firestore with new words
      await _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('word_tests')
          .doc(widget.testId) // Use the same test ID
          .update({
        'currentWordIndex': nextIndex,
        'words': nextWords,
      });

      setState(() {
        _currentWordIndex = nextIndex;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadStudentName() async {
    try {
      final studentDoc = await _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .get();

      if (mounted && studentDoc.exists) {
        setState(() {
          _studentName = studentDoc.data()?['name'] ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _startWordTest() async {
    try {
      // Önce mevcut test dokümanını güncelle
      await _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('tests')
          .doc(widget.testId)
          .update({
        'isWordTest': true,
      });

      final String wordData = await rootBundle.loadString('assets/word.txt');
      final List<String> allWords = wordData
          .split('\n')
          .where((word) => word.trim().isNotEmpty)
          .map((word) => word.trim())
          .toList();

      // İlk 10 kelimeyi al
      final selectedWords = allWords.sublist(0, 10);

      // Yeni word test dokümanı oluştur
      final wordTestRef = await _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('word_tests')
          .add({
        'words': selectedWords,
        'createdAt': FieldValue.serverTimestamp(),
        'completed': false,
        'results': Map.fromIterable(selectedWords, value: (_) => null),
        'currentIndex': 0,
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WordTestScreen(
              classId: widget.classId,
              studentId: widget.studentId,
              testId: wordTestRef
                  .id, // Yeni oluşturulan word test dokümanının ID'si
              isTeacher: true, // Öğretmen olduğunu belirt
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateLetterStatus(int index, bool isCorrect) async {
    try {
      final docRef = _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('tests')
          .doc(widget.testId);

      final doc = await docRef.get();
      if (!doc.exists) {
        throw Exception('Test bulunamadı');
      }

      final data = doc.data()!;
      final List<dynamic> status = List<dynamic>.from(data['status'] ?? []);

      // Durumu güncelle
      status[index] = isCorrect;

      // Firestore güncelle
      await docRef.update({
        'status': status,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _finishTest() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 1. Test verisini al
      final testDoc = await _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('tests')
          .doc(widget.testId)
          .get();

      if (!testDoc.exists) {
        throw Exception('Test bulunamadı');
      }

      final testData = testDoc.data()!;
      final List<dynamic> status = List<dynamic>.from(testData['status'] ?? []);

      // 2. Tüm harflerin değerlendirildiğinden emin ol
      if (status.any((s) => s == null)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lütfen tüm harfleri değerlendirin'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 3. Sonuçları hesapla
      final correctCount = status.where((s) => s == true).length;
      final totalQuestions = status.length;
      final score = (correctCount / totalQuestions) * 100;

      // 4. Test sonuç verisini hazırla
      final Map<String, dynamic> resultData = {
        'completed': true,
        'completedAt': FieldValue.serverTimestamp(),
        'score': score,
        'correctCount': correctCount,
        'totalQuestions': totalQuestions,
        'letters': testData['letters'] ?? '',
        'status': status,
        'testType': testData['letters'].length == 9 ? '9_harf' : '29_harf',
        'timestamp': FieldValue.serverTimestamp(),
      };

      // 5. Test history'ye kaydet
      await _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('test_history')
          .add(resultData);

      print('Test sonucu başarıyla kaydedildi: $resultData'); // Debug için

      // 6. Orijinal test dokümanını güncelle
      await testDoc.reference.update(resultData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test sonuçları kaydedildi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Test sonuçları kaydedilirken hata: $e'); // Debug için
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

// 29 harflik teste geçiş için _startNewTest metodunu da güncelleyin
  Future<void> _startNewTest(int correctCount, int attemptCount) async {
    try {
      await _firestore.runTransaction((transaction) async {
        if (correctCount == 0 && attemptCount == 1) {
          // 9 harflik yeni test
          final newLetters = generateRandomLetters(9);
          final testRef = _firestore
              .collection('classes')
              .doc(widget.classId)
              .collection('students')
              .doc(widget.studentId)
              .collection('tests')
              .doc(widget.testId);

          transaction.update(testRef, {
            'letters': newLetters,
            'status': List.generate(9, (_) => null),
            'completed': false,
            'timestamp': FieldValue.serverTimestamp(),
            'attemptCount': 2,
          });

        } else if (correctCount >= 1) {
          // 29 harflik yeni test
          final newLetters = generateRandomLetters(29);
          final testRef = _firestore
              .collection('classes')
              .doc(widget.classId)
              .collection('students')
              .doc(widget.studentId)
              .collection('tests')
              .doc(widget.testId);

          transaction.update(testRef, {
            'letters': newLetters,
            'status': List.generate(29, (_) => null),
            'completed': false,
            'timestamp': FieldValue.serverTimestamp(),
            'isAdvancedTest': true,
          });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yeni test başlatılamadı: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

// ... existing code ...
  Future<void> _resetTest() async {
    try {
      final testDoc = _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('tests')
          .doc(widget.testId);

      final snapshot = await testDoc.get();
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final String letters = data['letters'] ?? generateRandomLetters(9);

      await testDoc.update({
        'status': List.filled(letters.length, null),
        'completed': false,
        'score': 0,
        'correctCount': 0,
        'resetAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test sıfırlama hatası: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isSubmitting) return false;
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_loading
              ? 'Test Değerlendirme'
              : '$_studentName - Test Değerlendirme'),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFFBBDEFB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: StreamBuilder<DocumentSnapshot>(
            stream: _firestore
                .collection('classes')
                .doc(widget.classId)
                .collection('students')
                .doc(widget.studentId)
                .collection('tests')
                .doc(widget.testId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Hata: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: Text('Test bulunamadı'));
              }

              final testData = snapshot.data!.data() as Map<String, dynamic>;
              final bool completed = testData['completed'] ?? false;

              if (completed) {
                final int correctCount = testData['correctCount'] ?? 0;
                final bool isAdvancedTest = testData['isAdvancedTest'] ?? false;
                final int attemptCount = testData['attemptCount'] ?? 1;

                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (correctCount == 0 && attemptCount == 2) ...[
                        const Text(
                          'Öğrenciye sıfır puan verildi.',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => Navigator.popUntil(
                                  context, (route) => route.isFirst),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 16),
                                backgroundColor: Colors.blue,
                              ),
                              child: const Text(
                                'Ana Sayfaya Dön',
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 16),
                                backgroundColor: Colors.red,
                              ),
                              child: const Text(
                                'Testi Bitir',
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                          ],
                        ),
                      ] else if (!isAdvancedTest)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => Navigator.popUntil(
                                  context, (route) => route.isFirst),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 16),
                                backgroundColor: Colors.blue,
                              ),
                              child: const Text(
                                'Ana Sayfaya Dön',
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: () =>
                                  _startNewTest(correctCount, attemptCount),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 16),
                                backgroundColor: Colors.white,
                              ),
                              child: Text(
                                correctCount > 0
                                    ? 'Sıradaki Teste Geç (29 Harf)'
                                    : 'Sıradaki Teste Geç (9 Harf)',
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ],
                        )
                      else if (correctCount > 0) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => Navigator.popUntil(
                                  context, (route) => route.isFirst),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 16),
                                backgroundColor: Colors.blue,
                              ),
                              child: const Text(
                                'Ana Sayfaya Dön',
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: () =>
                                  _startNewTest(correctCount, attemptCount),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 16),
                                backgroundColor: Colors.white,
                              ),
                              child: const Text(
                                'Harf Listesinden\nDevam Et',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: _startWordTest,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 16),
                                backgroundColor: Colors.green,
                              ),
                              child: const Text(
                                'Kelime Listesine\nGeç',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ] else if (correctCount == 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => Navigator.popUntil(
                                  context, (route) => route.isFirst),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 16),
                                backgroundColor: Colors.blue,
                              ),
                              child: const Text(
                                'Ana Sayfaya Dön',
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 16),
                                backgroundColor: Colors.red,
                              ),
                              child: const Text(
                                'Testi Bitir',
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              }
              return _buildTestEvaluationScreen(testData);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTestEvaluationScreen(Map<String, dynamic> testData) {
    final String letters = testData['letters'] ?? '';
    final List<dynamic> status = List<dynamic>.from(testData['status'] ?? []);

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
          ),
          child: Column(
            children: [
              const Text(
                'Test Harfleri:',
                style: TextStyle(
                  fontFamily: 'TemelYazi',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                letters,
                style: const TextStyle(
                  fontFamily: 'TemelYazi',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: status.where((s) => s != null).length / letters.length,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.blue.shade300,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${status.where((s) => s != null).length}/${letters.length} harf değerlendirildi',
                style: TextStyle(
                  fontFamily: 'TemelYazi',
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: letters.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final letter = letters[index];
              final currentStatus = status[index];

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: currentStatus == null
                        ? Colors.grey.shade200
                        : currentStatus
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontFamily: 'TemelYazi',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: currentStatus == null
                            ? Colors.grey.shade700
                            : currentStatus
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                      ),
                    ),
                  ),
                  title: Text(
                    'Harf ${index + 1}',
                    style: const TextStyle(
                      fontFamily: 'TemelYazi',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: currentStatus == null
                      ? const Text('Değerlendirilmedi')
                      : Text(
                          currentStatus ? 'Doğru' : 'Yanlış',
                          style: TextStyle(
                            color: currentStatus ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.check_circle,
                          color: currentStatus == true
                              ? Colors.green
                              : Colors.grey.shade300,
                          size: 32,
                        ),
                        onPressed: () => _updateLetterStatus(index, true),
                        tooltip: 'Doğru',
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.cancel,
                          color: currentStatus == false
                              ? Colors.red
                              : Colors.grey.shade300,
                          size: 32,
                        ),
                        onPressed: () => _updateLetterStatus(index, false),
                        tooltip: 'Yanlış',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _resetTest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text('Testi Sıfırla'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _finishTest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check_circle),
                      const SizedBox(width: 8),
                      Text(_isSubmitting ? 'İşleniyor...' : 'Testi Bitir'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Temizlik işlemleri burada yapılabilir
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class StudentTestHistoryScreen extends StatefulWidget {
  final String classId;
  final String studentId;
  final String studentName;

  const StudentTestHistoryScreen({
    Key? key,
    required this.classId,
    required this.studentId,
    required this.studentName,
  }) : super(key: key);

  @override
  State<StudentTestHistoryScreen> createState() => _StudentTestHistoryScreenState();
}

class _StudentTestHistoryScreenState extends State<StudentTestHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingPath;

  String determineTestType(Map<String, dynamic> testData) {
    final letters = testData['letters'] as String? ?? '';
    if (letters.length == 9) {
      return 'Deneme Testi';
    } else if (letters.length == 29) {
      return 'Harf Testi';
    } else {
      return 'Kelime Testi';
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> playAudio(String filePath) async {
    try {
      // Eğer aynı dosya çalıyorsa, durdur
      if (_currentlyPlayingPath == filePath && _audioPlayer.playing) {
        await _audioPlayer.stop();
        setState(() => _currentlyPlayingPath = null);
        return;
      }

      // Dosya yolunu kontrol et ve dosyanın varlığını doğrula
      final File audioFile = File(filePath);
      if (!await audioFile.exists()) {
        print('Dosya bulunamadı: $filePath');
        return;
      }

      // Önceki sesi durdur
      await _audioPlayer.stop();

      // Yeni sesi yükle ve çal
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.play();
      setState(() => _currentlyPlayingPath = filePath);

      // Ses bittiğinde state'i güncelle
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) {
            setState(() => _currentlyPlayingPath = null);
          }
        }
      });

    } catch (e) {
      print('Ses çalma hatası: $e');
      if (mounted) {
        setState(() => _currentlyPlayingPath = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.studentName} - Test Geçmişi ve Ses Kayıtları',
          style: const TextStyle(
            fontFamily: 'ComicSans',
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.pink,
        elevation: 10,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade100, Colors.cyan.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('classes')
                    .doc(widget.classId)
                    .collection('students')
                    .doc(widget.studentId)
                    .collection('tests')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Hata: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final tests = snapshot.data!.docs;

                  if (tests.isEmpty) {
                    return const Center(
                      child: Text(
                        'Bu öğrenci için herhangi bir test bulunamadı.',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'ComicSans',
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: tests.length,
                    itemBuilder: (context, index) {
                      final testData = tests[index].data() as Map<String, dynamic>;
                      final testId = tests[index].id;
                      final testType = determineTestType(testData);
                      final testDate = testData['timestamp']?.toDate();
                      final formattedDate = testDate != null
                          ? '${testDate.day}/${testDate.month}/${testDate.year} - ${testDate.hour}:${testDate.minute}'
                          : 'Bilinmeyen Tarih';

                      return Card(
                        margin: EdgeInsets.symmetric(
                          vertical: screenHeight * 0.01,
                          horizontal: screenWidth * 0.05,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 8,
                        shadowColor: Colors.blueAccent,
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          title: Text(
                            'Test Türü: $testType',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'ComicSans',
                              fontSize: 18,
                              color: Colors.blueAccent,
                            ),
                          ),
                          subtitle: Text(
                            'Tarih: $formattedDate',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          leading: const Icon(
                            Icons.quiz,
                            size: 32,
                            color: Colors.pink,
                          ),
                          children: [
                            ListTile(
                              title: Text(
                                'Skor: ${testData['score'] ?? 'Belirtilmemiş'}',
                                style: const TextStyle(
                                  fontFamily: 'ComicSans',
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Doğru Sayısı: ${testData['correctCount'] ?? 0}',
                                    style: const TextStyle(fontFamily: 'ComicSans'),
                                  ),
                                  Text(
                                    'Yanlış Sayısı: ${(testData['totalQuestions'] ?? 0) - (testData['correctCount'] ?? 0)}',
                                    style: const TextStyle(fontFamily: 'ComicSans'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(
              height: 1,
              thickness: 2,
              color: Colors.blueGrey,
            ),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Ses Kayıtları',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'ComicSans',
                      ),
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('classes')
                          .doc(widget.classId)
                          .collection('students')
                          .doc(widget.studentId)
                          .collection('recordings')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('Hata: ${snapshot.error}'));
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final recordings = snapshot.data!.docs;

                        if (recordings.isEmpty) {
                          return const Center(
                            child: Text(
                              'Kayıt bulunamadı.',
                              style: TextStyle(
                                fontFamily: 'ComicSans',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: recordings.length,
                          itemBuilder: (context, index) {
                            final recordingData = recordings[index].data() as Map<String, dynamic>;
                            final filePath = recordingData['filePath'] ?? 'Dosya Yolu Yok';
                            final timestamp = recordingData['timestamp']?.toDate();
                            final formattedTimestamp = timestamp != null
                                ? '${timestamp.day}/${timestamp.month}/${timestamp.year} - ${timestamp.hour}:${timestamp.minute}'
                                : 'Bilinmeyen Tarih';

                            final isPlaying = _currentlyPlayingPath == filePath;

                            return ListTile(
                              leading: Icon(
                                Icons.mic,
                                color: Colors.blueAccent,
                                size: screenHeight * 0.05,
                              ),
                              title: Text('Kayıt Tarihi: $formattedTimestamp'),
                              subtitle: Text('Dosya Yolu: $filePath'),
                              trailing: IconButton(
                                icon: Icon(
                                  isPlaying ? Icons.stop : Icons.play_arrow,
                                  color: isPlaying ? Colors.red : Colors.green,
                                ),
                                onPressed: () => playAudio(filePath),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
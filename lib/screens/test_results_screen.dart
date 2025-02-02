import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:okuma_pusulasi_3/screens/word_test_screen.dart';

class TestResultsScreen extends StatelessWidget {
  final String classId;
  final String studentId;
  final String testId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  TestResultsScreen({
    Key? key,
    required this.classId,
    required this.studentId,
    required this.testId,
  }) : super(key: key);

  Future<void> _restartTest(BuildContext context) async {
    try {
      await _firestore
          .collection('classes')
          .doc(classId)
          .collection('students')
          .doc(studentId)
          .collection('tests')
          .doc(testId)
          .update({
        'completed': false,
        'status': List.filled(29, null),
        'score': 0,
        'correctCount': 0,
        'resetAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: ${e.toString()}'),
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
        Navigator.of(context).popUntil((route) => route.isFirst);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Test Geçmişi ve Ses Kayıtları'),
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Test Sonuçları Bölümü
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Sonuçları',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // StreamBuilder'ı güncelleyin
    // FutureBuilder yerine StreamBuilder'ı geri getirin
                    StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('classes')
                          .doc(classId)
                          .collection('students')
                          .doc(studentId)
                          .collection('test_history')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        // BURAYA EKLEYIN - EN ÜST
                        debugPrint('==================');
                        debugPrint('BAĞLANTI DURUMU: ${snapshot.connectionState}');
                        debugPrint('HATA VAR MI: ${snapshot.hasError}');

                        if (snapshot.hasError) {
                          debugPrint('HATA: ${snapshot.error}');
                          return Center(child: Text('Hata: ${snapshot.error}'));
                        }

                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final tests = snapshot.data!.docs;
                        // BURAYA EKLEYIN - TEST SAYISI
                        debugPrint('==================');
                        debugPrint('TEST VERİLERİ BAŞLANGIÇ');
                        debugPrint('Firestore\'dan gelen test sayısı: ${tests.length}');

                        if (tests.isEmpty) {
                          return const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('Henüz test sonucu bulunmuyor'),
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: tests.length,
                          itemBuilder: (context, index) {
                            final testData = tests[index].data() as Map<String, dynamic>;
                            // BURAYA EKLEYIN - HER TEST İÇİN
                            debugPrint('Test ${index + 1} detayları: ${testData.toString()}');

                            if (testData['testType'] == null) {
                              debugPrint('UYARI: Test kaydı $index testType alanı eksik');
                              return const SizedBox.shrink();
                            }
    final timestamp = testData['timestamp'] as Timestamp?;
    final score = testData['score'] ?? 0.0;
    final testType = testData['testType'] as String?;

    // Tüm test verilerini göster, completed kontrolünü kaldır
    return Card(
    margin: const EdgeInsets.only(bottom: 8),
    elevation: 2,
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    ),
    child: ExpansionTile(
    title: Row(
    children: [
    Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
    color: Colors.pink.shade50,
    borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(
    Icons.assignment,
    color: Colors.pink,
    size: 24,
    ),
    ),
    const SizedBox(width: 12),
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    'Test Türü: ${_getTestTypeText(testType ?? '')}',
    style: const TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 16,
    ),
    ),
    Text(
    'Tarih: ${_formatTimestamp(timestamp)}',
    style: TextStyle(
    fontSize: 14,
    color: Colors.grey[600],
    ),
    ),
    ],
    ),
    ),
    ],
    ),
    subtitle: Row(
    children: [
    Expanded(
    child: LinearProgressIndicator(
    value: score / 100,
    backgroundColor: Colors.grey[200],
    valueColor: AlwaysStoppedAnimation<Color>(
    score >= 80 ? Colors.green : Colors.orange,
    ),
    minHeight: 4,
    ),
    ),
    const SizedBox(width: 8),
    Text(
    '%${score.toStringAsFixed(1)}',
    style: TextStyle(
    color: score >= 80 ? Colors.green : Colors.orange,
    fontWeight: FontWeight.bold,
    ),
    ),
    ],
    ),
    children: [
    _buildTestDetails(testData),
    ],
    ),
    );
    },
    );
    },
    ),

                  ],
                ),
              ),

              // Ses Kayıtları Bölümü
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ses Kayıtları',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('classes')
                          .doc(classId)
                          .collection('students')
                          .doc(studentId)
                          .collection('recordings')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final recordings = snapshot.data!.docs;

                        if (recordings.isEmpty) {
                          return const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('Henüz ses kaydı bulunmuyor'),
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: recordings.length,
                          itemBuilder: (context, index) {
                            final recordingData = recordings[index].data() as Map<String, dynamic>;
                            final timestamp = recordingData['timestamp'] as Timestamp?;
                            final filePath = recordingData['filePath'] as String?;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.mic,
                                    color: Colors.blue,
                                    size: 24,
                                  ),
                                ),
                                title: Text(
                                  'Kayıt Tarihi: ${_formatTimestamp(timestamp)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'Dosya Yolu: ${filePath ?? "Belirtilmemiş"}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.play_arrow),
                                  onPressed: () {
                                    // TODO: Implement audio playback
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Tarih Yok';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildTestDetails(Map<String, dynamic> testData) {
    final score = testData['score'] ?? 0.0;
    final correctCount = testData['correctCount'] ?? 0;
    final letters = testData['letters'] as String?;
    final words = testData['words'] as List<dynamic>?;
    final totalQuestions = letters?.length ?? words?.length ?? 0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress indicator
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: score / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    score >= 80 ? Colors.green : Colors.orange,
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${score.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: score >= 80 ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Statistics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildStatRow('Toplam Soru', totalQuestions.toString()),
                  _buildStatRow('Doğru Cevap', correctCount.toString()),
                  _buildStatRow(
                    'Yanlış Cevap',
                    (totalQuestions - correctCount).toString(),
                  ),
                  _buildStatRow(
                    'Başarı Durumu',
                    score >= 80 ? 'Başarılı' : 'Başarısız',
                    textColor: score >= 80 ? Colors.green : Colors.red,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Letter or Word details
          if (letters != null)
            _buildLetterResults(testData)
          else if (words != null)
            _buildWordResults(testData),
        ],
      ),
    );
  }
  String _getTestTypeText(String type) {
    switch (type) {
      case 'word_test':
        return 'Kelime Testi';
      case '9_harf':
        return '9 Harf Testi';
      case '29_harf':
        return '29 Harf Testi';
      default:
        return 'Bilinmeyen Test';
    }
  }

// Kelime testi sonuçlarını göstermek için yardımcı metod
  Widget _buildWordResults(Map<String, dynamic> testData) {
    final words = testData['words'] as List<dynamic>?;
    final results = Map<String, dynamic>.from(testData['results'] ?? {});

    if (words == null || words.isEmpty) {
      return const Text('Kelime sonuçları bulunamadı');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kelime Detayları',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: words.length,
          itemBuilder: (context, index) {
            final word = words[index];
            final isCorrect = results[word] == true;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isCorrect ? Colors.green : Colors.red,
                  child: Icon(
                    isCorrect ? Icons.check : Icons.close,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  'Kelime ${index + 1}: $word',
                  style: const TextStyle(fontSize: 16),
                ),
                trailing: Text(
                  isCorrect ? 'Doğru' : 'Yanlış',
                  style: TextStyle(
                    color: isCorrect ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
  Widget _buildLetterResults(Map<String, dynamic> testData) {
    final letters = testData['letters'] as String;
    final List<dynamic> status = List<dynamic>.from(testData['status'] ?? []);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: letters.length,
      itemBuilder: (context, index) {
        final isCorrect = status[index] == true;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isCorrect ? Colors.green : Colors.red,
              child: Icon(
                isCorrect ? Icons.check : Icons.close,
                color: Colors.white,
              ),
            ),
            title: Text(
              'Harf ${index + 1}: ${letters[index]}',
              style: const TextStyle(fontSize: 16),
            ),
            trailing: Text(
              isCorrect ? 'Doğru' : 'Yanlış',
              style: TextStyle(
                color: isCorrect ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }



  Widget _buildStatRow(String label, String value, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
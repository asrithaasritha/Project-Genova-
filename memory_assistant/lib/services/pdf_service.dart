import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/memory.dart';

class PdfService {
  static Future<String> generateMemoriesPdf({
    required List<Memory> memories,
    String? categoryFilter,
    required String title,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/memories_${DateTime.now().millisecondsSinceEpoch}.txt');
      
      final filteredMemories = categoryFilter != null
          ? memories.where((m) => m.category == categoryFilter).toList()
          : memories;

      final content = StringBuffer();
      content.writeln('=== $title ===\n');
      
      for (var memory in filteredMemories) {
        content.writeln('Category: ${memory.category}');
        content.writeln('Date: ${memory.timestamp.toString()}');
        content.writeln('Text: ${memory.text}');
        if (memory.tags.isNotEmpty) {
          content.writeln('Tags: ${memory.tags.join(", ")}');
        }
        content.writeln('\n---\n');
      }

      await file.writeAsString(content.toString());
      return file.path;
    } catch (e) {
      print('Error generating PDF: $e');
      rethrow;
    }
  }
  
  static pw.Widget _buildSummarySection(List<Memory> memories) {
    final categoryCount = <String, int>{};
    for (final memory in memories) {
      categoryCount[memory.category] = (categoryCount[memory.category] ?? 0) + 1;
    }
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Summary',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.indigo,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Categories Breakdown:',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          ...categoryCount.entries.map((entry) => 
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
              child: pw.Text(
                '• ${entry.key}: ${entry.value} ${entry.value == 1 ? 'memory' : 'memories'}',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ),
          ).toList(),
        ],
      ),
    );
  }
  
  static pw.Widget _buildDateSection(String date, List<Memory> memories) {
    final formattedDate = DateFormat('EEEE, MMMM dd, yyyy').format(DateTime.parse(date));
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: pw.BoxDecoration(
            color: PdfColors.indigo50,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(
            formattedDate,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.indigo,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        ...memories.map((memory) => _buildMemoryItem(memory)).toList(),
        pw.SizedBox(height: 16),
      ],
    );
  }
  
  static pw.Widget _buildMemoryItem(Memory memory) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColors.indigo100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  memory.category,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo,
                  ),
                ),
              ),
              pw.Text(
                DateFormat('hh:mm a').format(memory.timestamp),
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            memory.text,
            style: const pw.TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
  
  static Future<void> shareMemoriesPdf(String filePath) async {
    try {
      await Share.shareXFiles([XFile(filePath)], text: 'My Memories');
    } catch (e) {
      print('Error sharing PDF: $e');
      rethrow;
    }
  }
}

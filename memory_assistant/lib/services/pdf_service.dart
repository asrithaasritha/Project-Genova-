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
    String title = 'Memory Assistant Export',
  }) async {
    final pdf = pw.Document();
    
    // Filter memories if category is specified
    final filteredMemories = categoryFilter != null
        ? memories.where((m) => m.category.toLowerCase() == categoryFilter.toLowerCase()).toList()
        : memories;
    
    // Sort by timestamp, newest first
    filteredMemories.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    // Group memories by date
    final groupedMemories = <String, List<Memory>>{};
    for (final memory in filteredMemories) {
      final dateKey = DateFormat('yyyy-MM-dd').format(memory.timestamp);
      groupedMemories.putIfAbsent(dateKey, () => []).add(memory);
    }
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 20),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(width: 2, color: PdfColors.indigo),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    categoryFilter != null 
                        ? 'Category: ${categoryFilter.toUpperCase()}'
                        : 'All Categories',
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Text(
                    'Generated on: ${DateFormat('MMMM dd, yyyy at hh:mm a').format(DateTime.now())}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Total Memories: ${filteredMemories.length}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo,
                    ),
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Summary Statistics
            _buildSummarySection(filteredMemories),
            
            pw.SizedBox(height: 20),
            
            // Memories by date
            ...groupedMemories.entries.map((entry) => 
              _buildDateSection(entry.key, entry.value)
            ).toList(),
          ];
        },
      ),
    );
    
    // Save PDF
    final output = await getApplicationDocumentsDirectory();
    final fileName = 'memories_${categoryFilter ?? 'all'}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    
    return file.path;
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
    await Share.shareXFiles([XFile(filePath)], text: 'My Memory Assistant Export');
  }
}

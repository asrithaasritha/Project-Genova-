import 'package:flutter/material.dart';
import '../models/memory.dart';
import '../services/pdf_service.dart';

class ExportScreen extends StatefulWidget {
  final List<Memory> memories;

  const ExportScreen({Key? key, required this.memories}) : super(key: key);

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  String? selectedCategory;
  bool isExporting = false;
  String? errorMessage;
  String? successMessage;

  List<String> get categories {
    final Set<String> uniqueCategories = widget.memories
        .map((m) => m.category)
        .toSet();
    return ['All Categories', ...uniqueCategories.toList()..sort()];
  }

  List<Memory> get filteredMemories {
    if (selectedCategory == null || selectedCategory == 'All Categories') {
      return widget.memories;
    }
    return widget.memories
        .where((m) => m.category == selectedCategory)
        .toList();
  }

  Future<void> _exportMemories() async {
    setState(() {
      isExporting = true;
      errorMessage = null;
      successMessage = null;
    });

    try {
      final categoryFilter = selectedCategory == 'All Categories' 
          ? null 
          : selectedCategory;

      final filePath = await PdfService.generateMemoriesPdf(
        memories: widget.memories,
        categoryFilter: categoryFilter,
        title: 'Memory Assistant Export',
      );

      await PdfService.shareMemoriesPdf(filePath);
      setState(() {
        successMessage = 'Exported and ready to share!';
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to export memories: $e';
      });
    } finally {
      setState(() {
        isExporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final exportCount = filteredMemories.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Memories'),
        backgroundColor: colorScheme.surfaceContainer,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer,
              colorScheme.surface,
              colorScheme.surfaceContainerLowest,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title and Icon
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.picture_as_pdf,
                          color: colorScheme.primary,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Export Your Memories',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a shareable file of your memories. Filter by category or export all.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Card for export options
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Export Options',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            value: selectedCategory ?? 'All Categories',
                            decoration: InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                            ),
                            items: categories.map((category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedCategory = value;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Icon(Icons.list_alt, color: colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '$exportCount ${exportCount == 1 ? 'memory' : 'memories'} will be exported',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              errorMessage!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          if (successMessage != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              successMessage!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              icon: isExporting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.picture_as_pdf),
                              label: Text(
                                isExporting ? 'Exporting...' : 'Export & Share',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(fontSize: 16),
                              ),
                              onPressed: isExporting || exportCount == 0 ? null : _exportMemories,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 
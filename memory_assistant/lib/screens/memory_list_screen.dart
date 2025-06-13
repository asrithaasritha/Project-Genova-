import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/memory.dart';
import '../services/pdf_service.dart';
import '../services/summary_service.dart';

class MemoryListScreen extends StatefulWidget {
  final List<Memory> memories;
  final String? initialCategory;

  const MemoryListScreen({
    super.key,
    required this.memories,
    this.initialCategory,
  });

  @override
  State<MemoryListScreen> createState() => _MemoryListScreenState();
}

class _MemoryListScreenState extends State<MemoryListScreen> {
  late List<Memory> filteredMemories;
  String? selectedCategory;
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    selectedCategory = widget.initialCategory;
    _filterMemories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterMemories() {
    setState(() {
      filteredMemories = widget.memories.where((memory) {
        final matchesCategory = selectedCategory == null ||
            memory.category.toLowerCase() == selectedCategory!.toLowerCase();
        final matchesSearch = searchQuery.isEmpty || memory.matches(searchQuery);
        
        return matchesCategory && matchesSearch;
      }).toList();
      
      // Sort by timestamp, newest first
      filteredMemories.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  void _onSearchChanged(String query) {
    searchQuery = query;
    _filterMemories();
  }

  void _onCategoryChanged(String? category) {
    selectedCategory = category;
    _filterMemories();
  }

  List<String> _getUniqueCategories() {
    final categories = widget.memories.map((m) => m.category).toSet().toList();
    categories.sort();
    return categories;
  }

  Future<void> _exportToPdf() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final filePath = await PdfService.generateMemoriesPdf(
        memories: widget.memories,
        categoryFilter: selectedCategory,
        title: selectedCategory != null 
            ? '$selectedCategory Memories Export'
            : 'Memory Assistant Export',
      );

      if (!mounted) return;

      // Show success dialog with options
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('PDF Export Successful'),
          content: Text('Your memories have been exported to:\n${filePath.split('/').last}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                PdfService.shareMemoriesPdf(filePath);
              },
              child: const Text('Share'),
            ),
          ],
        ),
      );

      _showSnackBar('PDF exported successfully!', isError: false);
    } catch (e) {
      _showSnackBar('Failed to export PDF: $e', isError: true);
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  void _showInsights() {
    final insights = SummaryService.generateInsights(filteredMemories);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildInsightsModal(insights),
    );
  }

  Widget _buildInsightsModal(Map<String, dynamic> insights) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Memory Insights',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInsightCard('Summary', [
                            'Total Memories: ${insights['totalMemories']}',
                            'Categories: ${(insights['categoryBreakdown'] as Map).length}',
                          ], Icons.summarize, colorScheme),
                          
                          const SizedBox(height: 16),
                          
                          _buildInsightCard('Top Keywords', 
                            (insights['topKeywords'] as List<String>).take(5).toList(),
                            Icons.tag, colorScheme),
                          
                          const SizedBox(height: 16),
                          
                          _buildInsightCard('Category Breakdown',
                            (insights['categoryBreakdown'] as Map<String, int>)
                                .entries.map((e) => '${e.key}: ${e.value}').toList(),
                            Icons.category, colorScheme),
                          
                          const SizedBox(height: 16),
                          
                          _buildInsightCard('Mood Analysis',
                            (insights['moodAnalysis'] as Map<String, int>)
                                .entries.map((e) => '${e.key.toUpperCase()}: ${e.value}').toList(),
                            Icons.mood, colorScheme),
                          
                          const SizedBox(height: 16),
                          
                          _buildInsightCard('Key Insights',
                            insights['insights'] as List<String>,
                            Icons.lightbulb, colorScheme),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String title, List<String> items, IconData icon, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $item', style: const TextStyle(fontSize: 13)),
            )).toList(),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('Copied to clipboard', isError: false);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError 
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showMemoryDetails(Memory memory) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.psychology,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Memory Details',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => _copyToClipboard(memory.text),
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copy text',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Category chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        memory.category,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Memory text
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            memory.text,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Timestamp
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDateTime(memory.timestamp),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return 'Today at ${_formatTime(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${_formatTime(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago at ${_formatTime(dateTime)}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${_formatTime(dateTime)}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour == 0 ? 12 : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _getMemoryPreview(String text, {int maxLength = 100}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categories = _getUniqueCategories();
    
    final screenTitle = selectedCategory != null 
        ? '${selectedCategory!.toUpperCase()} Memories'
        : 'Saved Memories';

    return Scaffold(
      appBar: AppBar(
        title: Text(screenTitle),
        actions: [
          // Insights button
          if (widget.memories.isNotEmpty)
            IconButton(
              onPressed: _showInsights,
              icon: const Icon(Icons.analytics),
              tooltip: 'View insights',
            ),
          
          // Export PDF button
          if (widget.memories.isNotEmpty)
            IconButton(
              onPressed: _isExporting ? null : _exportToPdf,
              icon: _isExporting 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf),
              tooltip: 'Export to PDF',
            ),
          
          // Filter menu
          if (widget.memories.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Filter by category',
              onSelected: _onCategoryChanged,
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: null,
                  child: Text('All Categories'),
                ),
                ...categories.map((category) => PopupMenuItem<String>(
                  value: category,
                  child: Text(category),
                )),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Enhanced search bar
          if (widget.memories.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search memories, categories, or keywords...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          icon: const Icon(Icons.clear),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                ),
              ),
            ),
          
          // Category filter chips
          if (categories.isNotEmpty)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('All'),
                        selected: selectedCategory == null,
                        onSelected: (selected) {
                          if (selected) _onCategoryChanged(null);
                        },
                      ),
                    );
                  }
                  
                  final category = categories[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category),
                      selected: selectedCategory == category,
                      onSelected: (selected) {
                        _onCategoryChanged(selected ? category : null);
                      },
                    ),
                  );
                },
              ),
            ),
          
          // Memories count and search results
          if (filteredMemories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${filteredMemories.length} ${filteredMemories.length == 1 ? 'memory' : 'memories'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (searchQuery.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'for "$searchQuery"',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          
          // Memories list
          Expanded(
            child: filteredMemories.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredMemories.length,
                    itemBuilder: (context, index) {
                      final memory = filteredMemories[index];
                      return _buildMemoryCard(context, memory, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    String message;
    IconData icon;
    
    if (widget.memories.isEmpty) {
      message = 'No memories saved yet\nStart by speaking to your assistant!';
      icon = Icons.psychology_outlined;
    } else if (searchQuery.isNotEmpty) {
      message = 'No memories found for "$searchQuery"\nTry a different search term';
      icon = Icons.search_off;
    } else if (selectedCategory != null) {
      message = 'No memories found in "$selectedCategory" category\nTry selecting a different category';
      icon = Icons.category_outlined;
    } else {
      message = 'No memories match your filters';
      icon = Icons.filter_list_off;
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: colorScheme.onSurfaceVariant.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCard(BuildContext context, Memory memory, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showMemoryDetails(memory),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with category and timestamp
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(memory.category, colorScheme),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      memory.category,
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDateTime(memory.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Memory text preview with search highlighting
              RichText(
                text: _buildHighlightedText(
                  _getMemoryPreview(memory.text),
                  searchQuery,
                  theme.textTheme.bodyMedium!,
                  colorScheme.primary,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Action buttons
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _showMemoryDetails(memory),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _copyToClipboard(memory.text),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  TextSpan _buildHighlightedText(String text, String query, TextStyle baseStyle, Color highlightColor) {
    if (query.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: baseStyle));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: baseStyle.copyWith(
          backgroundColor: highlightColor.withOpacity(0.3),
          fontWeight: FontWeight.bold,
        ),
      ));

      start = index + query.length;
    }

    return TextSpan(children: spans);
  }

  Color _getCategoryColor(String category, ColorScheme colorScheme) {
    // Generate consistent colors for categories
    final colors = [
      colorScheme.primaryContainer,
      colorScheme.secondaryContainer,
      colorScheme.tertiaryContainer,
      colorScheme.errorContainer,
    ];
    
    final hash = category.toLowerCase().hashCode;
    return colors[hash.abs() % colors.length];
  }
}

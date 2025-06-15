import '../models/memory.dart';

class SummaryService {
  static Map<String, dynamic> generateInsights(List<Memory> memories) {
    if (memories.isEmpty) {
      return {
        'totalMemories': 0,
        'topKeywords': <String>[],
        'categoryBreakdown': <String, int>{},
        'insights': <String>[],
      };
    }
    
    return {
      'totalMemories': memories.length,
      'topKeywords': _extractTopKeywords(memories),
      'categoryBreakdown': _getCategoryBreakdown(memories),
      'insights': _generateTextInsights(memories),
    };
  }
  
  static List<String> _extractTopKeywords(List<Memory> memories, {int limit = 10}) {
    final wordCount = <String, int>{};
    final stopWords = {
      'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
      'of', 'with', 'by', 'is', 'was', 'are', 'were', 'be', 'been', 'being',
      'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
      'should', 'may', 'might', 'must', 'can', 'i', 'you', 'he', 'she', 'it',
      'we', 'they', 'me', 'him', 'her', 'us', 'them', 'my', 'your', 'his',
      'her', 'its', 'our', 'their', 'this', 'that', 'these', 'those'
    };
    
    for (final memory in memories) {
      final words = memory.text.toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .split(' ')
          .where((word) => word.length > 2 && !stopWords.contains(word))
          .toList();
      
      for (final word in words) {
        wordCount[word] = (wordCount[word] ?? 0) + 1;
      }
    }
    
    final sortedWords = wordCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedWords.take(limit).map((e) => e.key).toList();
  }
  
  static Map<String, int> _getCategoryBreakdown(List<Memory> memories) {
    final categoryCount = <String, int>{};
    for (final memory in memories) {
      categoryCount[memory.category] = (categoryCount[memory.category] ?? 0) + 1;
    }
    return categoryCount;
  }
  
  static List<String> _generateTextInsights(List<Memory> memories) {
    final insights = <String>[];
    
    // Total memories insight
    insights.add('You have recorded ${memories.length} memories in total.');
    
    // Category insights
    final categoryBreakdown = _getCategoryBreakdown(memories);
    if (categoryBreakdown.isNotEmpty) {
      final mostUsedCategory = categoryBreakdown.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      insights.add('Most memories are in the ${mostUsedCategory.key} category (${mostUsedCategory.value} memories).');
    }
    
    // Recent activity insight
    final recentMemories = memories.where((m) => 
        DateTime.now().difference(m.timestamp).inDays < 7).length;
    insights.add('You\'ve added $recentMemories memories in the last week.');
    
    return insights;
  }
}

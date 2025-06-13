import '../models/memory.dart';

class SummaryService {
  static Map<String, dynamic> generateInsights(List<Memory> memories) {
    if (memories.isEmpty) {
      return {
        'totalMemories': 0,
        'topKeywords': <String>[],
        'categoryBreakdown': <String, int>{},
        'moodAnalysis': <String, int>{},
        'weeklyTrend': <String, int>{},
        'insights': <String>[],
      };
    }
    
    return {
      'totalMemories': memories.length,
      'topKeywords': _extractTopKeywords(memories),
      'categoryBreakdown': _getCategoryBreakdown(memories),
      'moodAnalysis': _analyzeMood(memories),
      'weeklyTrend': _getWeeklyTrend(memories),
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
  
  static Map<String, int> _analyzeMood(List<Memory> memories) {
    final moodKeywords = {
      'positive': ['happy', 'joy', 'excited', 'good', 'great', 'amazing', 'wonderful', 'love', 'success', 'achieved', 'accomplished', 'proud', 'grateful', 'blessed'],
      'negative': ['sad', 'angry', 'frustrated', 'bad', 'terrible', 'awful', 'hate', 'failed', 'disappointed', 'worried', 'stressed', 'anxious', 'upset'],
      'neutral': ['okay', 'fine', 'normal', 'usual', 'regular', 'routine', 'standard', 'typical']
    };
    
    final moodCount = {'positive': 0, 'negative': 0, 'neutral': 0};
    
    for (final memory in memories) {
      final text = memory.text.toLowerCase();
      var hasPositive = false;
      var hasNegative = false;
      
      for (final keyword in moodKeywords['positive']!) {
        if (text.contains(keyword)) {
          hasPositive = true;
          break;
        }
      }
      
      for (final keyword in moodKeywords['negative']!) {
        if (text.contains(keyword)) {
          hasNegative = true;
          break;
        }
      }
      
      if (hasPositive && !hasNegative) {
        moodCount['positive'] = moodCount['positive']! + 1;
      } else if (hasNegative && !hasPositive) {
        moodCount['negative'] = moodCount['negative']! + 1;
      } else {
        moodCount['neutral'] = moodCount['neutral']! + 1;
      }
    }
    
    return moodCount;
  }
  
  static Map<String, int> _getWeeklyTrend(List<Memory> memories) {
    final weeklyCount = <String, int>{};
    final now = DateTime.now();
    
    for (final memory in memories) {
      final daysDiff = now.difference(memory.timestamp).inDays;
      String period;
      
      if (daysDiff == 0) {
        period = 'Today';
      } else if (daysDiff == 1) {
        period = 'Yesterday';
      } else if (daysDiff <= 7) {
        period = 'This Week';
      } else if (daysDiff <= 14) {
        period = 'Last Week';
      } else if (daysDiff <= 30) {
        period = 'This Month';
      } else {
        period = 'Older';
      }
      
      weeklyCount[period] = (weeklyCount[period] ?? 0) + 1;
    }
    
    return weeklyCount;
  }
  
  static List<String> _generateTextInsights(List<Memory> memories) {
    final insights = <String>[];
    final categoryBreakdown = _getCategoryBreakdown(memories);
    final moodAnalysis = _analyzeMood(memories);
    final topKeywords = _extractTopKeywords(memories, limit: 5);
    
    // Most active category
    if (categoryBreakdown.isNotEmpty) {
      final topCategory = categoryBreakdown.entries.reduce((a, b) => a.value > b.value ? a : b);
      insights.add('Your most active category is "${topCategory.key}" with ${topCategory.value} memories.');
    }
    
    // Mood insight
    final totalMoods = moodAnalysis.values.reduce((a, b) => a + b);
    if (totalMoods > 0) {
      final dominantMood = moodAnalysis.entries.reduce((a, b) => a.value > b.value ? a : b);
      final percentage = ((dominantMood.value / totalMoods) * 100).round();
      insights.add('${percentage}% of your memories have a ${dominantMood.key} tone.');
    }
    
    // Keyword insight
    if (topKeywords.isNotEmpty) {
      insights.add('Your most frequently mentioned topics include: ${topKeywords.take(3).join(', ')}.');
    }
    
    // Activity insight
    final recentMemories = memories.where((m) => 
        DateTime.now().difference(m.timestamp).inDays <= 7).length;
    if (recentMemories > 0) {
      insights.add('You\'ve saved $recentMemories memories in the past week.');
    }
    
    // Diversity insight
    if (categoryBreakdown.length > 1) {
      insights.add('You\'re actively using ${categoryBreakdown.length} different categories to organize your memories.');
    }
    
    return insights;
  }
}

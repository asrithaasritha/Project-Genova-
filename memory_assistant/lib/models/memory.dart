class Memory {
  final String id;
  final String text;
  final String category;
  final DateTime timestamp;
  final int priority;
  final List<String> tags;

  Memory({
    String? id,
    required this.text,
    required this.category,
    required this.timestamp,
    this.priority = 3,
    List<String>? tags,
  }) : 
    id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    tags = tags ?? [];

  // Helper methods for better user experience
  String get formattedTimestamp {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String get preview {
    if (text.length <= 100) return text;
    return '${text.substring(0, 100)}...';
  }

  // Search functionality
  bool matches(String query) {
    final lowerQuery = query.toLowerCase();
    return text.toLowerCase().contains(lowerQuery) ||
           category.toLowerCase().contains(lowerQuery) ||
           tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
  }

  // Category helpers
  bool isInCategory(String categoryName) {
    return category.toLowerCase() == categoryName.toLowerCase();
  }

  // Priority helpers
  String get priorityLabel {
    switch (priority) {
      case 1:
        return 'Very Low';
      case 2:
        return 'Low';
      case 3:
        return 'Medium';
      case 4:
        return 'High';
      case 5:
        return 'Very High';
      default:
        return 'Medium';
    }
  }

  // Create copy with modifications
  Memory copyWith({
    String? id,
    String? text,
    DateTime? timestamp,
    String? category,
    List<String>? tags,
    int? priority,
  }) {
    return Memory(
      id: id ?? this.id,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      priority: priority ?? this.priority,
    );
  }

  // Serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'category': category,
      'timestamp': timestamp.toIso8601String(),
      'priority': priority,
      'tags': tags,
    };
  }

  factory Memory.fromJson(Map<String, dynamic> json) {
    return Memory(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      category: json['category'] ?? 'Personal',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      priority: json['priority'] ?? 3,
      tags: List<String>.from(json['tags'] ?? []),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Memory && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Memory(id: $id, text: ${text.length > 50 ? '${text.substring(0, 50)}...' : text}, category: $category)';
  }
}
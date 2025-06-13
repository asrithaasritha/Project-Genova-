class Memory {
  final String id;
  final String text;
  final DateTime timestamp;
  final String category;
  final List<String> tags;
  final int priority; // 1-5, where 5 is highest priority
  final bool isArchived;
  final DateTime? reminderTime;

  Memory({
    String? id,
    required this.text,
    required this.timestamp,
    required this.category,
    this.tags = const [],
    this.priority = 3,
    this.isArchived = false,
    this.reminderTime,
  }) : id = id ?? _generateId();

  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Helper methods for better user experience
  String get formattedTimestamp {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  String get preview {
    if (text.length <= 100) return text;
    return '${text.substring(0, 100)}...';
  }

  bool get hasReminder => reminderTime != null;

  bool get isReminderDue {
    if (reminderTime == null) return false;
    return DateTime.now().isAfter(reminderTime!);
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
    bool? isArchived,
    DateTime? reminderTime,
  }) {
    return Memory(
      id: id ?? this.id,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      priority: priority ?? this.priority,
      isArchived: isArchived ?? this.isArchived,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }

  // Serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'category': category,
      'tags': tags,
      'priority': priority,
      'isArchived': isArchived,
      'reminderTime': reminderTime?.toIso8601String(),
    };
  }

  factory Memory.fromJson(Map<String, dynamic> json) {
    return Memory(
      id: json['id'],
      text: json['text'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      category: json['category'] ?? 'General',
      tags: List<String>.from(json['tags'] ?? []),
      priority: json['priority'] ?? 3,
      isArchived: json['isArchived'] ?? false,
      reminderTime: json['reminderTime'] != null 
          ? DateTime.parse(json['reminderTime'])
          : null,
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
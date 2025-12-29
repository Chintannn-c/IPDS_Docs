class Item {
  final String id;
  final String name;
  final String description; // Original note text
  final String type;
  final bool isSummarized;
  final String? summaryParagraph;
  final List<String> bulletPoints;
  final List<String> keywords;
  final String? originalContent; // Original content before summarization

  Item({
    required this.id,
    required this.name,
    required this.description,
    this.type = 'text',
    this.isSummarized = false,
    this.summaryParagraph,
    this.bulletPoints = const [],
    this.keywords = const [],
    this.originalContent,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      type: json['type'] ?? 'text',
      isSummarized: json['is_summarized'] ?? false,
      summaryParagraph: json['summary_paragraph'],
      bulletPoints: json['bullet_points'] != null
          ? List<String>.from(json['bullet_points'])
          : [],
      keywords: json['keywords'] != null
          ? List<String>.from(json['keywords'])
          : [],
      originalContent: json['original_content'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type,
      'is_summarized': isSummarized,
      if (summaryParagraph != null) 'summary_paragraph': summaryParagraph,
      'bullet_points': bulletPoints,
      'keywords': keywords,
      if (originalContent != null) 'original_content': originalContent,
    };
  }
}

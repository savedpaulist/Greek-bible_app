// lib/features/notes/data/note_model.dart

class NoteModel {
  final String id;
  final String title;
  final String content; // Markdown
  final String? templateId;
  final String? folderId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NoteModel({
    required this.id,
    required this.title,
    required this.content,
    this.templateId,
    this.folderId,
    required this.createdAt,
    required this.updatedAt,
  });

  NoteModel copyWith({
    String? title,
    String? content,
    String? templateId,
    String? folderId,
    DateTime? updatedAt,
  }) => NoteModel(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    templateId: templateId ?? this.templateId,
    folderId: folderId ?? this.folderId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'content': content,
    'template_id': templateId,
    'folder_id': folderId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory NoteModel.fromMap(Map<String, dynamic> m) => NoteModel(
    id: m['id'] as String,
    title: m['title'] as String? ?? '',
    content: m['content'] as String? ?? '',
    templateId: m['template_id'] as String?,
    folderId: m['folder_id'] as String?,
    createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse(m['updated_at'] as String? ?? '') ?? DateTime.now(),
  );
}

class NoteTemplate {
  final String id;
  final String name;
  final String content; // Markdown template

  const NoteTemplate({
    required this.id,
    required this.name,
    required this.content,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'content': content,
  };

  factory NoteTemplate.fromMap(Map<String, dynamic> m) => NoteTemplate(
    id: m['id'] as String,
    name: m['name'] as String? ?? '',
    content: m['content'] as String? ?? '',
  );
}

/// A user-created tag for organizing notes
class NoteTag {
  final String id;
  final String name;
  final int colorValue; // ARGB color

  const NoteTag({
    required this.id,
    required this.name,
    this.colorValue = 0xFF2196F3, // default blue
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'color_value': colorValue,
  };

  factory NoteTag.fromMap(Map<String, dynamic> m) => NoteTag(
    id: m['id'] as String,
    name: m['name'] as String? ?? '',
    colorValue: m['color_value'] as int? ?? 0xFF2196F3,
  );
}

/// A tag applied to a specific verse
class VerseTag {
  final String id;
  final String tagId;
  final int bookNumber;
  final int chapter;
  final int verse;
  final DateTime createdAt;

  const VerseTag({
    required this.id,
    required this.tagId,
    required this.bookNumber,
    required this.chapter,
    required this.verse,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'tag_id': tagId,
    'book_number': bookNumber,
    'chapter': chapter,
    'verse': verse,
    'created_at': createdAt.toIso8601String(),
  };

  factory VerseTag.fromMap(Map<String, dynamic> m) => VerseTag(
    id: m['id'] as String,
    tagId: m['tag_id'] as String,
    bookNumber: m['book_number'] as int,
    chapter: m['chapter'] as int,
    verse: m['verse'] as int,
    createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
  );
}

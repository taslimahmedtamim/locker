import 'dart:convert';

import 'vault_entry.dart';

/// Database model representing all entries inside the vault.
class VaultDatabase {
  final int version;
  final DateTime updatedAt;
  final List<VaultEntry> entries;

  const VaultDatabase({
    this.version = 1,
    required this.updatedAt,
    this.entries = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'updatedAt': updatedAt.toIso8601String(),
      'entries': entries.map((e) => e.toJson()).toList(),
    };
  }

  factory VaultDatabase.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List<dynamic>? ?? [];
    final entries = rawEntries
        .map((e) => VaultEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    return VaultDatabase(
      version: json['version'] as int? ?? 1,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      entries: entries,
    );
  }

  String serialize() => jsonEncode(toJson());

  factory VaultDatabase.deserialize(String jsonString) {
    return VaultDatabase.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }
}

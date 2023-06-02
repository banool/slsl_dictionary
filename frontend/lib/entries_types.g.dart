// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entries_types.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MyEntry _$MyEntryFromJson(Map<String, dynamic> json) => MyEntry(
      word_in_english: json['word_in_english'] as String,
      word_in_tamil: json['word_in_tamil'] as String?,
      word_in_sinhala: json['word_in_sinhala'] as String?,
      category: json['category'] as String?,
      entry_type: json['entry_type'] as String,
      sub_entries: (json['sub_entries'] as List<dynamic>)
          .map((e) => MySubEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$MyEntryToJson(MyEntry instance) => <String, dynamic>{
      'word_in_english': instance.word_in_english,
      'word_in_tamil': instance.word_in_tamil,
      'word_in_sinhala': instance.word_in_sinhala,
      'category': instance.category,
      'entry_type': instance.entry_type,
      'sub_entries': instance.sub_entries,
    };

MySubEntry _$MySubEntryFromJson(Map<String, dynamic> json) => MySubEntry(
      videos:
          (json['videos'] as List<dynamic>).map((e) => e as String).toList(),
      definitions: (json['definitions'] as List<dynamic>?)
          ?.map((e) => Definition.fromJson(e as Map<String, dynamic>))
          .toList(),
      region: json['region'] as String,
      related_words: json['related_words'] as String?,
    );

Map<String, dynamic> _$MySubEntryToJson(MySubEntry instance) =>
    <String, dynamic>{
      'videos': instance.videos,
      'definitions': instance.definitions,
      'region': instance.region,
      'related_words': instance.related_words,
    };

Definition _$DefinitionFromJson(Map<String, dynamic> json) => Definition(
      language: json['language'] as String,
      category: json['category'] as String,
      definition: json['definition'] as String,
    );

Map<String, dynamic> _$DefinitionToJson(Definition instance) =>
    <String, dynamic>{
      'language': instance.language,
      'category': instance.category,
      'definition': instance.definition,
    };

import 'package:flutter/material.dart';

/// Information about the loaded score.
class MusicXmlScoreInfo {
  final String title;
  final String composer;
  final String subtitle;
  final int partCount;
  final int measureCount;
  final int pageCount;

  final int lastFittingMeasure;
  final int totalMeasureCount;

  const MusicXmlScoreInfo({
    this.title = '',
    this.composer = '',
    this.subtitle = '',
    this.partCount = 0,
    this.measureCount = 0,
    this.pageCount = 0,
    this.lastFittingMeasure = -1,
    this.totalMeasureCount = 0,
  });

  factory MusicXmlScoreInfo.fromJson(Map<String, dynamic> json) {
    return MusicXmlScoreInfo(
      title: json['title'] as String? ?? '',
      composer: json['composer'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      partCount: json['partCount'] as int? ?? 0,
      measureCount: json['measureCount'] as int? ?? 0,
      pageCount: json['pageCount'] as int? ?? 0,
      lastFittingMeasure: json['lastFittingMeasure'] as int? ?? -1,
      totalMeasureCount: json['totalMeasureCount'] as int? ?? 0,
    );
  }
}

/// Configuration options for the MusicXML renderer.
class MusicXmlRenderOptions {
  /// Whether to draw the title.
  final bool drawTitle;

  /// Whether to draw the composer name.
  final bool drawComposer;

  /// Whether to draw measure numbers.
  final bool drawMeasureNumbers;

  /// Whether to draw time signatures.
  final bool drawTimeSignatures;

  /// Whether to draw part names.
  final bool drawPartNames;

  /// Zoom level (1.0 = 100%).
  final double zoom;

  /// Initial page to show (1-indexed).
  final int? initialPage;

  /// Current page to show (1-indexed).
  final int? currentPage;

  const MusicXmlRenderOptions({
    this.drawTitle = true,
    this.drawComposer = true,
    this.drawMeasureNumbers = true,
    this.drawTimeSignatures = true,
    this.drawPartNames = true,
    this.zoom = 1.0,
    this.initialPage,
    this.currentPage,
  });

  Map<String, dynamic> toJson() {
    return {
      'drawTitle': drawTitle,
      'drawComposer': drawComposer,
      'drawMeasureNumbers': drawMeasureNumbers,
      'drawTimeSignatures': drawTimeSignatures,
      'drawPartNames': drawPartNames,
      'zoom': zoom,
      if (initialPage != null) 'initialPage': initialPage,
      if (currentPage != null) 'currentPage': currentPage,
    };
  }
}

/// Callback types for renderer events.
typedef OnScoreLoaded = void Function(MusicXmlScoreInfo info);
typedef OnError = void Function(String message, String type);
typedef OnReady = void Function();

import 'package:flutter/material.dart';
import 'package:music_xml/music_xml.dart';

/// Legacy widget that renders MusicXML content as sheet music using CustomPaint.
///
/// **Note:** This renderer provides basic notation rendering but has limitations.
/// For production use, prefer [MusicXmlWebRenderer] which uses OpenSheetMusicDisplay
/// for professional-quality engraving.
///
/// This renderer is kept as a fallback for platforms where WebView is unavailable
/// (e.g., Flutter Web) or for cases where a lightweight, offline renderer is needed.
class MusicXmlRenderer extends StatelessWidget {
  /// The parsed MusicXML document.
  final MusicXmlDocument document;

  /// Background color for the sheet.
  final Color backgroundColor;

  /// Color for the staff lines and notes.
  final Color foregroundColor;

  const MusicXmlRenderer({
    super.key,
    required this.document,
    this.backgroundColor = Colors.white,
    this.foregroundColor = Colors.black,
  });

  /// Parse MusicXML from a string, with basic sanitization for unsupported features.
  static MusicXmlDocument parse(String xmlContent) {
    try {
      return MusicXmlDocument.parse(xmlContent);
    } catch (e) {
      if (e.toString().contains('Unpitched')) {
        debugPrint('Sanitizing MusicXML to remove unsupported unpitched notes...');
        // Remove all <unpitched> tags and their contents to allow parsing of the rest
        final sanitized = xmlContent.replaceAll(
          RegExp(r'<unpitched>.*?</unpitched>', dotAll: true),
          '',
        );
        return MusicXmlDocument.parse(sanitized);
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: CustomPaint(
        painter: _MusicXmlPainter(
          document: document,
          foregroundColor: foregroundColor,
        ),
        size: Size.infinite,
      ),
    );
  }
}

/// Custom painter that renders MusicXML as sheet music.
class _MusicXmlPainter extends CustomPainter {
  final MusicXmlDocument document;
  final Color foregroundColor;

  // Layout constants
  static const double staffLineSpacing = 10.0;
  static const double staffHeight = staffLineSpacing * 4;
  static const double staffMarginTop = 80.0;
  static const double staffMarginLeft = 60.0;
  static const double staffMarginRight = 40.0;
  static const double staffSpacing = 100.0;
  static const double measureMinWidth = 150.0;
  static const double noteSpacing = 40.0;

  _MusicXmlPainter({required this.document, required this.foregroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = foregroundColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.fill;

    double currentY = staffMarginTop;
    final staffWidth = size.width - staffMarginLeft - staffMarginRight;

    // Draw title if available
    final title = _getTitle();
    if (title != null) {
      _drawTitle(canvas, title, size.width / 2, 30);
    }

    // Process each part
    for (final part in document.parts) {
      // Draw staff lines
      _drawStaffLines(canvas, staffMarginLeft, currentY, staffWidth, paint);

      // Draw clef
      _drawClef(canvas, staffMarginLeft + 10, currentY, fillPaint);

      // Draw time signature if available
      final timeSignature = _getTimeSignature(part);
      if (timeSignature != null) {
        _drawTimeSignature(
          canvas,
          staffMarginLeft + 45,
          currentY,
          timeSignature.$1,
          timeSignature.$2,
          fillPaint,
        );
      }

      // Draw measures and notes
      double measureX = staffMarginLeft + 80;
      for (final measure in part.measures) {
        final measureWidth = _calculateMeasureWidth(measure, staffWidth - 80);
        _drawMeasure(
          canvas,
          measure,
          measureX,
          currentY,
          measureWidth,
          paint,
          fillPaint,
        );
        measureX += measureWidth;

        // Wrap to next line if needed
        if (measureX > size.width - staffMarginRight - measureMinWidth) {
          currentY += staffSpacing;
          if (currentY < size.height - staffHeight) {
            _drawStaffLines(
              canvas,
              staffMarginLeft,
              currentY,
              staffWidth,
              paint,
            );
          }
          measureX = staffMarginLeft + 20;
        }
      }

      currentY += staffSpacing;
    }
  }

  String? _getTitle() {
    // Try to extract title from the document
    // The music_xml package may have this in different places
    return null; // Placeholder - would need to check document structure
  }

  (int, int)? _getTimeSignature(Part part) {
    // Look for time signature in the first measure
    // The music_xml package doesn't expose time signature directly in this API
    // Default to 4/4 - a more complete implementation would parse the XML directly
    if (part.measures.isEmpty) return null;
    return (4, 4); // Default to 4/4
  }

  double _calculateMeasureWidth(Measure measure, double maxWidth) {
    final noteCount = measure.notes.length;
    final width = (noteCount * noteSpacing).clamp(
      measureMinWidth,
      maxWidth / 2,
    );
    return width;
  }

  void _drawStaffLines(
    Canvas canvas,
    double x,
    double y,
    double width,
    Paint paint,
  ) {
    for (int i = 0; i < 5; i++) {
      final lineY = y + (i * staffLineSpacing);
      canvas.drawLine(Offset(x, lineY), Offset(x + width, lineY), paint);
    }
  }

  void _drawClef(Canvas canvas, double x, double y, Paint paint) {
    // Draw a simplified treble clef
    final textPainter = TextPainter(
      text: TextSpan(
        text: '𝄞',
        style: TextStyle(fontSize: 60, color: paint.color, fontFamily: 'serif'),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x, y - 20));
  }

  void _drawTimeSignature(
    Canvas canvas,
    double x,
    double y,
    int beats,
    int beatType,
    Paint paint,
  ) {
    final topPainter = TextPainter(
      text: TextSpan(
        text: beats.toString(),
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: paint.color,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    topPainter.layout();
    topPainter.paint(canvas, Offset(x, y - 2));

    final bottomPainter = TextPainter(
      text: TextSpan(
        text: beatType.toString(),
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: paint.color,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    bottomPainter.layout();
    bottomPainter.paint(canvas, Offset(x, y + staffLineSpacing * 2 - 2));
  }

  void _drawMeasure(
    Canvas canvas,
    Measure measure,
    double x,
    double y,
    double width,
    Paint strokePaint,
    Paint fillPaint,
  ) {
    // Draw bar line at end of measure
    canvas.drawLine(
      Offset(x + width, y),
      Offset(x + width, y + staffHeight),
      strokePaint,
    );

    // Draw notes
    double noteX = x + 20;
    final noteWidth = (width - 40) / (measure.notes.length.clamp(1, 100));

    for (final note in measure.notes) {
      try {
        if (!note.isRest) {
          _drawNote(canvas, note, noteX, y, fillPaint, strokePaint);
        } else {
          _drawRest(canvas, note, noteX, y, fillPaint);
        }
      } catch (e) {
        // Skip notes that cause errors (e.g., unpitched notes)
        debugPrint('Skipping note: $e');
      }
      noteX += noteWidth.clamp(noteSpacing / 2, noteSpacing * 2);
    }
  }

  void _drawNote(
    Canvas canvas,
    Note note,
    double x,
    double y,
    Paint fillPaint,
    Paint strokePaint,
  ) {
    // Calculate vertical position based on pitch
    final noteY = _getNoteY(note, y);

    // Draw ledger lines if needed
    _drawLedgerLines(canvas, x, y, noteY, strokePaint);

    // Determine if note head should be filled (quarter note or shorter)
    final isFilled = _isFilledNoteHead(note);

    // Draw note head (oval)
    final noteHeadRect = Rect.fromCenter(
      center: Offset(x, noteY),
      width: 12,
      height: 9,
    );

    canvas.save();
    canvas.translate(x, noteY);
    canvas.rotate(-0.3); // Slight rotation for note head
    canvas.translate(-x, -noteY);

    if (isFilled) {
      canvas.drawOval(noteHeadRect, fillPaint);
    } else {
      final hollowPaint = Paint()
        ..color = fillPaint.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawOval(noteHeadRect, hollowPaint);
    }

    canvas.restore();

    // Draw stem (except for whole notes)
    if (!_isWholeNote(note)) {
      final stemUp = noteY > y + staffHeight / 2;
      final stemX = stemUp ? x + 6 : x - 6;
      final stemStartY = noteY;
      final stemEndY = stemUp ? noteY - 35 : noteY + 35;

      canvas.drawLine(
        Offset(stemX, stemStartY),
        Offset(stemX, stemEndY),
        strokePaint,
      );

      // Draw flag for eighth notes and shorter
      if (_hasFlag(note)) {
        _drawFlag(canvas, stemX, stemEndY, stemUp, fillPaint);
      }
    }
  }

  double _getNoteY(Note note, double staffY) {
    // Map pitch to staff position
    // Middle line (B4 in treble clef) is at staffY + staffHeight/2
    final pitch = note.pitch;
    if (pitch == null) return staffY + staffHeight / 2;

    // pitch is MapEntry<String, int> where key is step (e.g., "C") and value is octave
    final step = pitch.key.toUpperCase();
    final octave = pitch.value;

    // Base positions for notes on the staff (treble clef)
    // E4 = bottom line, F4 = bottom space, G4 = second line, etc.
    const stepOffsets = {
      'C': 0,
      'D': 1,
      'E': 2,
      'F': 3,
      'G': 4,
      'A': 5,
      'B': 6,
    };

    final stepOffset = stepOffsets[step] ?? 0;
    // E4 is on the bottom line of treble clef
    // Each step moves half a staff line spacing
    final basePosition = (octave - 4) * 7 + stepOffset;
    // E4 = 2 (bottom line), so offset from there
    final positionFromE4 = basePosition - 2;

    // Each position is half a staff line spacing
    final yOffset = -positionFromE4 * (staffLineSpacing / 2);

    return staffY + staffHeight - yOffset;
  }

  void _drawLedgerLines(
    Canvas canvas,
    double x,
    double y,
    double noteY,
    Paint paint,
  ) {
    // Draw ledger lines above staff
    double ledgerY = y - staffLineSpacing;
    while (ledgerY >= noteY - staffLineSpacing / 2) {
      canvas.drawLine(Offset(x - 10, ledgerY), Offset(x + 10, ledgerY), paint);
      ledgerY -= staffLineSpacing;
    }

    // Draw ledger lines below staff
    ledgerY = y + staffHeight + staffLineSpacing;
    while (ledgerY <= noteY + staffLineSpacing / 2) {
      canvas.drawLine(Offset(x - 10, ledgerY), Offset(x + 10, ledgerY), paint);
      ledgerY += staffLineSpacing;
    }
  }

  bool _isFilledNoteHead(Note note) {
    // Quarter notes (1/4) and shorter have filled heads
    final type = note.noteDuration.type.toLowerCase();
    return type == 'quarter' ||
        type == 'eighth' ||
        type == '16th' ||
        type == '32nd';
  }

  bool _isWholeNote(Note note) {
    final type = note.noteDuration.type.toLowerCase();
    return type == 'whole';
  }

  bool _hasFlag(Note note) {
    final type = note.noteDuration.type.toLowerCase();
    return type == 'eighth' || type == '16th' || type == '32nd';
  }

  void _drawFlag(Canvas canvas, double x, double y, bool stemUp, Paint paint) {
    final path = Path();
    if (stemUp) {
      path.moveTo(x, y);
      path.quadraticBezierTo(x + 15, y + 10, x + 8, y + 25);
    } else {
      path.moveTo(x, y);
      path.quadraticBezierTo(x - 15, y - 10, x - 8, y - 25);
    }
    canvas.drawPath(path, paint);
  }

  void _drawRest(Canvas canvas, Note note, double x, double y, Paint paint) {
    final type = note.noteDuration.type.toLowerCase();
    final centerY = y + staffHeight / 2;

    switch (type) {
      case 'whole':
        // Whole rest - rectangle hanging from line
        canvas.drawRect(
          Rect.fromLTWH(x - 6, y + staffLineSpacing - 4, 12, 6),
          paint,
        );
        break;
      case 'half':
        // Half rest - rectangle sitting on line
        canvas.drawRect(
          Rect.fromLTWH(x - 6, y + staffLineSpacing * 2, 12, 6),
          paint,
        );
        break;
      case 'quarter':
        // Quarter rest - simplified squiggle
        final textPainter = TextPainter(
          text: TextSpan(
            text: '𝄽',
            style: TextStyle(fontSize: 32, color: paint.color),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - 6, centerY - 16));
        break;
      default:
        // Eighth rest and shorter - simplified
        final textPainter = TextPainter(
          text: TextSpan(
            text: '𝄾',
            style: TextStyle(fontSize: 24, color: paint.color),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - 6, centerY - 12));
    }
  }

  void _drawTitle(Canvas canvas, String title, double x, double y) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: foregroundColor,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x - textPainter.width / 2, y));
  }

  @override
  bool shouldRepaint(covariant _MusicXmlPainter oldDelegate) {
    return oldDelegate.document != document ||
        oldDelegate.foregroundColor != foregroundColor;
  }
}

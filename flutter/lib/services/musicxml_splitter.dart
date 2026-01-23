import 'package:xml/xml.dart';

/// A service that can split a MusicXML document into smaller docs containing
/// only a specific range of measures.
class MusicXmlSplitter {
  /// Splits the [originalXml] into a new MusicXML string containing only measures
  /// from [startMeasureIndex] to [endMeasureIndex] (inclusive, 0-indexed).
  static String split(String originalXml, int startMeasureIndex, int endMeasureIndex) {
    if (originalXml.isEmpty) return '';

    final document = XmlDocument.parse(originalXml);
    final root = document.rootElement;

    // Create a new document by cloning the root but clearing parts
    final newRoot = root.copy();
    
    // Find all <part> elements in the new root
    final parts = newRoot.findElements('part').toList();
    
    for (final part in parts) {
      // Find all measures in this part
      final allMeasures = part.findElements('measure').toList();
      
      // Clear all measures from the part
      // We use a safe way to remove children while iterating
      final childrenToRemove = part.children.where((node) => node is XmlElement && node.name.local == 'measure').toList();
      for (final child in childrenToRemove) {
        child.remove();
      }
      
      // Add back only the measures in range
      for (int i = 0; i < allMeasures.length; i++) {
        if (i >= startMeasureIndex && i <= endMeasureIndex) {
          // Important: We need a copy because the measure might still have parent/etc info
          // or be used elsewhere. Actually, allMeasures are from the old part.
          part.children.add(allMeasures[i].copy());
        }
      }
    }
    
    // Create a new document with the modified root and preserve the XML declaration
    final newDocument = XmlDocument([
      XmlDeclaration([
        XmlAttribute(XmlName('version'), '1.0'),
        XmlAttribute(XmlName('encoding'), 'UTF-8'),
      ]),
      newRoot,
    ]);
    
    return newDocument.toXmlString(pretty: true);
  }

  /// Extracts the measure count from the MusicXML document.
  static int getMeasureCount(String xml) {
    try {
      final document = XmlDocument.parse(xml);
      // Assume the first part has the correct number of measures
      final firstPart = document.rootElement.findElements('part').firstOrNull;
      if (firstPart == null) return 0;
      return firstPart.findElements('measure').length;
    } catch (_) {
      return 0;
    }
  }
}

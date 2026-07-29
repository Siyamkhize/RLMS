import 'package:flutter/material.dart';
import 'ArplToolkitViewerPage.dart';

/// Router widget for ARPL Toolkit Assessment Forms
/// Routes to toolkit viewer page for ALL trades
///
/// OFO Mappings:
/// - 671101 → Electrician (uses ArplToolkitViewerPage)
/// - 642601 → Plumber (uses ArplToolkitViewerPage)
/// - 641201 → Bricklayer (uses ArplToolkitViewerPage)

class ArplToolkitRouter extends StatelessWidget {
  final int learnerID;
  final int classID;
  final String ofoNumber;

  const ArplToolkitRouter({
    Key? key,
    required this.learnerID,
    required this.classID,
    required this.ofoNumber,
  }) : super(key: key);

  /// Get trade name from OFO number
  String _getTradeName(String ofoNumber) {
    switch (ofoNumber) {
      case '671101':
        return 'Electrician';
      case '642601':
        return 'Plumber';
      case '641201':
        return 'Bricklayer';
      default:
        return 'Unknown Trade';
    }
  }

  @override
  Widget build(BuildContext context) {
    // All trades use the viewer page with working UI
    return ArplToolkitViewerPage(
      learnerID: learnerID,
      classID: classID,
      ofoNumber: ofoNumber,
    );
  }
}

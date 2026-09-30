import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A API limita pontos de código Unicode. Preserva cada grafema ao truncar.
class CommunityLengthFormatter extends TextInputFormatter {
  const CommunityLengthFormatter(this.maxLength);

  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    if (newValue.text.runes.length <= maxLength) return newValue;
    final buffer = StringBuffer();
    var count = 0;
    for (final grapheme in newValue.text.characters) {
      final length = grapheme.runes.length;
      if (count + length > maxLength) break;
      buffer.write(grapheme);
      count += length;
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: newValue.selection.isValid
          ? TextSelection(
              baseOffset: newValue.selection.baseOffset.clamp(0, text.length),
              extentOffset:
                  newValue.selection.extentOffset.clamp(0, text.length),
            )
          : TextSelection.collapsed(offset: text.length),
    );
  }
}

import 'package:flutter/services.dart';

class CursoInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length < oldValue.text.length) {
      if (oldValue.text.endsWith('/')) {
        final String t = newValue.text.substring(0, newValue.text.length - 1);
        return TextEditingValue(
          text: t,
          selection: TextSelection.collapsed(offset: t.length),
        );
      }
      return newValue;
    }

    if (newValue.text.length == 2) {
      final String t = '${newValue.text}/';
      return TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      );
    }

    if (newValue.text.length > 5) {
      return oldValue;
    }

    return newValue;
  }
}
import 'dart:typed_data';

Future<void> saveFileImpl(String name, Uint8List bytes, String mime) async {
  throw UnsupportedError('File download is only supported on the web build.');
}

Future<String> extractPdfTextImpl(Uint8List bytes) async {
  throw UnsupportedError('PDF extraction is only supported on the web build.');
}

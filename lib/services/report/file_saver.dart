import 'dart:typed_data';

import 'file_saver_stub.dart'
    if (dart.library.js_interop) 'file_saver_web.dart' as impl;

const String pptxMime =
    'application/vnd.openxmlformats-officedocument.presentationml.presentation';
const String docxMime =
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

/// Triggers a browser download of [bytes] as [name].
Future<void> saveFile(String name, Uint8List bytes, String mime) =>
    impl.saveFileImpl(name, bytes, mime);

/// Extracts the text layer of a PDF using the bundled pdf.js helper.
/// Image-only pages yield no text.
Future<String> extractPdfText(Uint8List bytes) =>
    impl.extractPdfTextImpl(bytes);

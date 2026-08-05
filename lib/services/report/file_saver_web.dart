import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Browser download via Blob + anchor click.
Future<void> saveFileImpl(String name, Uint8List bytes, String mime) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mime),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = name;
  anchor.style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

@JS('extractPdfText')
external JSPromise<JSString> _extractPdfText(JSUint8Array bytes);

@JS('extractPdfText')
external JSAny? get _extractPdfTextRef;

/// PDF text extraction via the locally-bundled pdf.js (web/pdfjs).
Future<String> extractPdfTextImpl(Uint8List bytes) async {
  if (_extractPdfTextRef == null) {
    throw UnsupportedError(
        'PDF extraction unavailable: pdf.js helper not loaded.');
  }
  final result = await _extractPdfText(bytes.toJS).toDart;
  return result.toDart;
}

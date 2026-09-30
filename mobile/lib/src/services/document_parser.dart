import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Best-effort text extraction for PDF / DOCX / TXT on-device.
Future<String> extractDocumentText(File file) async {
  final ext = file.path.split('.').last.toLowerCase();
  if (ext == 'txt') {
    return file.readAsString();
  }
  if (ext == 'pdf') {
    final bytes = await file.readAsBytes();
    final doc = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(doc);
    final text = extractor.extractText();
    doc.dispose();
    return text.trim();
  }
  if (ext == 'docx') {
    return _readDocxPlainText(file);
  }
  throw UnsupportedError('Unsupported type: .$ext');
}

String _readDocxPlainText(File file) {
  final raw = file.readAsBytesSync();
  final arch = ZipDecoder().decodeBytes(raw);
  ArchiveFile? docXml;
  for (final f in arch.files) {
    if (f.name == 'word/document.xml') {
      docXml = f;
      break;
    }
  }
  if (docXml == null) return '';
  final xml = utf8.decode(docXml.content as List<int>);
  return xml.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

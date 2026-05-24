import 'dart:html' as html;
import 'dart:convert';

/// Web-specific file download implementation
/// This file is conditionally imported only on web platform
void downloadFile(String content, String filename) {
  // Create a blob from the content
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes]);
  
  // Create a download link
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  
  // Clean up
  html.Url.revokeObjectUrl(url);
}

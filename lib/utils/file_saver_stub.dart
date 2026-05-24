/// Stub implementation for non-web platforms
/// This file is used when not running on web
/// The actual implementation for mobile uses share_plus directly in the screen
void downloadFile(String content, String filename) {
  // This should never be called on mobile
  // Mobile uses share_plus dialog directly
  throw UnsupportedError('File download via this method is not supported on this platform');
}

/// Display metadata — keep in sync with pubspec version.
class AppMeta {
  static const name = 'Personal Life OS';
  static const version = '0.18.0';
  static const build = 22;
  static const tagline = 'Offline · local-first · your life in one place';

  static String get versionLabel => '$version+$build';
}

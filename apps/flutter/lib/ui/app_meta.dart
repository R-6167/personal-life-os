/// Display metadata — keep in sync with pubspec version.
class AppMeta {
  static const name = 'Personal Life OS';
  static const version = '0.17.0';
  static const build = 21;
  static const tagline = 'Offline · local-first · your life in one place';

  static String get versionLabel => '$version+$build';
}

/// Where the app reads its data. Override for a test site:
/// flutter run --dart-define=BASE_URL=http://127.0.0.1:8088
const String kBaseUrl = String.fromEnvironment('BASE_URL', defaultValue: 'https://leylotyavan.co.il');

/// Force the TV layout (for checking it on a phone or in the browser).
const bool kForceTv = bool.fromEnvironment('FORCE_TV');

/// Build number of this version, compared with minBuild from the site.
const int kBuild = int.fromEnvironment('BUILD_NUMBER', defaultValue: 18);

/// The REST route through ?rest_route=, which works with every permalink setting.
Uri apiUri(String route, [Map<String, String> query = const {}]) {
  final base = Uri.parse(kBaseUrl);
  return base.replace(
    path: base.path.isEmpty ? '/' : base.path,
    queryParameters: {'rest_route': route, ...query},
  );
}

const kPlayStoreUrl = 'https://play.google.com/store/apps/details?id=com.chagil.kahol_yavan_radio_app';
const kAppStoreUrl = 'https://apps.apple.com/app/id1585558940';

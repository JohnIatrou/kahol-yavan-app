# רדיו כחול יוון – האפליקציה

Flutter app for Radio Kahol Yavan (leylotyavan.co.il): phones, Android TV / Google TV, and iPhone.
It replaces the existing store apps (Google Play `com.chagil.kahol_yavan_radio_app`, App Store id1585558940).

- Data: the Leylot Modern WordPress plugin (1.10.0+, `includes/app.php`): `/lym/v1/app/*`, `/lym/v1/studio`, `/lym/v1/chat/*`.
- Phone: live stream + radio board, show archive, updates, contact / night chat / notification settings.
- TV: detected by the `android.software.leanback` feature; rows navigated with the remote.
- Notifications: Firebase Cloud Messaging topics `episodes`, `shows`, `news`, sent from WordPress
  (Settings → אפליקציית הרדיו).

```
flutter test
flutter run --dart-define=BASE_URL=https://leylotyavan.co.il      # FORCE_TV=true for the TV layout
```

Builds and Google Play uploads: `.github/workflows/android.yml` (secrets listed at the top of the file).

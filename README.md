# Smart Grocery Assistant (Tamil)

Personal, offline, Tamil-first grocery price comparison app for Android.

## How it works

1. **Record** — pick a store (Zepto / Blinkit / Swiggy Instamart / BigBasket), tap
   "பதிவைத் தொடங்கு" (start recording), then switch to that store's app yourself
   and browse/search normally, logged in with your own account as usual.
   Come back and tap "பதிவை நிறுத்து" (stop) when done.
2. **OCR extraction** — the app samples frames from that local recording and runs
   on-device OCR (Google ML Kit, no network call) to guess product name, quantity,
   and price for each item visible.
3. **Review** — you confirm, edit, or discard each guessed item before anything is
   saved. Nothing is written to the database until you tap "அனைத்தையும் சேமி".
4. **Compare** — search a product on the home screen to see every store's saved
   price side by side, cheapest highlighted.

## What this app deliberately does NOT do

- No login automation, no stored credentials, no API calls to Zepto/Blinkit/
  Instamart/BigBasket. You always log into those apps yourself, manually.
- No `INTERNET` permission is declared in the manifest — everything is on-device.
- Raw screen recordings are deleted immediately after OCR extraction; only the
  confirmed price entries you approve on the Review screen persist.
- No auto-add-to-cart — the app only suggests the cheapest store; you add items
  in the store's own app yourself.

## Build (via GitHub Actions, since this is developed from a phone)

This project has no CI workflow file yet. A minimal one:

```yaml
# .github/workflows/build.yml
name: Build APK
on: [workflow_dispatch, push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
      - run: flutter pub get
      - run: flutter build apk --release
      - uses: actions/upload-artifact@v4
        with:
          name: smart-grocery-apk
          path: build/app/outputs/flutter-apk/app-release.apk
```

Push this repo to GitHub, add the workflow file, trigger it manually (or on push),
and download the APK artifact from the Actions run — same pattern as your finance
tracker app.

## Known rough edges (v0.1 scaffold)

- OCR accuracy on scrolling video is noisy — the Review screen exists specifically
  because you'll need to correct names/prices fairly often, especially where store
  UIs mix Tamil and English or use stylized fonts.
- `product_name_en` is currently whatever you type in Review — for comparison to
  work well, use the **same English name** across stores for the same product
  (e.g. always "Tomato 1kg", not sometimes "Tomatoes").
- Notifications (offer expiry, price-drop alerts) and the Offers tab from the
  original spec aren't wired up yet in this scaffold — the core record → OCR →
  review → compare loop is built first since it's the foundation everything else
  depends on.
- `flutter_screen_recording`'s native service name may differ slightly by plugin
  version — check the plugin's own AndroidManifest snippet after `flutter pub get`
  and adjust the `<service>` entry in `android/app/src/main/AndroidManifest.xml`
  if the build fails on that line.

## Next steps I'd suggest

1. Get this building and confirm the record → OCR → review loop works end to end
   on your device for one store first (Zepto).
2. Tune the OCR regex patterns in `lib/data/services/ocr_service.dart` against
   real recordings — store UIs vary a lot in how price/quantity text is laid out.
3. Add the Offers tab + expiry notifications once the core comparison flow feels
   solid.

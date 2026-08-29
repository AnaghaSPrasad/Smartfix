# SmartFix — Flutter Frontend

Home services booking app frontend, built to talk to a Django REST backend.

## What's included

```
lib/
  models/          # AppUser, ServiceItem, Booking — match your Django serializers
  services/
    api_service.dart   # All HTTP calls to Django REST (login, services, bookings)
  providers/
    auth_provider.dart # Login state via Provider (ChangeNotifier)
  screens/
    login_screen.dart
    register_screen.dart
    home_screen.dart          # Lists services from GET /api/services/
    service_detail_screen.dart
    booking_screen.dart       # Date + address, POST /api/bookings/
  main.dart          # App entry, Provider wiring, auth gate
pubspec.yaml
```

## How to get this running

1. **Install Flutter SDK** if you haven't: https://docs.flutter.dev/get-started/install
   Verify with `flutter doctor`.

2. **Create the actual Flutter project shell** (this skeleton has the `lib/` code
   but not the platform folders like `android/`, `ios/`, which only `flutter create`
   can generate correctly):
   ```
   flutter create smartfix_app
   ```
   Then copy `lib/` and `pubspec.yaml` from this download into the generated
   `smartfix_app` folder, overwriting the defaults.

3. **Install dependencies:**
   ```
   cd smartfix_app
   flutter pub get
   ```

4. **Point the app at your Django backend.**
   Open `lib/services/api_service.dart` and update `baseUrl`:
   - Android emulator → `http://10.0.2.2:8000/api`
   - iOS simulator → `http://localhost:8000/api`
   - Physical device → `http://<your-computer's-LAN-IP>:8000/api`

5. **Run it:**
   ```
   flutter run
   ```

## Expected Django REST endpoints

This frontend assumes these endpoints exist on the backend (adjust `api_service.dart`
to match if your URLs differ):

| Endpoint | Method | Purpose |
|---|---|---|
| `/api/auth/login/` | POST | `{username, password}` → `{token, ...}` |
| `/api/auth/register/` | POST | `{username, email, password}` → created user |
| `/api/services/` | GET | List of services (optional `?category=`) |
| `/api/bookings/` | GET | Current user's bookings |
| `/api/bookings/` | POST | Create a booking `{service, scheduled_date, address}` |

Auth uses DRF's `TokenAuthentication` (`Authorization: Token <token>` header).
If your backend uses JWT or session auth instead, `api_service.dart` and
`auth_provider.dart` are the two files to adjust.

## Next steps to build out

- Wire `AppUser` model into a profile screen
- Add a "My Bookings" screen using `ApiService.getMyBookings()`
- Add pull-to-refresh on the home screen
- Add image loading for services via `cached_network_image` (already in pubspec)

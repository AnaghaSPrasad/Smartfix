# SmartFix — Django REST Backend

Home services booking API for the SmartFix Flutter app.

## Setup

1. **Create a virtual environment (recommended):**
   ```
   python -m venv venv
   venv\Scripts\activate      (Windows)
   ```

2. **Install dependencies:**
   ```
   pip install -r requirements.txt
   ```

3. **Run migrations:**
   ```
   python manage.py migrate
   ```

4. **Seed sample services** (so the Home screen has data to show):
   ```
   python manage.py seed_services
   ```

5. **Create an admin user (optional, for /admin/ panel):**
   ```
   python manage.py createsuperuser
   ```

6. **Run the server** — important: bind to 0.0.0.0 so Flutter (especially on
   Android emulator or Chrome) can reach it:
   ```
   python manage.py runserver 0.0.0.0:8000
   ```

## Endpoints (match `lib/services/api_service.dart` in the Flutter app)

| Endpoint | Method | Auth | Body / Params |
|---|---|---|---|
| `/api/auth/register/` | POST | none | `{username, email, password}` → `{id, username, email, token}` |
| `/api/auth/login/` | POST | none | `{username, password}` → `{token, user_id, username}` |
| `/api/services/` | GET | none | optional `?category=Plumbing` → list of services |
| `/api/bookings/` | GET | Token | → current user's bookings |
| `/api/bookings/` | POST | Token | `{service, scheduled_date, address}` → created booking |

Auth uses DRF Token Authentication. Send `Authorization: Token <token>` on
any authenticated request — this matches `_authHeaders()` in the Flutter
`ApiService` already.

## Connecting from Flutter

In `lib/services/api_service.dart`:
- Set `useMockData = false`
- Set `baseUrl`:
  - Android emulator → `http://10.0.2.2:8000/api`
  - Chrome (web) → `http://localhost:8000/api` or `http://127.0.0.1:8000/api`
  - Physical device → `http://<your-computer-LAN-IP>:8000/api`

CORS is set wide open (`CORS_ALLOW_ALL_ORIGINS = True`) in `settings.py` for
development so Chrome won't block the requests. Tighten this before any real
deployment.

## Admin panel

Visit `http://127.0.0.1:8000/admin/` after creating a superuser to view/edit
Services and Bookings directly — handy for demos and debugging.

## Project structure

```
smartfix_backend/
  smartfix_backend/   # settings, root urls
  accounts/            # register + login (token auth)
  services/            # Service model, list endpoint, seed_services command
  bookings/             # Booking model, list/create endpoint (per-user)
  requirements.txt
  manage.py
```

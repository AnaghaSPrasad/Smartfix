# SmartFix — What's new & how to run it

This build adds the pieces the abstract promised that weren't in the starter
project yet: **role-based accounts (Customer / Worker / Admin), urgent vs.
scheduled bookings with auto-assignment, the worker job lifecycle, worker
verification, and complaints.** Location tracking, ratings/reviews, and the
chatbot are intentionally left out, as requested.

## 1. Reset the database (schema changed)

The `Booking` model changed a lot (new fields, renamed `user` → `customer`,
added `worker`, `request_type`, etc.) and there's a new `Complaint` model, so
the old migration for `bookings` was removed. Easiest path — wipe and
rebuild:

```bash
cd smartfix_backend
rm -f db.sqlite3
rm -f bookings/migrations/0*.py     # keep __init__.py
python manage.py makemigrations accounts bookings services
python manage.py migrate
python manage.py seed_services
```

## 2. Create your test accounts

Register a **customer** and a **worker** straight from the Flutter app's
Register screen (pick a category for the worker — it must match a
`Service.category`, e.g. "Plumbing").

For an **admin** account, register a normal account first (role doesn't
matter), then promote it from the command line:

```bash
python manage.py createsuperuser        # or register via the app
python manage.py promote_admin <username>
```

The admin can then verify workers, view all bookings, and resolve
complaints — either from the Flutter Admin screens or from `/admin/`.

## 3. Run the server

```bash
python manage.py runserver 0.0.0.0:8000
```

## New / changed endpoints

| Endpoint | Method | Role | Purpose |
|---|---|---|---|
| `/api/auth/register/` | POST | any | now takes `role` (`customer`/`worker`), `phone`, `category` |
| `/api/auth/login/` | POST | any | now returns `role`, `is_verified`, `category` |
| `/api/auth/profile/` | GET/PATCH | any | view/update own profile; worker toggles `is_available` here |
| `/api/auth/workers/` | GET | admin | list workers, `?verified=false` for pending ones |
| `/api/auth/workers/<id>/verify/` | POST | admin | `{verify: true/false}` |
| `/api/bookings/` | GET/POST | customer | own bookings; urgent requests auto-assign on create |
| `/api/bookings/<id>/` | GET | owner/assigned worker/admin | booking detail |
| `/api/bookings/open/` | GET | worker | unassigned **scheduled** requests in their category |
| `/api/bookings/<id>/accept/` | POST | worker | claim an open job (requires verification) |
| `/api/bookings/mine/` | GET | worker | jobs assigned to them |
| `/api/bookings/<id>/update_status/` | POST | worker | `{status: in_progress\|completed\|cancelled}` |
| `/api/bookings/admin/all/` | GET | admin | every booking, `?status=` filter |
| `/api/complaints/` | GET/POST | customer/admin | customer files, admin sees all |
| `/api/complaints/<id>/resolve/` | POST | admin | `{admin_note}` |

## How the core workflows behave

- **Urgent request** → created with `status=pending`, then immediately
  auto-assigned to a random verified + available worker in the matching
  category (`status=assigned`). This is the offline stand-in for "nearest
  available worker" since there's no live location in this build. If no
  worker matches, it just sits at `pending` until an admin/worker follows up
  manually via Django admin.
- **Scheduled request** → created with `status=pending` and shows up on the
  job board (`/bookings/open/`) for any *verified* worker in that category to
  accept.
- **Status lifecycle**: `pending → assigned → in_progress → completed`
  (or `cancelled` from `assigned`/`in_progress`). Only the assigned worker can
  advance it.
- **Worker verification**: new workers register with `is_verified=False`.
  They can browse jobs immediately but can't accept them (or receive
  auto-assigned urgent jobs) until an admin verifies them.
- **Complaints**: customers can file one against any of their own bookings
  (typically after `completed`); admins resolve them with an optional note.

## Still worth doing before a real demo

- Add a few more seeded workers per category (via `/admin/` or the register
  screen) so urgent auto-assign and the open-jobs board have something to
  show.
- Tighten `CORS_ALLOW_ALL_ORIGINS` and rotate `SECRET_KEY` before any real
  deployment — both are fine for local dev/demo only.

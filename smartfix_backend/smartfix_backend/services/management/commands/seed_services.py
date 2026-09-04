from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from accounts.models import Profile
from services.models import Service
from bookings.models import Booking, Complaint


class Command(BaseCommand):
    help = "Seed the database with rich home services, verified demo workers, test accounts, and sample bookings."

    def handle(self, *args, **options):
        sample_services = [
            {"name": "Plumbing Leak & Pipe Repair", "category": "Plumbing", "description": "Emergency pipe fixes, dripping taps, low pressure repair, and drain unclogging.", "price": 349},
            {"name": "Water Heater / Geyser Service", "category": "Plumbing", "description": "Thermostat replacement, heating coil repair, and installation.", "price": 499},
            {"name": "Electrician Emergency Visit", "category": "Electrical", "description": "Short-circuit fixes, MCB tripping, sparking switches, and main line check.", "price": 299},
            {"name": "Ceiling Fan & Light Installation", "category": "Electrical", "description": "Installation of chandeliers, decorative lights, exhaust fans, and switches.", "price": 249},
            {"name": "Full Home Deep Cleaning", "category": "Cleaning", "description": "Comprehensive scrubbing, sanitization of kitchen, bathrooms, floors, and windows.", "price": 1299},
            {"name": "Bathroom & Kitchen Sanitization", "category": "Cleaning", "description": "High-pressure steam cleaning, tile grout removal, and descaling.", "price": 699},
            {"name": "Garden Maintenance & Trimming", "category": "Gardening", "description": "Lawn mowing, hedge trimming, weed removal, and plant nourishment.", "price": 499},
            {"name": "Landscape & Plant Potting", "category": "Gardening", "description": "New plant potting, soil fertilizing, balcony garden setup.", "price": 799},
            {"name": "General Pest Control Spray", "category": "Pest Control", "description": "Odorless herbal treatment for cockroaches, ants, termites, and mosquitoes.", "price": 799},
            {"name": "Bed Bug & Termite Treatment", "category": "Pest Control", "description": "Advanced chemical treatment with 3-month protection guarantee.", "price": 1199},
            {"name": "Split / Window AC Servicing", "category": "Appliance", "description": "Filter cleaning, cooling coil wash, gas leak check, and performance test.", "price": 599},
            {"name": "Washing Machine & Refrigerator Repair", "category": "Appliance", "description": "Drum motor check, cooling issues, PCB repair, and spare replacement.", "price": 649},
        ]

        # 1. Services
        service_objs = {}
        for data in sample_services:
            svc, _ = Service.objects.update_or_create(
                name=data["name"],
                defaults={
                    "category": data["category"],
                    "description": data["description"],
                    "price": data["price"],
                }
            )
            service_objs[svc.name] = svc
        self.stdout.write(self.style.SUCCESS("[OK] Seeded/Updated 12 Service listings across 6 categories."))

        # 2. Admin User
        admin_user, _ = User.objects.get_or_create(username="admin", defaults={"email": "admin@smartfix.com", "is_staff": True, "is_superuser": True})
        admin_user.set_password("admin123")
        admin_user.save()
        Profile.objects.update_or_create(user=admin_user, defaults={"role": "admin", "phone": "+91 98765 00000"})
        self.stdout.write(self.style.SUCCESS("[OK] Admin user ready: admin / admin123"))

        # 3. Customer Users
        cust_user, _ = User.objects.get_or_create(username="customer", defaults={"email": "customer@smartfix.com"})
        cust_user.set_password("password123")
        cust_user.save()
        Profile.objects.update_or_create(user=cust_user, defaults={"role": "customer", "phone": "+91 98765 11111"})

        cust_user2, _ = User.objects.get_or_create(username="alsafa", defaults={"email": "alsafa@smartfix.com"})
        cust_user2.set_password("password123")
        cust_user2.save()
        Profile.objects.update_or_create(user=cust_user2, defaults={"role": "customer", "phone": "+91 98765 22222"})
        self.stdout.write(self.style.SUCCESS("[OK] Customer users ready: customer, alsafa (password: password123)"))

        # 4. Verified Workers across all categories
        demo_workers = [
            {"username": "plumber_mike", "category": "Plumbing", "email": "mike@smartfix.com", "phone": "+91 98111 00001"},
            {"username": "sparky_dan", "category": "Electrical", "email": "dan@smartfix.com", "phone": "+91 98111 00002"},
            {"username": "cleaner_anna", "category": "Cleaning", "email": "anna@smartfix.com", "phone": "+91 98111 00003"},
            {"username": "gardener_bob", "category": "Gardening", "email": "bob@smartfix.com", "phone": "+91 98111 00004"},
            {"username": "pest_pro", "category": "Pest Control", "email": "pest@smartfix.com", "phone": "+91 98111 00005"},
            {"username": "appliance_tech", "category": "Appliance", "email": "tech@smartfix.com", "phone": "+91 98111 00006"},
        ]
        worker_objs = {}
        for w in demo_workers:
            u, _ = User.objects.get_or_create(username=w["username"], defaults={"email": w["email"]})
            u.set_password("password123")
            u.save()
            p, _ = Profile.objects.update_or_create(
                user=u,
                defaults={
                    "role": "worker",
                    "category": w["category"],
                    "is_verified": True,
                    "is_available": True,
                    "phone": w["phone"],
                }
            )
            worker_objs[w["category"]] = u
        self.stdout.write(self.style.SUCCESS("[OK] Seeded 6 verified workers (one per category, password: password123)"))

        # 5. Sample Bookings
        b1, _ = Booking.objects.get_or_create(
            customer=cust_user,
            service=service_objs["Plumbing Leak & Pipe Repair"],
            defaults={
                "request_type": "urgent",
                "address": "42 Richmond Road, Bangalore",
                "status": "completed",
                "worker": worker_objs["Plumbing"],
            }
        )

        b2, _ = Booking.objects.get_or_create(
            customer=cust_user,
            service=service_objs["Electrician Emergency Visit"],
            defaults={
                "request_type": "urgent",
                "address": "Flat 304, Green Heights, Indiranagar, Bangalore",
                "status": "in_progress",
                "worker": worker_objs["Electrical"],
            }
        )

        b3, _ = Booking.objects.get_or_create(
            customer=cust_user,
            service=service_objs["Full Home Deep Cleaning"],
            defaults={
                "request_type": "scheduled",
                "address": "Villa 12, Palm Meadows, Whitefield, Bangalore",
                "status": "pending",
                "worker": None,
            }
        )

        self.stdout.write(self.style.SUCCESS("[OK] Seeded sample bookings for instant demo testing."))



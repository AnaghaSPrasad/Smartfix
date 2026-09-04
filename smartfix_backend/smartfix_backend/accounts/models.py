from django.db import models
from django.contrib.auth.models import User

ROLE_CHOICES = [
    ('customer', 'Customer'),
    ('worker', 'Worker'),
    ('admin', 'Admin'),
]

CATEGORY_CHOICES = [
    ('Plumbing', 'Plumbing'),
    ('Electrical', 'Electrical'),
    ('Cleaning', 'Cleaning'),
    ('Gardening', 'Gardening'),
    ('Pest Control', 'Pest Control'),
    ('Appliance', 'Appliance'),
]


class Profile(models.Model):
    """Extends the built-in Django User with SmartFix-specific role info."""
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default='customer')
    phone = models.CharField(max_length=20, blank=True)

    # Worker-only fields
    category = models.CharField(max_length=50, choices=CATEGORY_CHOICES, blank=True)
    is_verified = models.BooleanField(default=False)  # admin must verify workers
    is_available = models.BooleanField(default=True)  # worker toggles this themselves

    def __str__(self):
        return f"{self.user.username} ({self.role})"

from django.db import models
from django.contrib.auth.models import User
from services.models import Service

REQUEST_TYPE_CHOICES = [
    ('urgent', 'Urgent'),
    ('scheduled', 'Scheduled'),
]

STATUS_CHOICES = [
    ('pending', 'Pending'),        # created, waiting for a worker
    ('assigned', 'Assigned'),      # worker attached, not started yet
    ('accepted', 'Accepted'),      # worker accepted job
    ('on_the_way', 'On The Way'),  # worker traveling to customer
    ('arrived', 'Arrived'),        # worker arrived at location
    ('in_progress', 'In Progress'),# work started
    ('completed', 'Completed'),
    ('cancelled', 'Cancelled'),
]


class Booking(models.Model):
    customer = models.ForeignKey(User, on_delete=models.CASCADE, related_name='bookings')
    worker = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='jobs')
    service = models.ForeignKey(Service, on_delete=models.CASCADE)

    request_type = models.CharField(max_length=10, choices=REQUEST_TYPE_CHOICES, default='scheduled')
    scheduled_date = models.DateTimeField(null=True, blank=True)  # required for scheduled, blank for urgent
    address = models.CharField(max_length=255)
    notes = models.TextField(blank=True)

    # Customer service location coordinates
    customer_lat = models.FloatField(null=True, blank=True)
    customer_lng = models.FloatField(null=True, blank=True)

    # Live worker location tracking coordinates
    worker_lat = models.FloatField(null=True, blank=True)
    worker_lng = models.FloatField(null=True, blank=True)
    worker_location_updated_at = models.DateTimeField(null=True, blank=True)

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.customer.username} - {self.service.name} ({self.status})"


class Complaint(models.Model):
    STATUS_CHOICES = [('open', 'Open'), ('resolved', 'Resolved')]

    booking = models.ForeignKey(Booking, on_delete=models.CASCADE, related_name='complaints')
    customer = models.ForeignKey(User, on_delete=models.CASCADE, related_name='complaints')
    description = models.TextField()
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='open')
    admin_note = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    resolved_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Complaint #{self.id} on booking #{self.booking_id} ({self.status})"


from django.contrib import admin
from .models import Booking, Complaint


@admin.register(Booking)
class BookingAdmin(admin.ModelAdmin):
    list_display = ['id', 'customer', 'service', 'request_type', 'status', 'worker', 'scheduled_date', 'created_at']
    list_filter = ['request_type', 'status', 'service__category']
    search_fields = ['customer__username', 'worker__username', 'service__name']


@admin.register(Complaint)
class ComplaintAdmin(admin.ModelAdmin):
    list_display = ['id', 'booking', 'customer', 'status', 'created_at']
    list_filter = ['status']

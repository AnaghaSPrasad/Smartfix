from django.contrib import admin
from .models import Profile


@admin.register(Profile)
class ProfileAdmin(admin.ModelAdmin):
    list_display = ['user', 'role', 'category', 'is_verified', 'is_available']
    list_filter = ['role', 'category', 'is_verified']
    search_fields = ['user__username', 'user__email']

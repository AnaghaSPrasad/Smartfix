from rest_framework import serializers
from .models import Booking, Complaint


class BookingSerializer(serializers.ModelSerializer):
    service_name = serializers.CharField(source='service.name', read_only=True)
    category = serializers.CharField(source='service.category', read_only=True)
    customer_name = serializers.CharField(source='customer.username', read_only=True)
    worker_name = serializers.SerializerMethodField()

    class Meta:
        model = Booking
        fields = [
            'id', 'service', 'service_name', 'category', 'request_type',
            'scheduled_date', 'address', 'notes', 'status',
            'customer_name', 'worker', 'worker_name',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['status', 'worker', 'created_at', 'updated_at']

    def get_worker_name(self, obj):
        return obj.worker.username if obj.worker_id else None

    def validate(self, data):
        request_type = data.get('request_type', 'scheduled')
        if request_type == 'scheduled' and not data.get('scheduled_date'):
            raise serializers.ValidationError({'scheduled_date': 'Required for scheduled requests.'})
        return data


class BookingStatusUpdateSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=['in_progress', 'completed', 'cancelled'])


class ComplaintSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source='customer.username', read_only=True)
    booking_summary = serializers.SerializerMethodField()

    class Meta:
        model = Complaint
        fields = [
            'id', 'booking', 'booking_summary', 'customer_name', 'description',
            'status', 'admin_note', 'created_at', 'resolved_at',
        ]
        read_only_fields = ['status', 'admin_note', 'created_at', 'resolved_at']

    def get_booking_summary(self, obj):
        when = obj.booking.scheduled_date.strftime('%d %b %Y') if obj.booking.scheduled_date else 'urgent request'
        return f"{obj.booking.service.name} ({when})"


class ComplaintResolveSerializer(serializers.Serializer):
    admin_note = serializers.CharField(required=False, allow_blank=True)



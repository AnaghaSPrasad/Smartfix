from rest_framework import serializers
from .models import Service


class ServiceSerializer(serializers.ModelSerializer):
    price = serializers.DecimalField(max_digits=8, decimal_places=2, coerce_to_string=False)
    rating = serializers.DecimalField(max_digits=2, decimal_places=1, coerce_to_string=False, required=False, allow_null=True)

    class Meta:
        model = Service
        fields = ['id', 'name', 'category', 'description', 'price', 'image', 'rating']


from django.contrib.auth.models import User
from rest_framework import serializers
from .models import Profile

# Public registration only allows these two roles.
# Admin accounts are created via `python manage.py promote_admin <username>`.
PUBLIC_ROLE_CHOICES = [('customer', 'Customer'), ('worker', 'Worker')]


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6, error_messages={
        'min_length': 'Password must be at least 6 characters long.',
    })
    role = serializers.ChoiceField(choices=PUBLIC_ROLE_CHOICES, default='customer')
    phone = serializers.CharField(required=True, allow_blank=False, error_messages={
        'required': 'Phone number is required.',
        'blank': 'Phone number cannot be blank.',
    })
    email = serializers.EmailField(required=True, allow_blank=False, error_messages={
        'required': 'Email address is required.',
        'blank': 'Email address cannot be blank.',
        'invalid': 'Enter a valid email address.',
    })
    category = serializers.ChoiceField(
        choices=Profile._meta.get_field('category').choices,
        required=False, allow_blank=True, default=''
    )

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'password', 'role', 'phone', 'category']

    def validate_username(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError("Username cannot be blank.")
        if len(value) < 3:
            raise serializers.ValidationError("Username must be at least 3 characters long.")
        if User.objects.filter(username__iexact=value).exists():
            raise serializers.ValidationError("A user with that username already exists.")
        return value

    def validate_email(self, value):
        value = value.strip().lower()
        if not value:
            raise serializers.ValidationError("Email address cannot be blank.")
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("A user with this email address already exists.")
        return value

    def validate_phone(self, value):
        value = value.strip()
        cleaned = ''.join(filter(str.isdigit, value))
        if len(cleaned) < 10:
            raise serializers.ValidationError("Enter a valid phone number with at least 10 digits.")
        return value

    def validate(self, data):
        if data.get('role') == 'worker' and not data.get('category'):
            raise serializers.ValidationError({'category': 'Service category is required for worker accounts.'})
        return data

    def create(self, validated_data):
        role = validated_data.pop('role', 'customer')
        phone = validated_data.pop('phone', '')
        category = validated_data.pop('category', '')
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data.get('email', ''),
            password=validated_data['password'],
        )
        Profile.objects.create(
            user=user,
            role=role,
            phone=phone,
            category=category if role == 'worker' else '',
            # Workers need admin verification before they can accept jobs;
            # customers are usable immediately.
            is_verified=(role != 'worker'),
        )
        return user



class ProfileSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    email = serializers.CharField(source='user.email', read_only=True)

    class Meta:
        model = Profile
        fields = ['id', 'username', 'email', 'role', 'phone', 'category', 'is_verified', 'is_available']
        read_only_fields = ['role', 'is_verified']


class WorkerSerializer(serializers.ModelSerializer):
    """Used by the admin worker-verification screen."""
    username = serializers.CharField(source='user.username', read_only=True)
    email = serializers.CharField(source='user.email', read_only=True)
    date_joined = serializers.DateTimeField(source='user.date_joined', read_only=True)
    user_id = serializers.IntegerField(source='user.id', read_only=True)

    class Meta:
        model = Profile
        fields = ['id', 'user_id', 'username', 'email', 'phone', 'role', 'category', 'is_verified', 'is_available', 'date_joined']

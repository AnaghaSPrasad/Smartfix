from rest_framework import generics, permissions, status
from rest_framework.authtoken.models import Token
from rest_framework.authtoken.views import ObtainAuthToken
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import Profile
from .serializers import RegisterSerializer, ProfileSerializer, WorkerSerializer


class IsAdminRole(permissions.BasePermission):
    """Only lets through users whose Profile.role == 'admin'."""

    def has_permission(self, request, view):
        profile = getattr(request.user, 'profile', None)
        return bool(request.user and request.user.is_authenticated and profile and profile.role == 'admin')


class RegisterView(generics.CreateAPIView):
    """POST /api/auth/register/  {username, email, password, role, phone, category}"""
    permission_classes = [permissions.AllowAny]
    serializer_class = RegisterSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        token, _ = Token.objects.get_or_create(user=user)
        profile = user.profile
        return Response(
            {
                'id': user.id,
                'username': user.username,
                'email': user.email,
                'token': token.key,
                'role': profile.role,
                'is_verified': profile.is_verified,
            },
            status=status.HTTP_201_CREATED,
        )


class LoginView(ObtainAuthToken):
    """POST /api/auth/login/  {username, password} -> {token, user_id, username, role, is_verified}"""
    permission_classes = [permissions.AllowAny]

    def post(self, request, *args, **kwargs):
        serializer = self.serializer_class(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data['user']
        token, _ = Token.objects.get_or_create(user=user)
        profile, _ = Profile.objects.get_or_create(user=user)
        return Response({
            'token': token.key,
            'user_id': user.pk,
            'username': user.username,
            'role': profile.role,
            'is_verified': profile.is_verified,
            'category': profile.category,
        })


class ProfileView(generics.RetrieveUpdateAPIView):
    """
    GET   /api/auth/profile/  -> current user's profile
    PATCH /api/auth/profile/  -> update phone / category / is_available
    (role and is_verified are read-only here — only admins can change those)
    """
    serializer_class = ProfileSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        profile, _ = Profile.objects.get_or_create(user=self.request.user)
        return profile


class WorkerListView(generics.ListAPIView):
    """Admin: GET /api/auth/workers/  optional ?verified=false to see pending ones."""
    serializer_class = WorkerSerializer
    permission_classes = [IsAdminRole]

    def get_queryset(self):
        qs = Profile.objects.filter(role='worker').order_by('-user__date_joined')
        verified = self.request.query_params.get('verified')
        if verified is not None:
            qs = qs.filter(is_verified=(verified.lower() == 'true'))
        return qs


class VerifyWorkerView(APIView):
    """Admin: POST /api/auth/workers/<id>/verify/  {verify: true|false}"""
    permission_classes = [IsAdminRole]

    def post(self, request, pk):
        try:
            profile = Profile.objects.get(pk=pk, role='worker')
        except Profile.DoesNotExist:
            return Response({'detail': 'Worker not found.'}, status=404)
        profile.is_verified = bool(request.data.get('verify', True))
        profile.save()
        return Response(WorkerSerializer(profile).data)

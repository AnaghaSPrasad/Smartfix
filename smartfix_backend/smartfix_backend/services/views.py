from rest_framework import generics, permissions
from .models import Service
from .serializers import ServiceSerializer


class ServiceListView(generics.ListAPIView):
    """GET /api/services/  (optional ?category=Plumbing)"""
    serializer_class = ServiceSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        queryset = Service.objects.all()
        category = self.request.query_params.get('category')
        if category:
            queryset = queryset.filter(category__iexact=category)
        return queryset

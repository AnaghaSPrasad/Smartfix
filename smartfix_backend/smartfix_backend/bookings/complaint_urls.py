from django.urls import path
from .views import ComplaintListCreateView, ComplaintResolveView

urlpatterns = [
    path('', ComplaintListCreateView.as_view(), name='complaint-list-create'),
    path('<int:pk>/resolve/', ComplaintResolveView.as_view(), name='complaint-resolve'),
]

from django.urls import path
from .views import (
    AvailableWorkerListView,
    RegisterView,
    LoginView,
    ProfileView,
    WorkerListView,
    VerifyWorkerView,
)

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
    path('profile/', ProfileView.as_view(), name='profile'),
    path('available-workers/', AvailableWorkerListView.as_view(), name='available-worker-list'),
    path('workers/', WorkerListView.as_view(), name='worker-list'),
    path('workers/<int:pk>/verify/', VerifyWorkerView.as_view(), name='worker-verify'),
]

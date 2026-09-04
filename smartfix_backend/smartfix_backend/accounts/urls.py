from django.urls import path
from .views import RegisterView, LoginView, ProfileView, WorkerListView, VerifyWorkerView

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
    path('profile/', ProfileView.as_view(), name='profile'),
    path('workers/', WorkerListView.as_view(), name='worker-list'),
    path('workers/<int:pk>/verify/', VerifyWorkerView.as_view(), name='worker-verify'),
]

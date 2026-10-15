from django.urls import path
from .views import (
    BookingListCreateView, BookingDetailView, OpenJobsView, MyJobsView,
    AcceptJobView, UpdateJobStatusView, UpdateWorkerLocationView, AdminBookingListView,
)

urlpatterns = [
    path('', BookingListCreateView.as_view(), name='booking-list-create'),
    path('open/', OpenJobsView.as_view(), name='booking-open'),
    path('mine/', MyJobsView.as_view(), name='booking-mine'),
    path('admin/all/', AdminBookingListView.as_view(), name='booking-admin-all'),
    path('<int:pk>/', BookingDetailView.as_view(), name='booking-detail'),
    path('<int:pk>/accept/', AcceptJobView.as_view(), name='booking-accept'),
    path('<int:pk>/update_status/', UpdateJobStatusView.as_view(), name='booking-update-status'),
    path('<int:pk>/location/', UpdateWorkerLocationView.as_view(), name='booking-worker-location'),
]



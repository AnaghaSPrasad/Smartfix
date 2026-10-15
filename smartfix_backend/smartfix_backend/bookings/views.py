from rest_framework import generics, permissions
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils import timezone

from accounts.models import Profile
from .models import Booking, Complaint
from .serializers import (
    BookingSerializer, BookingStatusUpdateSerializer, WorkerLocationUpdateSerializer,
    ComplaintSerializer, ComplaintResolveSerializer,
)


# ---------- role permissions ----------

class IsCustomer(permissions.BasePermission):
    def has_permission(self, request, view):
        p = getattr(request.user, 'profile', None)
        return bool(p and p.role == 'customer')


class IsWorker(permissions.BasePermission):
    def has_permission(self, request, view):
        p = getattr(request.user, 'profile', None)
        return bool(p and p.role == 'worker')


class IsAdminRole(permissions.BasePermission):
    def has_permission(self, request, view):
        p = getattr(request.user, 'profile', None)
        return bool(p and p.role == 'admin')


def auto_assign_worker(booking):
    """
    Urgent-request auto-assign: picks a verified, available worker in the
    booking's service category.
    """
    worker_profile = (
        Profile.objects.filter(
            role='worker', is_verified=True, is_available=True,
            category__iexact=booking.service.category,
        ).order_by('?').first()
    )
    if worker_profile:
        booking.worker = worker_profile.user
        booking.status = 'assigned'
        booking.save()
    return booking


# ---------- customer ----------

class BookingListCreateView(generics.ListCreateAPIView):
    """
    GET  /api/bookings/  -> current customer's bookings
    POST /api/bookings/  -> create a booking. Urgent requests are auto-assigned
                             immediately; scheduled ones go on the open job board.
    """
    serializer_class = BookingSerializer
    permission_classes = [permissions.IsAuthenticated, IsCustomer]

    def get_queryset(self):
        return Booking.objects.filter(customer=self.request.user)

    def perform_create(self, serializer):
        booking = serializer.save(customer=self.request.user)
        if booking.request_type == 'urgent':
            auto_assign_worker(booking)


class BookingDetailView(generics.RetrieveAPIView):
    """GET /api/bookings/<id>/ -> visible to the owning customer, assigned worker, or admin."""
    serializer_class = BookingSerializer
    permission_classes = [permissions.IsAuthenticated]
    queryset = Booking.objects.all()

    def get_object(self):
        obj = super().get_object()
        profile = self.request.user.profile
        if profile.role == 'admin':
            return obj
        if profile.role == 'customer' and obj.customer_id == self.request.user.id:
            return obj
        if profile.role == 'worker' and obj.worker_id == self.request.user.id:
            return obj
        raise PermissionDenied('Not your booking.')


# ---------- worker ----------

class OpenJobsView(generics.ListAPIView):
    """GET /api/bookings/open/ -> unassigned scheduled requests in the worker's category."""
    serializer_class = BookingSerializer
    permission_classes = [permissions.IsAuthenticated, IsWorker]

    def get_queryset(self):
        profile = self.request.user.profile
        return Booking.objects.filter(
            status='pending', worker__isnull=True,
            service__category__iexact=profile.category,
        )


class MyJobsView(generics.ListAPIView):
    """GET /api/bookings/mine/ -> jobs assigned to the current worker (active + past)."""
    serializer_class = BookingSerializer
    permission_classes = [permissions.IsAuthenticated, IsWorker]

    def get_queryset(self):
        return Booking.objects.filter(worker=self.request.user)


class AcceptJobView(APIView):
    """POST /api/bookings/<id>/accept/ -> worker accepts an open scheduled job."""
    permission_classes = [permissions.IsAuthenticated, IsWorker]

    def post(self, request, pk):
        profile = request.user.profile
        if not profile.is_verified:
            return Response({'detail': 'Your account is not yet verified by an admin.'}, status=403)
        try:
            booking = Booking.objects.get(pk=pk, status='pending', worker__isnull=True)
        except Booking.DoesNotExist:
            return Response({'detail': 'This job is no longer available.'}, status=404)
        if booking.service.category.lower() != (profile.category or '').lower():
            return Response({'detail': 'This job is outside your service category.'}, status=403)
        booking.worker = request.user
        booking.status = 'assigned'
        booking.save()
        return Response(BookingSerializer(booking).data)


class UpdateJobStatusView(APIView):
    """POST /api/bookings/<id>/update_status/  {status: accepted|on_the_way|arrived|in_progress|completed|cancelled}"""
    permission_classes = [permissions.IsAuthenticated, IsWorker]

    VALID_TRANSITIONS = {
        'assigned': ['accepted', 'on_the_way', 'in_progress', 'cancelled'],
        'accepted': ['on_the_way', 'arrived', 'in_progress', 'cancelled'],
        'on_the_way': ['arrived', 'in_progress', 'cancelled'],
        'arrived': ['in_progress', 'cancelled'],
        'in_progress': ['completed', 'cancelled'],
    }

    def post(self, request, pk):
        try:
            booking = Booking.objects.get(pk=pk, worker=request.user)
        except Booking.DoesNotExist:
            return Response({'detail': 'Job not found.'}, status=404)
        serializer = BookingStatusUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        new_status = serializer.validated_data['status']
        if new_status not in self.VALID_TRANSITIONS.get(booking.status, []):
            return Response(
                {'detail': f'Cannot move a job from "{booking.status}" to "{new_status}".'}, status=400
            )
        booking.status = new_status
        booking.save()
        return Response(BookingSerializer(booking).data)


class UpdateWorkerLocationView(APIView):
    """
    POST /api/bookings/<id>/location/
    Worker sends real-time GPS coordinates while active on the job:
    { "latitude": 12.9716, "longitude": 77.5946 }
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        profile = getattr(request.user, 'profile', None)
        try:
            booking = Booking.objects.get(pk=pk)
        except Booking.DoesNotExist:
            return Response({'detail': 'Booking not found.'}, status=404)

        # Authorized only if the user is the assigned worker or admin
        is_assigned_worker = (booking.worker_id == request.user.id)
        is_admin = (profile and profile.role == 'admin') or request.user.is_staff or request.user.is_superuser
        if not (is_assigned_worker or is_admin):
            return Response({'detail': 'You are not authorized to update location for this booking.'}, status=403)

        if booking.status in ['completed', 'cancelled']:
            return Response({'detail': 'Location cannot be updated for completed or cancelled bookings.'}, status=400)

        serializer = WorkerLocationUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        booking.worker_lat = serializer.validated_data['lat']
        booking.worker_lng = serializer.validated_data['lng']
        booking.worker_location_updated_at = timezone.now()
        booking.save()
        return Response(BookingSerializer(booking).data)


# ---------- admin ----------

class AdminBookingListView(generics.ListAPIView):
    """GET /api/bookings/admin/all/ -> every booking in the system, optional ?status="""
    serializer_class = BookingSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdminRole]

    def get_queryset(self):
        qs = Booking.objects.all()
        status_param = self.request.query_params.get('status')
        if status_param:
            qs = qs.filter(status=status_param)
        return qs


# ---------- complaints ----------

class ComplaintListCreateView(generics.ListCreateAPIView):
    """
    GET  /api/complaints/  -> customer sees their own; admin sees all
    POST /api/complaints/  -> customer files a complaint about one of their bookings
    """
    serializer_class = ComplaintSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        profile = self.request.user.profile
        if profile.role == 'admin':
            return Complaint.objects.all()
        return Complaint.objects.filter(customer=self.request.user)

    def perform_create(self, serializer):
        booking = serializer.validated_data['booking']
        if booking.customer_id != self.request.user.id:
            raise PermissionDenied('You can only file complaints about your own bookings.')
        serializer.save(customer=self.request.user)


class ComplaintResolveView(APIView):
    """POST /api/complaints/<id>/resolve/  {admin_note}"""
    permission_classes = [permissions.IsAuthenticated, IsAdminRole]

    def post(self, request, pk):
        try:
            complaint = Complaint.objects.get(pk=pk)
        except Complaint.DoesNotExist:
            return Response({'detail': 'Not found.'}, status=404)
        serializer = ComplaintResolveSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        complaint.status = 'resolved'
        complaint.admin_note = serializer.validated_data.get('admin_note', '')
        complaint.resolved_at = timezone.now()
        complaint.save()
        return Response(ComplaintSerializer(complaint).data)



from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from accounts.models import Profile
from services.models import Service
from bookings.models import Booking, Complaint


class SmartFixApiTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # 1. Create service
        self.service = Service.objects.create(
            name="Plumbing Leak Fix",
            category="Plumbing",
            description="Fix leaky pipes and taps",
            price=350,
        )

        # 2. Create customer
        self.customer = User.objects.create_user(username="test_customer", password="password123")
        Profile.objects.create(user=self.customer, role="customer", phone="9876543210")

        # 3. Create verified worker
        self.worker = User.objects.create_user(username="test_worker", password="password123")
        Profile.objects.create(
            user=self.worker, role="worker", category="Plumbing",
            is_verified=True, is_available=True, phone="9811122233"
        )

        # 4. Create admin
        self.admin = User.objects.create_user(username="test_admin", password="password123")
        Profile.objects.create(user=self.admin, role="admin")

    def test_services_list(self):
        response = self.client.get('/api/services/')
        self.assertEqual(response.status_code, 200)
        self.assertGreaterEqual(len(response.data), 1)

    def test_urgent_booking_auto_assign(self):
        self.client.force_authenticate(user=self.customer)
        response = self.client.post('/api/bookings/', {
            'service': self.service.id,
            'request_type': 'urgent',
            'address': '123 Main St, Bangalore',
            'notes': 'Kitchen pipe burst',
        })
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['status'], 'assigned')
        self.assertEqual(response.data['worker_name'], self.worker.username)

    def test_worker_lifecycle(self):
        # 1. Create urgent booking auto-assigned to worker
        booking = Booking.objects.create(
            customer=self.customer,
            service=self.service,
            request_type='urgent',
            status='assigned',
            worker=self.worker,
            address='123 Main St, Bangalore',
        )

        # 2. Worker updates status to in_progress
        self.client.force_authenticate(user=self.worker)
        res_progress = self.client.post(f'/api/bookings/{booking.id}/update_status/', {'status': 'in_progress'})
        self.assertEqual(res_progress.status_code, 200)
        self.assertEqual(res_progress.data['status'], 'in_progress')

        # 3. Worker completes job
        res_comp = self.client.post(f'/api/bookings/{booking.id}/update_status/', {'status': 'completed'})
        self.assertEqual(res_comp.status_code, 200)
        self.assertEqual(res_comp.data['status'], 'completed')

    def test_complaint_and_admin_resolution(self):
        booking = Booking.objects.create(
            customer=self.customer,
            service=self.service,
            request_type='urgent',
            status='completed',
            worker=self.worker,
            address='123 Main St, Bangalore',
        )

        # Customer files complaint
        self.client.force_authenticate(user=self.customer)
        res_comp = self.client.post('/api/complaints/', {
            'booking': booking.id,
            'description': 'Arrived 10 minutes later than expected.',
        })
        self.assertEqual(res_comp.status_code, 201)
        complaint_id = res_comp.data['id']

        # Admin resolves complaint
        self.client.force_authenticate(user=self.admin)
        res_res = self.client.post(f'/api/complaints/{complaint_id}/resolve/', {
            'admin_note': 'Contacted customer and offered 10% coupon.',
        })
        self.assertEqual(res_res.status_code, 200)
        self.assertEqual(res_res.data['status'], 'resolved')
        self.assertEqual(res_res.data['admin_note'], 'Contacted customer and offered 10% coupon.')

        # Customer can see the resolution message.
        self.client.force_authenticate(user=self.customer)
        res_customer = self.client.get('/api/complaints/')
        self.assertEqual(res_customer.status_code, 200)
        self.assertEqual(res_customer.data[0]['status'], 'resolved')
        self.assertEqual(res_customer.data[0]['admin_note'], 'Contacted customer and offered 10% coupon.')



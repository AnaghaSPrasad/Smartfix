from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from accounts.models import Profile


class AccountRegistrationTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_valid_customer_registration(self):
        data = {
            'username': 'newcustomer',
            'email': 'newcustomer@example.com',
            'password': 'password123',
            'role': 'customer',
            'phone': '9876543210',
        }
        response = self.client.post('/api/auth/register/', data)
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['username'], 'newcustomer')
        self.assertEqual(response.data['role'], 'customer')
        self.assertTrue(response.data['is_verified'])

        # Verify DB
        user = User.objects.get(username='newcustomer')
        self.assertEqual(user.email, 'newcustomer@example.com')
        self.assertEqual(user.profile.role, 'customer')
        self.assertEqual(user.profile.phone, '9876543210')

    def test_valid_worker_registration(self):
        data = {
            'username': 'newworker',
            'email': 'newworker@example.com',
            'password': 'password123',
            'role': 'worker',
            'phone': '9811122233',
            'category': 'Plumbing',
        }
        response = self.client.post('/api/auth/register/', data)
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['username'], 'newworker')
        self.assertEqual(response.data['role'], 'worker')
        self.assertFalse(response.data['is_verified'])  # Workers require admin verification

        user = User.objects.get(username='newworker')
        self.assertEqual(user.profile.category, 'Plumbing')
        self.assertFalse(user.profile.is_verified)

    def test_worker_registration_missing_category(self):
        data = {
            'username': 'workernocat',
            'email': 'workernocat@example.com',
            'password': 'password123',
            'role': 'worker',
            'phone': '9811122233',
            'category': '',
        }
        response = self.client.post('/api/auth/register/', data)
        self.assertEqual(response.status_code, 400)
        self.assertIn('category', response.data)

    def test_empty_fields_validation(self):
        data = {
            'username': '',
            'email': '',
            'password': '',
        }
        response = self.client.post('/api/auth/register/', data)
        self.assertEqual(response.status_code, 400)
        self.assertIn('username', response.data)
        self.assertIn('email', response.data)
        self.assertIn('password', response.data)

    def test_registration_without_phone(self):
        data = {
            'username': 'nophonecustomer',
            'email': 'nophone@example.com',
            'password': 'password123',
        }
        response = self.client.post('/api/auth/register/', data)
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['username'], 'nophonecustomer')
        self.assertEqual(response.data['role'], 'customer')
        user = User.objects.get(username='nophonecustomer')
        self.assertEqual(user.profile.phone, '')

    def test_invalid_email_format(self):
        data = {
            'username': 'userbadmail',
            'email': 'not-an-email',
            'password': 'password123',
            'phone': '9876543210',
        }
        response = self.client.post('/api/auth/register/', data)
        self.assertEqual(response.status_code, 400)
        self.assertIn('email', response.data)

    def test_short_password(self):
        data = {
            'username': 'usershortpw',
            'email': 'shortpw@example.com',
            'password': '123',
            'phone': '9876543210',
        }
        response = self.client.post('/api/auth/register/', data)
        self.assertEqual(response.status_code, 400)
        self.assertIn('password', response.data)

    def test_invalid_phone_format(self):
        data = {
            'username': 'userbadphone',
            'email': 'badphone@example.com',
            'password': 'password123',
            'phone': '1234',  # Less than 10 digits
        }
        response = self.client.post('/api/auth/register/', data)
        self.assertEqual(response.status_code, 400)
        self.assertIn('phone', response.data)

    def test_phone_must_be_exactly_ten_digits(self):
        for suffix, phone in [('long', '98765432101'), ('letters', '98765432ab')]:
            with self.subTest(phone=phone):
                response = self.client.post('/api/auth/register/', {
                    'username': f'userbadphone{suffix}',
                    'email': f'badphone{suffix}@example.com',
                    'password': 'password123',
                    'phone': phone,
                })
                self.assertEqual(response.status_code, 400)
                self.assertIn('phone', response.data)

    def test_duplicate_username(self):
        User.objects.create_user(username='existinguser', email='existing@example.com', password='password123')
        data = {
            'username': 'ExistingUser',  # Case insensitive
            'email': 'unique@example.com',
            'password': 'password123',
            'phone': '9876543210',
        }
        response = self.client.post('/api/auth/register/', data)
        self.assertEqual(response.status_code, 400)
        self.assertIn('username', response.data)

    def test_duplicate_email(self):
        User.objects.create_user(username='otheruser', email='duplicate@example.com', password='password123')
        data = {
            'username': 'newuser123',
            'email': 'Duplicate@Example.com',  # Case insensitive
            'password': 'password123',
            'phone': '9876543210',
        }
        response = self.client.post('/api/auth/register/', data)
        self.assertEqual(response.status_code, 400)
        self.assertIn('email', response.data)

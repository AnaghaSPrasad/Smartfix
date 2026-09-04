from django.contrib.auth.models import User
from django.core.management.base import BaseCommand, CommandError
from accounts.models import Profile


class Command(BaseCommand):
    help = "Promote an existing user to the 'admin' role (for the Admin module of the app)."

    def add_arguments(self, parser):
        parser.add_argument('username', type=str)

    def handle(self, *args, **options):
        username = options['username']
        try:
            user = User.objects.get(username=username)
        except User.DoesNotExist:
            raise CommandError(f'No such user: {username}. Register the account in the app first.')
        profile, _ = Profile.objects.get_or_create(user=user)
        profile.role = 'admin'
        profile.is_verified = True
        profile.save()
        self.stdout.write(self.style.SUCCESS(f'{username} is now an admin.'))

from django.contrib.auth.models import User
from django.core.management.base import BaseCommand

from slsl_backend.secrets import secrets


class Command(BaseCommand):
    def handle(self, *args, **options):
        if User.objects.count() == 0:
            username = secrets["admin_username"]
            email = secrets["admin_email"]
            password = secrets["admin_password"]
            print("Creating account for %s (%s)" % (username, email))
            admin = User.objects.create_superuser(
                email=email, username=username, password=password
            )
            admin.is_active = True
            admin.is_admin = True
            admin.save()
        else:
            print("Admin accounts can only be initialized if no Users exist")

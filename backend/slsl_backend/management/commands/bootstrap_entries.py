# This file defines a management command that consumes the initial video files from the
# video bank and creates the corresponding database entries + uploads the videos. It is
# written such that it should be safe to call it multiple times and it won't upload
# duplicate entries / incorrectly clobber existing ones.

from django.core.management.base import BaseCommand

from slsl_backend.secrets import secrets


class Command(BaseCommand):
    def handle(self, *args, **options):

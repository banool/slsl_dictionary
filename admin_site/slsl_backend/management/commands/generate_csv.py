# Generate a csv to be used for translating.

import csv

from django.core.management.base import BaseCommand

from slsl_backend import models


class Command(BaseCommand):
    def add_arguments(self, parser):
        parser.add_argument("out_file")
        parser.add_argument("--only-no-translations", action="store_true")

    def handle(self, *args, **options):
        entries = models.Entry.objects.all()
        entry_data = entries.values(
            "word_in_english",
            "word_in_tamil",
            "word_in_sinhala",
        )

        if options["only_no_translations"]:
            entry_data = [e for e in entry_data if not e["word_in_tamil"] or not e["word_in_sinhala"]]

        with open(
            options["out_file"],
            "w",
            newline="",
            # https://stackoverflow.com/a/58941211/3846032
            encoding="utf-8-sig",
        ) as f:
            writer = csv.DictWriter(
                f,
                fieldnames=["English", "Sinhala", "Tamil"],
                extrasaction="ignore",
            )
            writer.writeheader()
            for entry in entry_data:
                entry["English"] = entry["word_in_english"]
                entry["Sinhala"] = entry["word_in_sinhala"]
                entry["Tamil"] = entry["word_in_tamil"]
                writer.writerow(entry)

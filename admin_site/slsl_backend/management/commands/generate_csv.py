# Generate a csv to be used for translating.

import csv
import dataclasses

from django.core.management.base import BaseCommand

from slsl_backend import models


class Command(BaseCommand):
    def add_arguments(self, parser):
        subparsers = parser.add_subparsers(dest="subcommand")

        entries = subparsers.add_parser("entries")
        entries.add_argument("out_file")
        entries.add_argument("--only-no-translations", action="store_true")

        definitions = subparsers.add_parser("definitions")
        definitions.add_argument("out_file")

    def handle(self, *args, **options):
        d = {
            "entries": self.handle_entries,
            "definitions": self.handle_definitions,
        }
        f = d[options["subcommand"]]
        f(options)

    # Generate a csv for translating entries.
    def handle_entries(self, options):
        entries = models.Entry.objects.all()
        entry_data = entries.values(
            "word_in_english",
            "word_in_tamil",
            "word_in_sinhala",
        )

        if options["only_no_translations"]:
            entry_data = [
                e
                for e in entry_data
                if not e["word_in_tamil"] or not e["word_in_sinhala"]
            ]

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

    # Generate a csv for translating definitions.
    def handle_definitions(self, options):
        definitions = models.Definition.objects.all()
        definition_data = definitions.values(
            # We include the ID here so we can look up the definition later more easily,
            # we probably need some kind of link back to the English definition for all
            # the non English definitions so we don't get duplicates. The data model
            # today doesn't assume a 1:1 mapping between definitions in different
            # languages, if I knew we were going to do that I would've done something
            # like what I did for entry, or some higher level model that contains sub
            # definitions for each language.
            "id",
            "sub_entry",
            "language",
            "category",
            "definition",
        )

        subentries = models.SubEntry.objects.all()
        sub_entry_data = subentries.values(
            "id",
            "entry",
            "region",
        )
        sub_entry_id_to_sub_entry_data = {d["id"]: d for d in sub_entry_data}

        entries = models.Entry.objects.all()
        entry_data = entries.values(
            "id",
            "word_in_english",
            "word_in_tamil",
            "word_in_sinhala",
        )
        entry_id_to_entry_data = {d["id"]: d for d in entry_data}

        # We collapse the data.
        @dataclasses.dataclass()
        class Data:
            definition_id: int
            word_in_english: str
            word_in_tamil: str
            word_in_sinhala: str
            region: str
            category: str
            definition_in_english: str
            sub_entry_id: int

        data = []
        for d in definition_data:
            sub_entry_data = sub_entry_id_to_sub_entry_data[d["sub_entry"]]
            entry_data = entry_id_to_entry_data[sub_entry_data["entry"]]
            data.append(
                Data(
                    definition_id=d["id"],
                    word_in_english=entry_data["word_in_english"],
                    word_in_tamil=entry_data["word_in_tamil"],
                    word_in_sinhala=entry_data["word_in_sinhala"],
                    region=sub_entry_data["region"],
                    category=d["category"],
                    definition_in_english=d["definition"],
                    sub_entry_id=d["sub_entry"],
                )
            )

        # Select all sub entries where the number of definitions in each language is
        # not the same. This is our heuristic for finding sub entries that do not have
        # complete definition translations.
        sub_entry_id_to_count = {}
        for d in definition_data:
            sub_entry_id = d["sub_entry"]
            if sub_entry_id not in sub_entry_id_to_count:
                sub_entry_id_to_count[sub_entry_id] = {"EN": 0, "TA": 0, "SI": 0}
            sub_entry_id_to_count[sub_entry_id][d["language"]] += 1
        data = [
            d
            for d in data
            if sub_entry_id_to_count[d.sub_entry_id]["EN"]
            != sub_entry_id_to_count[d.sub_entry_id]["TA"]
            or sub_entry_id_to_count[d.sub_entry_id]["EN"]
            != sub_entry_id_to_count[d.sub_entry_id]["SI"]
        ]

        ds = []
        for d in data:
            out = {
                "Definition ID": d.definition_id,
                "Word in English": d.word_in_english,
                "Word in Sinhala": d.word_in_sinhala,
                "Word in Tamil": d.word_in_tamil,
                "Region": d.region,
                "Category": d.category,
                "Definition in English": d.definition_in_english,
                # Include empty column for translation.
                "Definition in Sinhala": "",
                "Definition in Tamil": "",
            }
            ds.append(out)

        with open(
            options["out_file"],
            "w",
            newline="",
            # https://stackoverflow.com/a/58941211/3846032
            encoding="utf-8-sig",
        ) as f:
            writer = csv.DictWriter(
                f,
                fieldnames=list(ds[0].keys()),
                extrasaction="ignore",
            )
            writer.writeheader()
            for out in ds:
                writer.writerow(out)

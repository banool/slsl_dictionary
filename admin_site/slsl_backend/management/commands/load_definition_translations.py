"""
This script can be used to load in translations of definitions from a CSV file. The CSV
would have originally come from scripts/translate_definitions.py. This is idemponent
thanks to the translation_of field, assuming that there is only a single translation of
a definition for each non-English language.
"""

import csv

from django.core.management.base import BaseCommand

from slsl_backend import models


class Command(BaseCommand):
    help = "Add definitions in Sinhala and Tamil to SubEntries from CSV"

    def add_arguments(self, parser):
        parser.add_argument("csv_file", type=str, help="Path to the CSV file")
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Run the script without making changes",
        )
        parser.add_argument(
            "--limit",
            type=int,
            help="Limit the number of definitions to process",
        )

    def handle(self, *args, **options):
        csv_file = options["csv_file"]
        dry_run = options.get("dry_run", False)

        # Build a map of existing Definition IDs to their SubEntry IDs
        # Load up all definitions and sub-entries.
        definitions = list(models.Definition.objects.all())
        sub_entries = list(models.SubEntry.objects.all())

        # Build maps based on ID.
        sub_entry_id_to_sub_entry = {
            sub_entry.id: sub_entry for sub_entry in sub_entries
        }

        definition_id_to_subentry = {}
        for definition in definitions:
            definition_id_to_subentry[definition.id] = sub_entry_id_to_sub_entry[
                definition.sub_entry_id
            ]

        # Build a map of English definition ID -> language code -> non-English definition ID. This lets us
        # look up if a translated definition already exists in the DB.
        english_definition_id_to_language_to_other_definition_id = {}
        for definition in definitions:
            english_definition_id = definition.translation_of_id
            d = english_definition_id_to_language_to_other_definition_id.setdefault(english_definition_id, {})
            d[definition.language] = definition.id

        sub_entry_id_to_definition = {}
        for definition in definitions:
            sub_entry_id_to_definition.setdefault(
                definition.sub_entry_id, {}
            ).setdefault(definition.language, {}).setdefault(definition.id, definition)

        with open(csv_file, "r", encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            rows = list(reader)

        if options.get("limit"):
            rows = rows[: options["limit"]]

        for row in rows:
            definition_id = int(row["Definition ID"])
            definition_in_sinhala = row["Definition in Sinhala"].strip()
            definition_in_tamil = row["Definition in Tamil"].strip()
            category = row["Category"].strip()

            subentry = definition_id_to_subentry.get(definition_id)
            if not subentry:
                print(f"SubEntry for definition {definition_id} not found.")
                continue

            # Prepare new definitions
            definitions = {
                "SI": definition_in_sinhala,
                "TA": definition_in_tamil,
            }

            for language_code, definition_text in definitions.items():
                if not definition_text:
                    continue

                other_definition_id = english_definition_id_to_language_to_other_definition_id.get(definition_id, {}).get(language_code)
                if other_definition_id:
                    print(f"Translation of definition '{definition_id}' for '{language_code}' already exists as '{other_definition_id}'.")
                    continue

                if dry_run:
                    print(
                        f"[Dry Run] Would add definition for '{language_code}' to SubEntry '{subentry.id}'."
                    )
                else:
                    # Create new Definition
                    new_definition = models.Definition(
                        language=language_code,
                        category=category,
                        definition=definition_text,
                        sub_entry=subentry,
                        # https://stackoverflow.com/a/2846537/3846032
                        translation_of_id=definition_id,
                    )
                    new_definition.save()
                    print(
                        f"Added definition for '{language_code}' to SubEntry '{subentry.id}' as translation of '{definition_id}'"
                    )

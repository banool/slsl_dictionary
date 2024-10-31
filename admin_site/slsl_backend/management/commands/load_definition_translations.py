"""
This script can be used to load in translations of definitions from a CSV file. The CSV
would have originally come from scripts/translate_definitions.py. This is only idempotent
if you use the exact same definitions Sinhala / Tamil translations, otherwise it will
consider them to be new definitions and add them. So if you run this script multiple times
with different csvs, be careful. Probably best to regenerate a new csv for the entries
where there aren't definitions for Sinhala / Tamil. But note that there is no direct
notion of "definition translations", definitions for different languages are not linked.
"""

import csv

from django.core.management.base import BaseCommand

from slsl_backend import models
from slsl_backend.dump import build_dump_models


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

                # Check if a definition for this language already exists for this sub-entry.
                if sub_entry_id_to_definition.get(subentry.id, {}).get(language_code):
                    print(
                        f"Definition already exists for language '{language_code}' in SubEntry '{subentry.id}'."
                    )
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
                    )
                    new_definition.save()
                    print(
                        f"Added definition for '{language_code}' to SubEntry '{subentry.id}'."
                    )

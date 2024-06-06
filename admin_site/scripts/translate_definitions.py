"""
This works with the output of this command:

poetry run python manage.py generate_csv definitions ~/definitions-to-translate.csv
"""

import argparse
import csv
import logging
from googletrans import Translator


logging.basicConfig(level="INFO", format="%(asctime)s - %(levelname)s - %(message)s")


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("input_csv", type=str, help="Input CSV file")
    parser.add_argument("output_csv", type=str, help="Output CSV file")
    parser.add_argument("--start-at", type=int, help="Start at this row", default=0)
    args = parser.parse_args()
    return args


def translate_text(translator, text, dest_lang):
    try:
        return translator.translate(text, dest=dest_lang).text
    except Exception as e:
        logging.error(f"Translation error: {e}")
        return text


# Alter rows in place.
def translate_definitions(rows, start_at, limit):
    translator = Translator()

    for row in rows[start_at:start_at + limit]:
        row['Definition in Sinhala'] = translate_text(translator, row['Definition in English'], 'si')
        row['Definition in Tamil'] = translate_text(translator, row['Definition in English'], 'ta')
        logging.info(f"Translated: {row['Definition in English']} -> {row['Definition in Sinhala']} // {row['Definition in Tamil']}")


def main():
    args = parse_args()

    logging.info("Reading input CSV file")

    with open(args.input_csv, 'r') as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        rows = list(reader)

    logging.info(f"Translating {len(rows)} definitions")

    start_at = args.start_at
    limit = 50
    while True:
        translate_definitions(rows, start_at, limit)
        start_at += limit

        with open(args.output_csv, 'w') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows)
        logging.info(f"Wrote output ({start_at} rows so far) to {args.output_csv}")

        if start_at >= len(rows):
            break


if __name__ == "__main__":
    main()

# This file defines a management command that consumes the video files from the Phrases
# directory and creates entries for them. It expects that the Phrases directory is
# organized like this:
#
#   Phrases/
#     Food/
#       MyFavouriteFruitIsApple.mp4
#       MyFavouriteFruitIsBanana.mp4
#     Sports/
#       IPlayCricket.mp4
#       IPlayTennis.mp4
#
# It doesn't handle partial Entry uploads very well though, so don't cancel the script
# part way through if you can avoid it / clean up the latest word if you did have to.
#
# Even at the time of writing (2023-06-02) this script is not idempotent because the
# data in the site once added could have changed, making the logic to find things we've
# already uploaded incorrect. So be careful, try to only use this for brand new data.
#
# From slsl_backend run this command like this:
#
#   poetry run python manage.py bootstrap_phrases ~/Phrases --dry-run

import os
import re
import sys

from django.core.files.base import File
from django.core.management.base import BaseCommand

from slsl_backend import models
from slsl_backend.dump import build_dump_models


class Command(BaseCommand):
    def add_arguments(self, parser):
        parser.add_argument("directory")
        parser.add_argument("--limit", type=int)
        parser.add_argument("--dry-run", action="store_true")

    def handle(self, *args, **options):
        directory = options["directory"]
        limit = options.get("limit")

        subdirnames = sorted(os.listdir(directory))

        category_to_word_to_region_to_video_fnames = {}

        for subdirname in subdirnames:
            if not os.path.isdir(os.path.join(directory, subdirname)):
                continue
            category, word_to_region_to_video_fnames = self.handle_subdir(
                directory, subdirname
            )
            category_to_word_to_region_to_video_fnames[
                category
            ] = word_to_region_to_video_fnames

        num_processed = 0

        # Get all Entries so we know what we might need to skip.
        existing_entry_dump = build_dump_models()

        # Create a map of phrases (in English, which is the primary key) to videos.
        # For this we flatten out any sub entries' videos into a single list.
        existing_word_to_video_fnames = {}
        for e in existing_entry_dump:
            videos = []
            for s in e.get("sub_entries", []):
                videos += s.get("videos", [])
            existing_word_to_video_fnames[e["word_in_english"]] = videos

        for (
            category,
            word_to_region_to_video_fnames,
        ) in category_to_word_to_region_to_video_fnames.items():
            print(f"=== Working on category {category} ===")
            for word, region_to_video_fnames in word_to_region_to_video_fnames.items():
                # See if we need to skip the word, either because there is nothing to
                # do or because manual intervention is required.
                if word in existing_word_to_video_fnames:
                    existing_video_basenames = [
                        get_filename_no_ext(f)
                        for f in existing_word_to_video_fnames[word]
                    ]
                    new_video_basenames = [
                        get_filename_no_ext(f)
                        for f in sum(list(region_to_video_fnames.values()), [])
                    ]
                    if set(existing_video_basenames) == set(new_video_basenames):
                        print(
                            f"Skipping {word} because it already exists in the DB and has the same videos"
                        )
                    else:
                        print(
                            f"WARNING: Skipping {word} because it already exists in the DB but has different videos"
                        )
                        # TODO Add instructions explaining what to do to fix this.
                        print(f"Existing: {existing_video_basenames}")
                        print(f"New: {new_video_basenames}")
                    continue
                if options.get("dry_run"):
                    print(f'Would\'ve created entry for word "{word}"')
                else:
                    # Create the Entry
                    entry = models.Entry()
                    entry.word_in_english = word
                    entry.category = category
                    entry.entry_type = models.EntryType.PHRASE
                    entry.save()
                for region, video_fnames in region_to_video_fnames.items():
                    print(
                        f"Working on sub-entries for word {word} (region {region}): {[os.path.basename(f) for f in video_fnames]}"
                    )
                    if options.get("dry_run"):
                        print(
                            f'Would\'ve created sub-entry for word "{word}" (region {region}) with {[os.path.basename(f) for f in video_fnames]}'
                        )
                    else:
                        # Create the SubEntry, pointing back to the Entry.
                        sub_entry = models.SubEntry()
                        sub_entry.entry = entry
                        sub_entry.region = region
                        sub_entry.save()

                        # Attach the Videos to the SubEntry.
                        for fname in video_fnames:
                            with open(fname, "rb") as f:
                                content = File(f)
                                # Create the Video and save the file content to it, which will
                                # actually result in uploading the file.
                                video = models.Video()
                                video.sub_entry = sub_entry
                                video.media.save(os.path.basename(fname), content)

                num_processed += 1
                if limit and num_processed >= limit:
                    print("Hit the limit, exiting...")
                    sys.exit(0)

        print(f"Done, added {num_processed} entries!")

    def handle_subdir(self, directory, subdirname):
        category = self.determine_category(subdirname)

        word_to_region_to_video_fnames = {}

        fnames = sorted(os.listdir(os.path.join(directory, subdirname)))
        for fname in fnames:
            if not (fname.endswith(".mp4")):
                print(f"Skipping video not ending in .mp4: {fname}")
                continue
            word, region = self.determine_word(fname)
            region_to_video_fnames = word_to_region_to_video_fnames.setdefault(word, {})
            region_to_video_fnames.setdefault(region, []).append(
                os.path.join(directory, subdirname, fname)
            )

        return (category, word_to_region_to_video_fnames)

    def determine_word(self, fname):
        region = models.Region.ALL_OF_SRI_LANKA
        word = fname
        if " - RegionNE" in word:
            region = models.Region.NORTH_EAST
            word = word.replace(" - RegionNE", "")
        # Special case for (.-)(a|b|c|d).ext file names.
        if word.split(".")[-2].lower() in ["a", "b", "c", "d"]:
            word = word.split(".")[-3]
        if "-" in word and word.split("-")[-1][0] in ["a", "b", "c", "d"]:
            word = "-".join(word.split("-")[:-1])
        else:
            word = word.split(".")[-2]
        # If the word ends with a number, remove it.
        if word[-1].isdigit():
            word = word[:-1]
        word = word.lstrip().rstrip()
        word = camel_to_sentence(word)
        return (word, region)

    def determine_category(self, subdirname):
        return subdirname


def camel_to_sentence(camel_str):
    s1 = re.sub("(.)([A-Z][a-z]+)", r"\1 \2", camel_str)
    sentence = re.sub("([a-z0-9])([A-Z])", r"\1 \2", s1)
    sentence = sentence[0].upper() + sentence[1:].lower()
    sentence = re.sub(r"\bi\b", "I", sentence)
    return sentence


def camel_case_split(identifier):
    matches = re.finditer(
        ".+?(?:(?<=[a-z])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])|$)", identifier
    )
    return [m.group(0) for m in matches]


def get_filename_no_ext(path):
    return os.path.basename(os.path.splitext(os.path.basename(path))[0])

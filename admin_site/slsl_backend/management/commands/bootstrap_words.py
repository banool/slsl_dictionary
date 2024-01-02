# Update: I would not advise running this multiple times against the same data, I don't
# think the naming scheme is consistent or stable enough in the original data, nor the
# behavior on the backend side currently consistent enough, to make this work very well.
#
# This file defines a management command that consumes the initial video files from the
# video bank and creates the corresponding database entries + uploads the videos. It is
# written such that it should be safe to call it multiple times and it won't upload
# duplicate entries / incorrectly clobber existing ones. It doesn't handle partial
# Entry uploads very well though, so don't cancel the script part way through if you
# can avoid it / clean up the latest word if you did have to.
#
# For now this is only written to work on 1-1 SLSL Vocabulary Words.
#
# This does not handle creating multiple sub-entries per word and instead just creates
# a single sub entry for each entry. This was necessary because there was no consistent
# naming scheme for the video files and so it was not possible to determine which videos
# belonged to which sub-entry.

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

        unknown_category_count = 1

        category_to_word_to_video_fnames = {}

        for subdirname in subdirnames:
            if not os.path.isdir(os.path.join(directory, subdirname)):
                continue
            category, word_to_video_fnames = self.handle_subdir(directory, subdirname)
            if category is None:
                category = f"Unknown{unknown_category_count}"
                unknown_category_count += 1
            category_to_word_to_video_fnames[category] = word_to_video_fnames

        num_processed = 0

        # Get all Entries so we know what we might need to skip.
        existing_entry_dump = build_dump_models()

        # Create a map of words (in English, which is the primary key) to videos.
        # For this we flatten out any sub entries' videos into a single list.
        existing_word_to_video_fnames = {}
        for e in existing_entry_dump:
            videos = []
            for s in e.get("sub_entries", []):
                videos += s.get("videos", [])
            existing_word_to_video_fnames[e["word_in_english"]] = videos

        for category, word_to_video_fnames in category_to_word_to_video_fnames.items():
            print(f"=== Working on category {category} ===")
            for word, video_fnames in word_to_video_fnames.items():
                # See if we need to skip the word, either because there is nothing to
                # do or because manual intervention is required.
                if word in existing_word_to_video_fnames:
                    existing_video_basenames = [
                        get_filename_no_ext(f)
                        for f in existing_word_to_video_fnames[word]
                    ]
                    new_video_basenames = [get_filename_no_ext(f) for f in video_fnames]
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

                print(
                    f"Working on word {word}: {[os.path.basename(f) for f in video_fnames]}"
                )

                if options.get("dry_run"):
                    print(
                        f"Would've created entry for word {word} with {[os.path.basename(f) for f in video_fnames]}"
                    )
                else:
                    # Create the Entry
                    entry = models.Entry()
                    entry.word_in_english = word
                    if category and not category.startswith("Unknown"):
                        entry.category = category
                    entry.save()

                    # Create the SubEntry, pointing back to the Entry.
                    sub_entry = models.SubEntry()
                    sub_entry.entry = entry
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

        word_to_video_fnames = {}

        fnames = sorted(os.listdir(os.path.join(directory, subdirname)))
        for fname in fnames:
            if not (
                fname.endswith(".mp4")
                or fname.endswith(".m4v")
                or fname.endswith(".mov")
            ):
                print(f"Skipping video not ending in .mp4 or .m4v: {fname}")
                continue
            word = self.determine_word(fname)
            word_to_video_fnames.setdefault(word, []).append(
                os.path.join(directory, subdirname, fname)
            )

        return (category, word_to_video_fnames)

    def determine_word(self, fname):
        word = fname
        # Special case for .(a|b).ext file names.
        if fname.split(".")[-2].lower() in ["a", "b"]:
            word = fname.split(".")[-3]
        else:
            word = fname.split(".")[-2]
        word = word.replace("_SLSL", "")
        word = word.replace("_SLSL3", "")
        word = word.split("_")[-1]
        word = word.lstrip().rstrip()
        word = " ".join([s.title() for s in camel_case_split(word)])
        word = " ".join([s.title() for s in word.split("-")])
        word = word.replace("(", "").replace(")", "")
        # Remove numbers from the end of each word.
        words = []
        for w in word.split(" "):
            words.append(re.sub(r"\d+$", "", w))
        word = " ".join(words)
        word = word.lstrip().rstrip()
        word = word.replace(" Slsl", "")
        return word

    def determine_category(self, subdirname):
        if not "_" in subdirname:
            return None

        category = subdirname.split("_")[1].lstrip()
        category = category.replace(" Video Signs", "")
        category = " ".join(camel_case_split(category))
        category = " ".join(category.split("-"))
        category = category.replace("(", " (")

        # Special cases.
        if "Numbers" in category and "1K" in category:
            category = "Numbers 1 to 1000"

        return category


def camel_case_split(identifier):
    matches = re.finditer(
        ".+?(?:(?<=[a-z])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])|$)", identifier
    )
    return [m.group(0) for m in matches]


def get_filename_no_ext(path):
    return os.path.basename(os.path.splitext(os.path.basename(path))[0])

import logging

from . import models

LOG = logging.getLogger(__name__)


# Get the entire DB as JSON, to be stored in a bucket to then be served to clients.
def build_dump():
    LOG.info("Building data dump")

    # Load all the information we care about from the entries.
    entries = models.Entry.objects.all()
    entry_data = entries.values(
        "id",
        "word_in_english",
        "word_in_tamil",
        "word_in_sinhala",
        "related_words",
        "category",
    )

    # Build a map of Entry ID to Entry as a dict.
    id_to_entry = {}
    for entry in entry_data:
        id = entry["id"]
        del entry["id"]
        id_to_entry[id] = entry

    # Load up a map of SubEntry ID to Entry ID.
    sub_entries = models.SubEntry.objects.all()
    sub_entry_id_to_entry_id = {
        k: v for (k, v) in sub_entries.values_list("id", "entry")
    }

    # Attach video information to the entry data.
    videos = models.Video.objects.all()
    for video in videos:
        entry_id = sub_entry_id_to_entry_id[video.sub_entry_id]
        entry = id_to_entry[entry_id]
        sub_entries = entry.setdefault("sub_entries", {})
        sub_entry = sub_entries.setdefault(video.sub_entry_id, {})
        videos = sub_entry.setdefault("videos", [])
        videos.append(video.media.url)

    # Attach definitions information to the entry data.
    definitions = models.Definition.objects.all().values()
    for definition in definitions:
        entry_id = sub_entry_id_to_entry_id[definition["sub_entry_id"]]
        entry = id_to_entry[entry_id]
        sub_entries = entry.setdefault("sub_entries", {})
        sub_entry = sub_entries.setdefault(definition["sub_entry_id"], {})
        definitions = sub_entry.setdefault("definitions", [])
        del definition["id"]
        del definition["sub_entry_id"]
        definitions.append(definition)

    # Collapse the sub entries dictionary, since we don't actually care about
    # any kind of numerical index for the sub-entries. Order is preserved since dicts
    # are ordered in Python 3.6+ by insertion order.
    out = []
    for entry in id_to_entry.values():
        if "sub_entries" not in entry:
            continue
        entry["sub_entries"] = list(entry["sub_entries"].values())
        out.append(entry)

    # Throw out the Entry IDs and just take the values.
    out = {"data": out}

    LOG.info(f"Returning data dump containing {len(id_to_entry)} entries")

    return out

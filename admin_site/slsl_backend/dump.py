import logging

from django.forms.models import model_to_dict

from . import models

LOG = logging.getLogger(__name__)


def dump_video(video):
    """Serialise one Video for the dump.

    Back-compat: a plain CURRENT video with no versioning metadata is emitted as
    a bare filename string (the legacy shape older app builds understand).
    Anything with versioning info — HISTORICAL status, or any date/source/note —
    is emitted as an object the new app parses into a MediaItem. The "video" key
    always carries the filename, so the saved-video identity (its path) is
    unchanged either way.
    """
    name = video.media.name
    meta = {
        "researched": video.researched,
        "recorded": video.recorded,
        "published": video.published,
        "source": video.source,
        "note": video.note,
    }
    has_meta = any(v for v in meta.values())
    if video.status == models.VideoStatus.CURRENT and not has_meta:
        return name
    out = {"video": name, "status": video.status}
    for key, value in meta.items():
        if value:
            out[key] = value
    return out


def build_dump_models():
    # Load all the information we care about from the entries. We don't load up
    # categories here for efficiency reasons, it is faster to load up the relations
    # and category data separately in a single query and then build it all up in
    # the Python code.
    entries = models.Entry.objects.all()
    entry_data = entries.values(
        "id",
        "word_in_english",
        "word_in_tamil",
        "word_in_sinhala",
        "entry_type",
    )

    # Build a map of Entry ID to Entry as a dict.
    entry_id_to_entry = {}
    for entry in entry_data:
        id = entry["id"]
        del entry["id"]
        entry_id_to_entry[id] = entry

    # Build a map of Category ID to Category as a dict.
    categories = models.Category.objects.all()
    category_id_to_category = {}
    for category in categories:
        id = category.id
        del category.id
        category_id_to_category[id] = category

    # Load up the entry category relations.
    entry_categories = models.Entry.categories.through.objects.all()
    entry_id_to_category_ids = {}
    for entry_category in entry_categories:
        entry_id = entry_category.entry_id
        category_id = entry_category.category_id
        entry_id_to_category_ids.setdefault(entry_id, []).append(category_id)

    # Set categories on the entries. We only set the category names. If there are no
    # relations, set an empty list.
    for entry_id, entry in entry_id_to_entry.items():
        entry["categories"] = [
            category_id_to_category[category_id].name
            for category_id in entry_id_to_category_ids.get(entry_id, [])
        ]
        # For backwards compatibility, set the first category as the "category" field.
        if entry["categories"]:
            entry["category"] = entry["categories"][0]

    # Load up a map of SubEntry ID to Entry ID.
    sub_entries = models.SubEntry.objects.all()
    sub_entry_id_to_entry_id = {
        k: v for (k, v) in sub_entries.values_list("id", "entry")
    }

    # Add base information for each sub-entry.
    for sub_entry in sub_entries:
        entry_id = sub_entry_id_to_entry_id[sub_entry.id]
        entry = entry_id_to_entry[entry_id]
        sub_entries = entry.setdefault("sub_entries", {})
        sub_entry_dict = model_to_dict(sub_entry)
        del sub_entry_dict["id"]
        del sub_entry_dict["entry"]
        sub_entry = sub_entries.setdefault(sub_entry.id, sub_entry_dict)

    # Attach video information to the sub-entry data, newest-first (highest id =
    # most recently uploaded). The app trusts this order — index 0 is the current
    # video — and does not re-sort client-side.
    videos = models.Video.objects.all().order_by("-id")
    for video in videos:
        entry_id = sub_entry_id_to_entry_id[video.sub_entry_id]
        entry = entry_id_to_entry[entry_id]
        sub_entries = entry["sub_entries"]
        sub_entry = sub_entries.setdefault(video.sub_entry_id, {})
        sub_entry.setdefault("videos", []).append(dump_video(video))

    # Attach definitions information to the sub-entry data.
    definitions = models.Definition.objects.all()
    for definition in definitions:
        entry_id = sub_entry_id_to_entry_id[definition.sub_entry_id]
        entry = entry_id_to_entry[entry_id]
        sub_entries = entry["sub_entries"]
        sub_entry = sub_entries.setdefault(definition.sub_entry_id, {})
        definition = model_to_dict(definition)
        del definition["id"]
        del definition["sub_entry"]
        sub_entry.setdefault("definitions", []).append(definition)

    # Collapse the sub entries dictionary, since we don't actually care about any kind
    # of numerical index for the sub-entries. Order is preserved since dicts are
    # ordered in Python 3.6+ by insertion order.
    out = []
    for entry in entry_id_to_entry.values():
        if "sub_entries" not in entry:
            continue
        # Remove any sub entries without at least one video.
        new_sub_entries = []
        for sub_entry in list(entry["sub_entries"].values()):
            if not sub_entry.get("videos", []):
                continue
            new_sub_entries.append(sub_entry)
        # Ignore any entries without at least one sub-entry.
        if len(new_sub_entries) == 0:
            continue
        entry["sub_entries"] = new_sub_entries
        out.append(entry)

    return out


# Get the entire DB as JSON, to be stored in a bucket to then be served to clients.
def build_dump():
    LOG.info("Building data dump")

    out = build_dump_models()

    LOG.info(f"Returning data dump containing {len(out)} entries")

    # Throw out the Entry IDs and just take the values.
    out = {"data": out}

    return out

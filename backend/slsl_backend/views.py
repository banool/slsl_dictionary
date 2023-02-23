from django.forms.models import model_to_dict
from django.http import HttpResponseBadRequest, HttpResponseForbidden, JsonResponse

from slsl_backend.secrets import secrets

from . import models


# Get the entire DB as JSON, to be stored in a bucket to then be served to clients.
def get_dump(request):
    # If the server is running with a required auth token configured, check it.
    our_auth_token = secrets.get("dump_auth_token")
    if our_auth_token:
        their_auth_token = request.headers.get("Authorization")
        if not their_auth_token:
            return HttpResponseForbidden("Authorization header required")
        if not their_auth_token.startswith("Bearer "):
            HttpResponseBadRequest("Authorization header must start with Bearer")
        their_auth_token = their_auth_token[len("Bearer ") :]
        if their_auth_token != our_auth_token:
            return HttpResponseForbidden("Auth token was incorrect")

    # Load all the Entries, SubEntries, Videos, Definitions.
    entries = models.Entry.objects.all()
    sub_entries = models.SubEntry.objects.all()
    videos = models.Video.objects.all()
    definitions = models.Definition.objects.all()

    # Build a map of ID to Entry as a dict.
    id_to_entry = {}
    for entry in entries:
        id = entry.id
        d = model_to_dict(entry)
        del d["id"]
        id_to_entry[id] = d

    # Build a map of SubEntry ID to Entry ID.
    sub_entry_id_to_entry_id = {}
    for sub_entry in sub_entries:
        sub_entry_id_to_entry_id[sub_entry.id] = sub_entry.entry.id

    # For each Video, find the Entry it belongs to through the SubEntry ID to Entry ID
    # map, create a new SubEntry in that Entry if it doesn't already exist, and then
    # add the Video.
    for video in videos:
        sub_entry_id = video.sub_entry.id
        entry_id = sub_entry_id_to_entry_id[sub_entry_id]
        entry = id_to_entry[entry_id]
        sub_entries = entry.setdefault("sub_entries", {})
        sub_entry = sub_entries.setdefault(sub_entry_id, {})
        videos = sub_entry.setdefault("videos", [])
        videos.append(video.media.url)

    # Do the same thing for the Definitions.
    for definition in definitions:
        sub_entry_id = definition.sub_entry.id
        entry_id = sub_entry_id_to_entry_id[sub_entry_id]
        entry = id_to_entry[entry_id]
        sub_entries = entry.setdefault("sub_entries", {})
        sub_entry = sub_entries.setdefault(sub_entry_id, {})
        definitions = sub_entry.setdefault("definitions", [])
        d = model_to_dict(definition)
        del d["id"]
        del d["sub_entry"]
        definitions.append(d)

    # Finally, collapse the sub entries dictionary, since we don't actually care about
    # any kind of numerical index for the sub-entries. Order is preserved since dicts
    # are ordered in Python 3.6+ by insertion order.
    for entry in id_to_entry.values():
        entry["sub_entries"] = list(entry["sub_entries"].values())

    # Simlarly, throw out the Entry IDs and just take the values.
    out = {"data": list(id_to_entry.values())}

    return JsonResponse(out)

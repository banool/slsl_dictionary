from django.http import HttpResponseBadRequest, HttpResponseForbidden, JsonResponse

from .dump import build_dump
from .secrets import secrets


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

    dump = build_dump()

    return JsonResponse(dump)

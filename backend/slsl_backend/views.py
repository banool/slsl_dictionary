from . import models

# Get the entire DB as JSON, to be stored in a bucket to then be served to clients.
# todo figure out how to make this take an auth key so only my gcp function will
# actually invoke the db dump, while anyone else will get rejected. or make the LB
# do it for me.
def get_dump():
    objects = models.Entry.objects.all()
    # todo lookup how to load up objects and their sub objects (so a DAG, no cycles)
    # and turn it into JSON.
    return objects.as_json()

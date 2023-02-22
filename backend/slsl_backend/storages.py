from storages.backends.gcloud import GoogleCloudStorage

StaticStorage = lambda: GoogleCloudStorage(location='static')
MediaStorage = lambda: GoogleCloudStorage(location='media')

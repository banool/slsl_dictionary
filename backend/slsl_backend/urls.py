from django.contrib import admin
from django.urls import path

from . import views

admin.site.site_title = "SLSL Admin"
admin.site.site_header = "Sri Lankan Sign Language Dictionary"

urlpatterns = [
    path("dump", views.get_dump),
    path("", admin.site.urls),
]

from django.contrib import admin
from django.urls import path

from . import views

urlpatterns = [
    path("", admin.site.urls),
    path("dump", views.get_dump),
]

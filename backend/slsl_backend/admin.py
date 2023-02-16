from django.contrib import admin
from django.urls import reverse
from django.utils.safestring import mark_safe

from nested_admin import NestedModelAdmin, NestedStackedInline, NestedTabularInline

from . import models


class DefinitionInline(NestedTabularInline):
    model = models.Definition
    extra = 0


class VideoInline(NestedTabularInline):
    model = models.Video
    extra = 0


class SubEntryAdmin(NestedStackedInline):
    model = models.SubEntry
    extra = 0
    inlines = [
        DefinitionInline,
        VideoInline
    ]


class EntryAdmin(NestedModelAdmin):
    search_fields = ["word_in_english", "word_in_tamil", "word_in_sinhala"]
    inlines = [
        SubEntryAdmin,
    ]


# Register relevant models.
admin.site.register(models.Entry, EntryAdmin)

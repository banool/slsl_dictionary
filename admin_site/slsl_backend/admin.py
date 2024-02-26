from django.contrib import admin
from nested_admin import NestedModelAdmin, NestedStackedInline, NestedTabularInline

from . import models

# TODO: Find a way to hide the string representation, e.g. Definition, Video, etc.
# It doesn't add anything useful. Then once that's done, make the __str__ representation
# actually more useful, e.g. the video file name. It is helpful for the history / debugging.


class DefinitionInline(NestedTabularInline):
    model = models.Definition
    extra = 0


class VideoInline(NestedTabularInline):
    model = models.Video
    extra = 0


class SubEntryAdmin(NestedStackedInline):
    model = models.SubEntry
    extra = 0
    inlines = [DefinitionInline, VideoInline]


class EntryAdmin(NestedModelAdmin):
    search_fields = ["word_in_english", "word_in_tamil", "word_in_sinhala"]
    # This introduces a nicer UI for selecting categories on the entry edit page.
    filter_horizontal = ("categories",)
    # This lets the user filter entries by entry type and category.
    list_filter = ["entry_type", "categories"]
    inlines = [
        SubEntryAdmin,
    ]


# Register relevant models.
admin.site.register(models.Entry, EntryAdmin)
admin.site.register(models.Category)

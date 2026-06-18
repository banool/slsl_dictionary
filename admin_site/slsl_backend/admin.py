from django.contrib import admin
from nested_admin import (
    NestedModelAdmin,
    NestedStackedInline,
    NestedTabularInline,
    SortableHiddenMixin,
)

from . import models

# TODO: Find a way to hide the string representation, e.g. Definition, Video, etc.
# It doesn't add anything useful. Then once that's done, make the __str__ representation
# actually more useful, e.g. the video file name. It is helpful for the history / debugging.


class DefinitionInline(NestedTabularInline):
    model = models.Definition
    extra = 0
    # `translation_of` is a self-FK to Definition. As a plain dropdown it loads
    # EVERY definition (~7.7k) as <option>s, once per definition on the change
    # page — multi-MB pages + N full-table queries that timed out the small prod
    # DB. Use a searchable autocomplete (results fetched server-side as you type,
    # so the page never loads them all); it needs DefinitionAdmin registered with
    # search_fields (below). The readable labels come from Definition.__str__.
    autocomplete_fields = ("translation_of",)


# Stacked (not tabular) so the per-video versioning fields — the status
# dropdown, the date/source text fields, and the multiline note — lay out
# vertically and stay legible.
class VideoInline(SortableHiddenMixin, NestedStackedInline):
    model = models.Video
    extra = 0
    # Drag-to-reorder the videos within a sub-entry: drag a video's header. The
    # SortableHiddenMixin hides the `order` field (it's still in `fields` so the
    # form has it) and nested_admin writes the dragged position into it; the dump
    # emits videos in that order (0 = first/primary). A new current upload still
    # auto-jumps to first — see Video.save().
    sortable_field_name = "order"
    fields = [
        "media",
        "status",
        ("researched", "recorded", "published"),
        "source",
        "note",
        # Must be in the form for sortable_field_name to work; nested_admin
        # renders it as the hidden drag widget, not a visible number input.
        "order",
    ]


class SubEntryAdmin(SortableHiddenMixin, NestedStackedInline):
    model = models.SubEntry
    extra = 0
    # Drag-to-reorder the sub-entries within an entry (drag a sub-entry header).
    sortable_field_name = "order"
    inlines = [DefinitionInline, VideoInline]


class EntryAdmin(NestedModelAdmin):
    # Adds a grip glyph + grab cursor to the inline drag handles (the sub-entry
    # and video headers), so it's obvious they can be dragged to reorder.
    class Media:
        css = {"all": ["slsl_backend/reorder_handles.css"]}

    search_fields = ["word_in_english", "word_in_tamil", "word_in_sinhala"]
    # This introduces a nicer UI for selecting categories on the entry edit page.
    filter_horizontal = ("categories",)
    # This lets the user filter entries by entry type and category.
    list_filter = ["entry_type", "categories"]
    inlines = [
        SubEntryAdmin,
    ]


@admin.register(models.Definition)
class DefinitionAdmin(admin.ModelAdmin):
    # Definitions are normally edited via the Entry page; this standalone admin
    # exists mainly so the translation_of autocomplete (in DefinitionInline) has
    # a registered, searchable target. search_fields powers that autocomplete —
    # you find the source definition by typing its text.
    search_fields = ["definition"]
    list_display = ("__str__", "language", "category")
    list_filter = ("language", "category")
    # Definition has no default ordering; give the changelist one so the
    # autocomplete view's pagination is stable (avoids UnorderedObjectList
    # warnings on every search).
    ordering = ("id",)


# Register relevant models.
admin.site.register(models.Entry, EntryAdmin)
admin.site.register(models.Category)

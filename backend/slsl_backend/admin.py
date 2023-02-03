from django.contrib import admin

from . import models


# Modify pages to support inlining.
class DefinitionInline(admin.TabularInline):
    model = models.Definition


class EntryAdmin(admin.ModelAdmin):
    search_fields = ["word_in_english", "word_in_tamil", "word_in_sinhala"]

    inlines = [
        DefinitionInline,
    ]


# Register relevant models.
admin.site.register(models.Entry, EntryAdmin)

import re

from django.core.validators import FileExtensionValidator, RegexValidator
from django.db import models
from django.utils.translation import gettext_lazy as _

from .validators import validate_media

COMMA_SEPARATED_LIST_REGEX = re.compile(r"^(?!.*,$)([\w|\s]+(?:,\s*\w(\w|\s)*)*)?$")

# TODO: Require that each entry has at least one sub entry and that each subentry has
# at least one video.


class Category(models.Model):
    class Meta:
        verbose_name_plural = "categories"
        ordering = ["name"]

    name = models.CharField(
        max_length=128, unique=True, help_text='Please use title case, e.g. "Animals"'
    )

    def __str__(self):
        return self.name


class EntryType(models.TextChoices):
    WORD = "WORD", _("Word")
    PHRASE = "PHRASE", _("Phrase")
    FINGERSPELLING = "FINGERSPELLING", _("Fingerspelling")


# This class defines a single entry, aka word.
class Entry(models.Model):
    class Meta:
        verbose_name_plural = "entries"
        ordering = ["word_in_english"]

    # Because we're only dealing with 3 languages ever, it is fine to make these
    # explicit fields, particularly since these are all "keys" into the data.
    # As for which are required, the current data model is that English is required
    # while Tamil and Sinhala are optional.
    word_in_english = models.CharField(
        max_length=256, verbose_name="Word in English", null=False, unique=True
    )
    word_in_sinhala = models.CharField(
        max_length=256, null=True, blank=True, verbose_name="Word in Sinhala"
    )
    word_in_tamil = models.CharField(
        max_length=256, null=True, blank=True, verbose_name="Word in Tamil"
    )

    categories = models.ManyToManyField(Category, blank=True)

    # This field defines whether the entry is, for now, a word or phrase.
    entry_type = models.CharField(
        max_length=32,
        null=False,
        help_text="Whether this entry is a word or a phrase. If unsure, use word.",
        choices=EntryType.choices,
        default=EntryType.WORD,
    )

    datetime_added = models.DateTimeField(auto_now_add=True)
    datetime_modified = models.DateTimeField(auto_now=True)

    def __str__(self):
        out = self.word_in_english
        if self.word_in_tamil:
            out += f" ({self.word_in_tamil})"
        if self.word_in_sinhala:
            out += f" ({self.word_in_sinhala})"
        return out


# TODO: Iterate on this.
class DefinitionCategory(models.TextChoices):
    AS_A_NOUN = "AS_A_NOUN", _("As a noun")
    AS_A_VERB_OR_ADJECTIVE = "AS_A_VERB_OR_ADJECTIVE", _("As a verb or adjective")
    AS_MODIFIER = "AS_MODIFIER", _("As modifier")
    AS_QUESTION = "AS_QUESTION", _("As question")
    INTERACTIVE = "INTERACTIVE", _("Interactive")
    GENERAL_DEFINITION = "GENERAL_DEFINITION", _("General definition")
    NOTE = "NOTE", _("Note")
    AUGMENTED_MEANING = "AUGMENTED_MEANING", _("Augmented meaning")
    AS_A_POINTING_SIGN = "AS_A_POINTING_SIGN", _("As a pointing sign")
    TRANSLATION = "TRANSLATION", _("Translation")


# TODO Because there are only 3, we could do 3 checkboxes in the form instead of a dropdown.
class Language(models.TextChoices):
    ENGLISH = "EN", _("English")
    TAMIL = "TA", _("Tamil")
    SINHALA = "SI", _("Sinhala")


class Region(models.TextChoices):
    ALL_OF_SRI_LANKA = "ALL", _("All of Sri Lanka")
    NORTH_EAST = "NE", _("North East")


# Per-video status. Intentionally an OPEN set: kept as plain text choices so new
# states (e.g. a regional variant) can be added later with just a migration, and
# downstream (dump + app) treats it as a string token rather than a closed enum.
class VideoStatus(models.TextChoices):
    CURRENT = "CURRENT", _("Current")
    HISTORICAL = "HISTORICAL", _("Historical")


# This links back to the Entry, implying there can be multiple SubEntries per Entry.
# per SubEntry.
class SubEntry(models.Model):
    class Meta:
        verbose_name_plural = "sub-entries"
        # Admin-controlled display order within an entry (drag-to-reorder in the
        # admin; the dump emits sub-entries in this order). See `order` below.
        ordering = ["order"]

    # Link back to the Entry.
    entry = models.ForeignKey(Entry, on_delete=models.CASCADE)

    # Position of this sub-entry within its entry. Set via the admin's
    # drag-to-reorder (nested_admin sortable_field_name); lower = earlier.
    order = models.PositiveIntegerField(default=0, db_index=True)

    # All videos in a sub entry should share the same region information.
    region = models.CharField(
        max_length=3,
        choices=Region.choices,
        default=Region.ALL_OF_SRI_LANKA,
    )

    # This can be used to help with search. These can be any language.
    # TODO: Make a new form field type to accept these.
    related_words = models.CharField(
        max_length=256,
        null=True,
        blank=True,
        validators=[
            RegexValidator(
                regex=COMMA_SEPARATED_LIST_REGEX,
                message="Please enter a comma separated list",
            )
        ],
        help_text='Optional. Comma separated, for example: "great, really awesome, fantastic"',
    )

    def __str__(self):
        return f""


# This links back to the SubEntry, implying there can be multiple Videos per SubEntry.
# Video is a legacy name, this can also contain images, e.g. for fingerspelling.
class Video(models.Model):
    class Meta:
        # Admin-controlled display order within a sub-entry (drag-to-reorder;
        # the dump emits videos in this order, so order 0 = the first/primary
        # video). See `order` below and the save() override for the auto-first
        # behaviour on a new current upload.
        ordering = ["order"]

    # Link back to the SubEntry.
    sub_entry = models.ForeignKey(SubEntry, on_delete=models.CASCADE)

    # Position of this video within its sub-entry. Set via the admin's
    # drag-to-reorder (nested_admin sortable_field_name); lower = earlier.
    order = models.PositiveIntegerField(default=0, db_index=True)

    # This manages the file that this video captures. In local dev mode this will
    # just use the development server file management (which is either in memory
    # or in a temp dir depending on the size). In prod this will use a real cloud
    # bucket. See settings.py for more.
    # Reject corrupt uploads and videos in formats clients can't decode (see
    # validators.validate_media). The extension check stays as a cheap first gate.
    media = models.FileField(
        validators=[
            FileExtensionValidator(allowed_extensions=["mp4", "jpg"]),
            validate_media,
        ]
    )

    # Whether this is the current sign or an older/archived recording kept for
    # documentation. New uploads default to CURRENT; switch older ones to
    # HISTORICAL. See VideoStatus (open set).
    status = models.CharField(
        max_length=32,
        choices=VideoStatus.choices,
        default=VideoStatus.CURRENT,
    )

    # Free-form display dates. Deliberately strings, not DateFields: an admin may
    # only know a year ("2014") or a phrase ("March 2016"). Shown verbatim in the
    # app's source sheet; never parsed.
    researched = models.CharField(max_length=64, blank=True, default="")
    recorded = models.CharField(max_length=64, blank=True, default="")
    published = models.CharField(max_length=64, blank=True, default="")

    # Where the sign came from, e.g. "Deaf School Archive, Kandy". Free text for
    # now; may later become a person/org/URL.
    source = models.CharField(max_length=256, blank=True, default="")

    # Admin-authored free text shown in the source sheet's note card. Optional.
    note = models.TextField(blank=True, default="")

    def save(self, *args, **kwargs):
        # A newly-uploaded current video becomes the first (primary) video for
        # its sub-entry: bump the existing videos down one so it sorts ahead of
        # them (the dump orders by `order`, so 0 = first). Only on creation of a
        # CURRENT video — editing an existing video, or reordering, is left to
        # the admin's drag-to-reorder. (Reordering happens via the historical
        # model in migrations and via nested_admin in the admin, neither of
        # which is "adding", so they don't trip this.)
        promote = self._state.adding and self.status == VideoStatus.CURRENT
        if promote and self.sub_entry_id is not None:
            Video.objects.filter(sub_entry_id=self.sub_entry_id).update(
                order=models.F("order") + 1
            )
            self.order = 0
        super().save(*args, **kwargs)

    def __str__(self):
        return f"Video"


# Unlike the Auslan data, we choose to allow only one definition per language plus
# category pair. This approach flattens the data as much as possible. In the various
# frontends we can reorganize however we wish.
# This links back to the SubEntry, implying there can be multiple Definitions per SubEntry.
class Definition(models.Model):
    # Link back to the SubEntry.
    sub_entry = models.ForeignKey(SubEntry, on_delete=models.CASCADE)

    # If this definition is a translation of another definition, we link to it. This
    # helps us find definitions that are missing translations.
    translation_of = models.ForeignKey(
        "self",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="translations",
    )

    language = models.CharField(
        max_length=3,
        choices=Language.choices,
        default=Language.ENGLISH,
    )
    category = models.CharField(
        max_length=32,
        choices=DefinitionCategory.choices,
        default=DefinitionCategory.AS_A_NOUN,
    )
    definition = models.TextField()

    def __str__(self):
        # Descriptive so the admin (e.g. the translation_of autocomplete picker
        # and history) shows what this definition actually is — language +
        # category + a short snippet — rather than a useless constant. Uses only
        # this row's own fields to avoid extra queries.
        snippet = " ".join((self.definition or "").split())
        if len(snippet) > 60:
            snippet = snippet[:60] + "…"
        return (
            f"{self.get_language_display()} · {self.get_category_display()}: {snippet}"
        )

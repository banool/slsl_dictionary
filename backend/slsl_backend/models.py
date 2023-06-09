import re

from django.core.validators import FileExtensionValidator, RegexValidator
from django.db import models
from django.utils.translation import gettext_lazy as _

COMMA_SEPARATED_LIST_REGEX = re.compile(r"^(?!.*,$)([\w|\s]+(?:,\s*\w(\w|\s)*)*)?$")

# TODO: Require that each entry has at least one sub entry and that each subentry has
# at least one video.

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

    # This is an optional field that we might use down the line for some kind of
    # predefined word list feature.
    category = models.CharField(
        max_length=128,
        null=True,
        blank=True,
        help_text="This is a field we might use down the line for some kind of predefined word list feature.",
    )

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


# TODO Because there are only 3, we could do 3 checkboxes in the form instead of a dropdown.
class Language(models.TextChoices):
    ENGLISH = "EN", _("English")
    TAMIL = "TA", _("Tamil")
    SINHALA = "SI", _("Sinhala")


class Region(models.TextChoices):
    ALL_OF_SRI_LANKA = "ALL", _("All of Sri Lanka")
    NORTH_EAST = "NE", _("North East")


# This links back to the Entry, implying there can be multiple SubEntries per Entry.
# per SubEntry.
class SubEntry(models.Model):
    class Meta:
        verbose_name_plural = "sub-entries"

    # Link back to the Entry.
    entry = models.ForeignKey(Entry, on_delete=models.CASCADE)

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
    # Link back to the SubEntry.
    sub_entry = models.ForeignKey(SubEntry, on_delete=models.CASCADE)

    # This manages the file that this video captures. In local dev mode this will
    # just use the development server file management (which is either in memory
    # or in a temp dir depending on the size). In prod this will use a real cloud
    # bucket. See settings.py for more.
    # TODO: Consider actually validating that the file is valid H.264 mp4.
    media = models.FileField(
        validators=[FileExtensionValidator(allowed_extensions=["mp4", "jpg"])]
    )

    def __str__(self):
        return f"Video"


# Unlike the Auslan data, we choose to allow only one definition per language plus
# category pair. This approach flattens the data as much as possible. In the various
# frontends we can reorganize however we wish.
# This links back to the SubEntry, implying there can be multiple Definitions per SubEntry.
class Definition(models.Model):
    # Link back to the SubEntry.
    sub_entry = models.ForeignKey(SubEntry, on_delete=models.CASCADE)

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
        return f"Definition"

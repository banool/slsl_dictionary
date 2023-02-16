import re

from django.core.validators import RegexValidator
from django.db import models
from django.utils.translation import gettext_lazy as _

COMMA_SEPARATED_LIST_REGEX = re.compile(r"(^$)|(\w+)(,\s*\w+)*")


# This class defines a single entry, aka word.
class Entry(models.Model):
    class Meta:
        verbose_name_plural = "entries"

    # Because we're only dealing with 3 languages ever, it is fine to make these
    # explicit fields, particularly since these are all "keys" into the data.
    # As for which are required, the current data model is that English is required
    # while Tamil and Sinhala are optional.
    word_in_english = models.CharField(max_length=256, verbose_name="Word in English")
    word_in_tamil = models.CharField(
        max_length=256, null=True, blank=True, verbose_name="Word in Tamil"
    )
    word_in_sinhala = models.CharField(
        max_length=256, null=True, blank=True, verbose_name="Word in Sinhala"
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
        help_text='Comma separated, for example: "great, awesome, fantastic"',
    )

    # blah = models.FileField(upload_to='router_specifications')

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
    SINHALA = "SIN", _("Sinhala")


# This links back to the Entry, implying there can be multiple SubEntries per Entry.
# per SubEntry.
class SubEntry(models.Model):
    class Meta:
        verbose_name_plural = "sub-entries"

    # Link back to the Entry.
    entry = models.ForeignKey(Entry, on_delete=models.CASCADE)


# This links back to the SubEntry, implying there can be multiple Videos per SubEntry.
class Video(models.Model):
    # Link back to the SubEntry.
    sub_entry = models.ForeignKey(SubEntry, on_delete=models.CASCADE)


# Unlike the Auslan data, we choose to allow only one definition per language plus
# category pair. This approach flattens the data as much as possible. In the various
# frontends we can reorganize however we wish.
# This links back to the SubEntry, implying there can be multiple Definitions per SubEntry.
class Definition(models.Model):
    # Link back to the Entry.
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


class MediaBackend(models.TextChoices):
    GCP_CDN = "GCP_CDN", _("GCP CDN")


# TODO: In the form there needs to be a way to obscure this. Really the form
# should show the admin the video and give them an option to replace it, rather
# than show them the info in this handle explicitly.
class MediaHandle(models.Model):
    # Link back to the Entry.
    entry = models.ForeignKey(Entry, on_delete=models.CASCADE)

    backend = models.CharField(
        max_length=16,
        choices=MediaBackend.choices,
        default=MediaBackend.GCP_CDN,
    )
    mime_type = models.CharField(max_length=128)
    # TODO: Come up with scheme so we know what the length will be.
    handle = models.CharField(max_length=256)

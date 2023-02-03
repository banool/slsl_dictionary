from django.db import models
from enum import Enum
import typing


# TODO: Iterate on this.
class DefinitionCategory(Enum):
    AS_A_NOUN = 1
    AS_A_VERB_OR_ADJECTIVE = 2
    AS_MODIFIER = 3
    AS_QUESTION = 4
    INTERACTIVE = 5
    GENERAL_DEFINITION = 6
    NOTE = 7
    AUGMENTED_MEANING = 8
    AS_A_POINTING_SIGN = 9


# Because there are only 3, we could do 3 checkboxes in the form instead of a dropdown.
class Language(Enum):
    ENGLISH = 1
    TAMIL = 2
    SINHALA = 3


# Unlike the Auslan data, we choose to allow only one definition per language plus
# category pair. This approach flattens the data as much as possible. In the various
# frontends we can reorganize however we wish.
# TODO: Use django stuff for this.
class Definition(models.Model):
    # TOOD: Figure out how to do this:
    # language = models.IntegerChoices(Language)
    # category = models.IntegerChoices(DefinitionCategory)
    definition: models.CharField(max_length=2048)


class MediaBackend(Enum):
    GCP_CDN = 1


# We keep this class more than just a string just in case down the line we want to use
# a different media storage backend.
class MediaHandle(models.Model):
    # backend = models.IntegerChoices(MediaBackend)
    # TODO: Google mime type max length
    mime_type = models.CharField(max_length=64)
    # TODO: Come up with scheme so we know what the length will be.
    handle = models.CharField(max_length=256)


# This class defines a single entry, aka word.
class Entry(models.Model):
    # Because we're only dealing with 3 languages ever, it is fine to make these
    # explicit fields, particularly since these are all "keys" into the data.
    # TODO: Verify this assumption that there will always be an English version.
    # If there is not, it might make sense to have `words` instead and then do
    # the same thing we're doing with Definition. In which case we could probably
    # do away with related_words.
    word_in_english = models.CharField(max_length=256)
    word_in_tamil = models.CharField(max_length=256, null=True, blank=True)
    word_in_sinhala = models.CharField(max_length=256, null=True, blank=True)

    # This can be used to help with search.
    related_words = typing.List[Definition]

    # We don't care for this to be a model because it will never be shared between
    # other models, queried individually, searched for specifically, and so on. The
    # data exists only for and within this Entry. The only reason we do use a model
    # is so the data can be viewed in a structured manner and updated easily.
    # TODO: Use proper django types for this. Make sure it's possible to get this
    # into a single web form.
    definitions = typing.List[Definition]

    # TODO: In the form there needs to be a way to obscure this. Really the form
    # should show the admin the video and give them an option to replace it, rather
    # than show them the info in this handle explicitly.
    handle: MediaHandle

    datetime_added = models.DateTimeField(auto_now=True)
    datetime_modified = models.DateTimeField(auto_now=True)

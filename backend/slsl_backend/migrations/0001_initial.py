# Generated by Django 4.1.6 on 2023-02-22 14:22

import re

import django.core.validators
import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name="Entry",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                (
                    "word_in_english",
                    models.CharField(
                        max_length=256, unique=True, verbose_name="Word in English"
                    ),
                ),
                (
                    "word_in_tamil",
                    models.CharField(
                        blank=True,
                        max_length=256,
                        null=True,
                        verbose_name="Word in Tamil",
                    ),
                ),
                (
                    "word_in_sinhala",
                    models.CharField(
                        blank=True,
                        max_length=256,
                        null=True,
                        verbose_name="Word in Sinhala",
                    ),
                ),
                (
                    "related_words",
                    models.CharField(
                        blank=True,
                        help_text='Comma separated, for example: "great, awesome, fantastic"',
                        max_length=256,
                        null=True,
                        validators=[
                            django.core.validators.RegexValidator(
                                message="Please enter a comma separated list",
                                regex=re.compile("(^$)|(\\w+)(,\\s*\\w+)*"),
                            )
                        ],
                    ),
                ),
                ("datetime_added", models.DateTimeField(auto_now_add=True)),
                ("datetime_modified", models.DateTimeField(auto_now=True)),
            ],
            options={
                "verbose_name_plural": "entries",
            },
        ),
        migrations.CreateModel(
            name="SubEntry",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                (
                    "entry",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        to="slsl_backend.entry",
                    ),
                ),
            ],
            options={
                "verbose_name_plural": "sub-entries",
            },
        ),
        migrations.CreateModel(
            name="Video",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                ("media", models.FileField(upload_to="")),
                (
                    "sub_entry",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        to="slsl_backend.subentry",
                    ),
                ),
            ],
        ),
        migrations.CreateModel(
            name="MediaHandle",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                (
                    "backend",
                    models.CharField(
                        choices=[("GCP_CDN", "GCP CDN")],
                        default="GCP_CDN",
                        max_length=16,
                    ),
                ),
                ("mime_type", models.CharField(max_length=128)),
                ("handle", models.CharField(max_length=256)),
                (
                    "entry",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        to="slsl_backend.entry",
                    ),
                ),
            ],
        ),
        migrations.CreateModel(
            name="Definition",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                (
                    "language",
                    models.CharField(
                        choices=[
                            ("EN", "English"),
                            ("TA", "Tamil"),
                            ("SIN", "Sinhala"),
                        ],
                        default="EN",
                        max_length=3,
                    ),
                ),
                (
                    "category",
                    models.CharField(
                        choices=[
                            ("AS_A_NOUN", "As a noun"),
                            ("AS_A_VERB_OR_ADJECTIVE", "As a verb or adjective"),
                            ("AS_MODIFIER", "As modifier"),
                            ("AS_QUESTION", "As question"),
                            ("INTERACTIVE", "Interactive"),
                            ("GENERAL_DEFINITION", "General definition"),
                            ("NOTE", "Note"),
                            ("AUGMENTED_MEANING", "Augmented meaning"),
                            ("AS_A_POINTING_SIGN", "As a pointing sign"),
                        ],
                        default="AS_A_NOUN",
                        max_length=32,
                    ),
                ),
                ("definition", models.TextField()),
                (
                    "sub_entry",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        to="slsl_backend.subentry",
                    ),
                ),
            ],
        ),
    ]

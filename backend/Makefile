# Copyright (c) Aptos
# SPDX-License-Identifier: Apache-2.0

fmt:
	- find . -type f -name "*.py" | xargs poetry run autoflake -i -r --remove-all-unused-imports --remove-unused-variables --ignore-init-module-imports
	- find . -type f -name "*.py" | xargs poetry run isort
	- find . -type f -name "*.py" | xargs poetry run black

lint:
	- poetry run mypy .
	- poetry run flake8 .

.PHONY: fmt lint

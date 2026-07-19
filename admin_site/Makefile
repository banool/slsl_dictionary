# Copyright (c) Aptos
# SPDX-License-Identifier: Apache-2.0

fmt:
	- find . -type f -name "*.py" | xargs uv run autoflake -i -r --remove-all-unused-imports --remove-unused-variables --ignore-init-module-imports
	- find . -type f -name "*.py" | xargs uv run isort
	- find . -type f -name "*.py" | xargs uv run black

.PHONY: fmt lint

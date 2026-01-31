# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

# The Jp module provides utility methods for GitHub data processing.
#
# This module serves as a namespace for various helper methods used throughout
# the judges-action codebase. It includes functionality for:
# - Incrementally accumulating data from multiple Ruby scripts
# - Retrieving GitHub user information with error handling
# - Processing and transforming GitHub API data
#
# All methods in this module are defined as module methods (using `def Jp.method_name`)
# to allow direct invocation without instantiation.
#
# @example
#   # Get a GitHub user's nickname
#   nick = Jp.nick_of(123456)
#
#   # Accumulate data from scripts
#   Jp.incremate(fact, '/path/to/scripts', 'total')
module Jp; end

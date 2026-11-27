# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe'
require 'fbe/octo'
require_relative 'jp'

# @todo #2649:30min Twelve judges and some_triage_time still call the fbe lookups directly, unwrap them too

def Jp.slug(id)
  Fbe.octo.repo_name_by_id(id)
rescue Fbe::Error => e
  raise(e.cause || e)
end

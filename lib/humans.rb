# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'jp'

def Jp.bots
  return [] unless $options.respond_to?(:bots)
  list = $options.bots
  return [] if list.nil? || list.empty?
  list.split(',').filter_map do |n|
    n = n.strip
    n unless n.empty?
  end
end

def Jp.human_comments(comments)
  bots = Jp.bots
  comments.reject do |c|
    login = c.dig(:user, :login)
    c.dig(:user, :type) == 'Bot' || bots.any? { |b| b.casecmp?(login.to_s) }
  end
end

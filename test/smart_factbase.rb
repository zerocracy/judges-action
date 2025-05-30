# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'

module SmartFactbase
  refine Factbase do
    def with(**props)
      insert.then do |f|
        props.each do |prop, value|
          f.send(:"#{prop}=", value)
        end
      end
      self
    end

    def picks(**props)
      eqs =
        props.map do |prop, value|
          val =
            case value
            when String then "'#{value}'"
            else value
            end
          "(eq #{prop} #{val})"
        end
      query("(and #{eqs.join(' ')})").each.to_a
    end

    def pick(**props)
      picks(**props).first
    end

    def has?(**props)
      picks(**props).size.positive?
    end

    def one?(**props)
      picks(**props).size == 1
    end

    def many?(**props)
      picks(**props).size > 1
    end

    def none?(**props)
      !has?(**props)
    end
  end
end

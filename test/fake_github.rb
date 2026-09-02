# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'json'
require 'octokit'
require 'socket'
require_relative '../lib/jp'

# rubocop:disable Elegant/NoComments
# @todo #1923:60min Move the rest of the tests onto this server.
#  Thirty three files under `test/` still build their GitHub with
#  `stub_request` and `stub_github`, over a thousand stubs in all, the
#  heaviest being `test/judges/test-quality-of-service.rb` with two
#  hundred and fifty three. Each of them should declare its routes through
#  `Jp::FakeGithub` instead, one file at a time, so that a reviewer can
#  follow every step. When the last one is moved, `stub_github` and
#  `rate_limit_up` go from `test/test__helper.rb`, the `webmock` gem goes
#  from the `Gemfile`, and `require 'webmock/minitest'` goes with it.
# rubocop:enable Elegant/NoComments
class Jp::FakeGithub
  def initialize(routes = {})
    @routes = routes
  end

  def run
    server = TCPServer.new('127.0.0.1', 0)
    uri = "http://127.0.0.1:#{server.addr[1]}"
    thread = Thread.new { serve(server) }
    endpoint = Octokit.api_endpoint
    net = WebMock.net_connect_allowed?
    begin
      Octokit.api_endpoint = uri
      WebMock.disable_net_connect!(allow_localhost: true)
      yield(uri)
    ensure
      Octokit.api_endpoint = endpoint
      net ? WebMock.allow_net_connect! : WebMock.disable_net_connect!
      thread.kill
      server.close
    end
  end

  private

  def serve(server)
    loop do
      socket = server.accept
      begin
        line = socket.gets
        break if line.nil?
        while (header = socket.gets)
          break if header.strip.empty?
        end
        answer(socket, line.split[0], line.split[1])
      ensure
        socket.close
      end
    end
  rescue IOError, Errno::EBADF, Errno::ECONNRESET
    nil
  end

  def answer(socket, method, path)
    status, body = reply(@routes.fetch("#{method} #{path}", 404))
    text = body.to_json
    socket.print(
      [
        "HTTP/1.1 #{status} #{status == 200 ? 'OK' : 'Error'}",
        'Content-Type: application/json',
        "Content-Length: #{text.bytesize}",
        'X-RateLimit-Remaining: 999',
        'Connection: close',
        '',
        text
      ].join("\r\n")
    )
  end

  def reply(route)
    case route
    when Integer then [route, {}]
    when Array then route
    else [200, route]
    end
  end
end

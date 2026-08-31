# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'json'
require 'octokit'
require 'socket'
require_relative '../lib/jp'

# A fake GitHub API, running as a real HTTP server on a local port.
#
# A test says which paths exist and what they answer, and the server answers
# them. Nothing is stubbed: Octokit opens a socket, writes a request and reads
# a response, the same way it does against the real API. That is the point of
# #760 - a stub per request makes a test long and hides what is being asked,
# while a table of paths reads like the API itself.
#
#   Jp::FakeGithub.new(
#     'GET /rate_limit' => { rate: { remaining: 222 } },
#     'GET /user/444' => 404
#   ).run do
#     load_it('who-is-alive', fb)
#   end
#
# A route answers with a hash (200 and that hash as JSON), with an integer
# (that status and an empty body), or with a pair of the two. A path nobody
# declared answers 404, so a test that forgot a call fails on the call it
# forgot rather than on a stub that quietly matched something else.
#
# @todo #760:60min Move the rest of the tests onto this server.
#  Thirty four files under `test/` still build their GitHub with
#  `stub_request` and `stub_github`, about a hundred and ten stubs in all,
#  the heaviest being `test/judges/test-github-events.rb` with forty one.
#  Each of them should declare its routes here instead, one file at a time,
#  so that a reviewer can follow every step. When the last one is moved,
#  `stub_github` and `rate_limit_up` go from `test/test__helper.rb`, the
#  `webmock` gem goes from the `Gemfile`, and `require 'webmock/minitest'`
#  goes with it.
class Jp::FakeGithub
  # Ctor.
  # @param [Hash] routes What every "METHOD /path" answers
  def initialize(routes = {})
    @routes = routes
  end

  # Start the server, point Octokit at it, run the block, then stop it.
  # @yield [String] The base URI of the server
  # @return [Object] Whatever the block returns
  def run
    server = TCPServer.new('127.0.0.1', 0)
    uri = "http://127.0.0.1:#{server.addr[1]}"
    thread = Thread.new { serve(server) }
    endpoint = Octokit.api_endpoint
    net = WebMock.net_connect_allowed?
    begin
      Octokit.api_endpoint = uri
      WebMock.disable_net_connect!(allow_localhost: true)
      yield uri
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

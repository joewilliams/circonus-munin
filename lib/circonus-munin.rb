#!/usr/bin/env ruby
#
# Author:: Adam Jacob (<adam@opscode.com>)
# Copyright:: Copyright (c) 2009 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'socket'
require 'rack/request'
require 'rack/response'
require 'libxml'

class CirconusMunin 
  def initialize(host='localhost', port=4949)
    @munin = TCPSocket.new(host, port)
    @munin.gets
  end
  
  def get_response(cmd)
    @munin.puts(cmd)
    stop = false 
    response = Array.new
    while stop == false
      line = @munin.gets
      line.chomp!
      if line == '.'
        stop = true
      else
        response << line 
        stop = true if cmd == "list"
      end
    end
    response
  end
  
  def close
    @munin.close
  end
end

class CirconusMuninServer
  def initialize
    @munin = CirconusMunin.new
  end

  def call(env)
    #req = Rack::Request.new(env)
    munin = CirconusMunin.new

    xml_document = LibXML::XML::Document.new
    resmon_results = LibXML::XML::Node.new("ResmonResults")

    munin.get_response("list")[0].split(" ").each do |metric|
      resmon_result = LibXML::XML::Node.new("ResmonResult")
      resmon_result["module"] = "MUNIN"
      resmon_result["metric"] = metric 

      begin_time = Time.now
      munin.get_response("fetch #{metric}").each do |line|
        line =~ /^(.+)\.value\s+(.+)$/
        field = $1
        value = $2
        metric = LibXML::XML::Node.new("metric")
        metric["name"] = field
        metric.content = value.to_s
        resmon_result << metric
      end
      end_time = Time.now
      runtime = end_time - begin_time

      last_runtime_seconds = LibXML::XML::Node.new("last_runtime_seconds")
      last_runtime_seconds.content = runtime.to_s
      resmon_result << last_runtime_seconds

      last_update = LibXML::XML::Node.new("last_update")
      last_update.content = Time.now.to_i.to_s
      resmon_result << last_update

      state = LibXML::XML::Node.new("state")
      state.content = "OK"
      resmon_result << state

      resmon_results << resmon_result
    end
  
    xml_document.root = resmon_results

    Rack::Response.new(xml_document.to_s, 200).finish
  end
end


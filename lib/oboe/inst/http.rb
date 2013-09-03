# Copyright (c) 2012 by Tracelytics, Inc.
# All rights reserved.

require 'net/http'

Net::HTTP.class_eval do
  def request_with_oboe(*args, &block)
    unless started? 
      return request_without_oboe(*args, &block) 
    end

    # Avoid cross host tracing for blacklisted domains
    blacklisted = Oboe::API.blacklisted?(addr_port)

    Oboe::API.trace('net-http') do
      opts = {}
      if args.length and args[0]
        req = args[0]

        opts['IsService'] = 1
        opts['RemoteProtocol'] = use_ssl? ? 'HTTPS' : 'HTTP'
        opts['RemoteHost'] = addr_port
        opts['ServiceArg'] = req.path
        opts['Method'] = req.method
        opts['Blacklisted'] = true if blacklisted
      
        Oboe::API.log('net-http', 'info', opts)
        req['X-Trace'] = Oboe::Context.toString() unless blacklisted
      end

      resp = request_without_oboe(*args, &block)

      unless blacklisted
        xtrace = resp.get_fields('X-Trace')
        if xtrace and xtrace.size and Oboe.tracing? 
          Oboe::Context.fromString(xtrace[0])
        end
      end
      next resp
    end
  end

  alias request_without_oboe request
  alias request request_with_oboe

  Oboe.logger.info "[oboe/loading] Instrumenting net/http" if Oboe::Config[:verbose]
end

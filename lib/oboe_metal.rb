# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe_metal
  class Context
    class << self
      attr_accessor :layer_op
      
      def log(layer, label, options = {}, with_backtrace = false)
        evt = Oboe::Context.createEvent()
        evt.addInfo("Layer", layer.to_s)
        evt.addInfo("Label", label.to_s)

        options.each_pair do |k, v|
          evt.addInfo(k.to_s, v.to_s)
        end

        evt.addInfo("Backtrace", Oboe::API.backtrace) if with_backtrace

        Oboe.reporter.sendReport(evt)
      end
       
      def tracing_layer_op?(operation)
        if operation.is_a?(Array)
          return operation.include?(@layer_op)
        else
          return @layer_op == operation
        end
      end
    end
  end

  class Event
    def self.metadataString(evt)
      evt.metadataString()
    end
  end

  class Reporter
    ##
    # Initialize the Oboe Context, reporter and report the initialization
    #
    def self.start
      return unless Oboe.loaded

      begin
        Oboe_metal::Context.init() 

        if ENV['RACK_ENV'] == "test"
          Oboe.reporter = Oboe::FileReporter.new("/tmp/trace_output.bson")
        else
          Oboe.reporter = Oboe::UdpReporter.new(Oboe::Config[:reporter_host])
        end

        Oboe::API.report_init('rack') unless ["development", "test"].include? ENV['RACK_ENV']
      
      rescue Exception => e
        $stderr.puts e.message
        raise
      end
    end
    
    def self.sendReport(evt)
      Oboe.reporter.sendReport(evt)
    end
  end
end

module Oboe 
  extend OboeBase
  include Oboe_metal

  class << self
    def sample?(opts = {})
      # Assure defaults since SWIG enforces Strings
      opts[:layer]      ||= ''
      opts[:xtrace]     ||= ''
      opts['X-TV-Meta']   ||= ''
      Oboe::Context.sampleRequest(opts[:layer], opts[:xtrace], opts['X-TV-Meta'])
    end

    def set_tracing_mode(mode)
      return unless Oboe.loaded

      value = mode.to_sym

      case value
      when :never
        # OBOE_TRACE_NEVER
        Oboe::Context.setTracingMode(0)
      when :always
        # OBOE_TRACE_ALWAYS
        Oboe::Context.setTracingMode(1)
      when :through
        # OBOE_TRACE_THROUGH
        Oboe::Context.setTracingMode(2)
      else
        Oboe.logger.fatal "[oboe/error] Invalid tracing mode set: #{mode}"
        # OBOE_TRACE_THROUGH
        Oboe::Context.setTracingMode(2)
      end
    end
    
    def set_sample_rate(rate)
      if Oboe.loaded
        # Update liboboe with the new SampleRate value
        Oboe::Context.setDefaultSampleRate(rate.to_i)
      end
    end
  end
end

Oboe.loaded = true


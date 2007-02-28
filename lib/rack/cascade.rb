module Rack
  class Cascade
    attr_reader :apps

    def initialize(apps, catch=404)
      @apps = apps
      @catch = [*catch]
    end

    def call(env)
      status = headers = body = nil
      raise ArgumentError, "empty cascade"  if @apps.empty?
      @apps.each { |app|
        begin
          status, headers, body = app.call(env)
          break  unless @catch.include?(status.to_i)
        end
      }
      [status, headers, body]
    end
  end
end

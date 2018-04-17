# frozen_string_literal: true

class AnUnderscoreApp
  def self.call(env)
    [200, { 'Content-Type' => 'text/plain' }, ['OK']]
  end
end

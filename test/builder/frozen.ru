# frozen_string_literal: true

run lambda { |env|
  body = 'frozen'
  raise "Not frozen!" unless body.frozen?
  [200, { 'Content-Type' => 'text/plain' }, [body]]
}

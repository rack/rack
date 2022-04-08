# frozen_string_literal: true

#\ -d -p 2929 --env test
run lambda { |env| [200, { 'content-type' => 'text/plain' }, ['OK']] }

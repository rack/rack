# frozen_string_literal: true

run lambda { |env| [200, { 'content-type' => 'text/plain' }, ['OK']] }
__END__
Should not be evaluated
Neither should
This

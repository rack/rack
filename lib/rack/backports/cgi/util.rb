# :stopdoc:

# Stolen from ruby core's cgi/util.rb:
#
# https://github.com/ruby/ruby/blob/trunk/lib/cgi/util.rb
class CGI
  @@accept_charset="UTF-8" unless defined?(@@accept_charset)
  # URL-encode a string.
  #   url_encoded_string = CGI::escape("'Stop!' said Fred")
  #      # => "%27Stop%21%27+said+Fred"
  def CGI::escape(string)
    string.gsub(/([^ a-zA-Z0-9_.-]+)/) do
      '%' + $1.unpack('H2' * $1.bytesize).join('%').upcase
    end.tr(' ', '+')
  end


  # URL-decode a string with encoding(optional).
  #   string = CGI::unescape("%27Stop%21%27+said+Fred")
  #      # => "'Stop!' said Fred"
  def CGI::unescape(string,encoding=@@accept_charset)
    string.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2})+)/) do
      [$1.delete('%')].pack('H*')
    end
  end
end

# :startdoc:

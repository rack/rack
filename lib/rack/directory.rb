module Rack
  # Rack::Directory serves entries below the +root+ given, according to the
  # path info of the Rack request. If a directory is found, the file's contents
  # will be presented in an html based index. If a file is found, the env will
  # be passed to the specified +app+.
  #
  # If +app+ is not specified, a Rack::File of the same +root+ will be used.

  class Directory < Rack::File
    DIR_FILE = "<tr><td class='name'><a href='%s'>%s</a></td><td class='size'>%s</td><td class='type'>%s</td><td class='mtime'>%s</td></tr>"
    DIR_PAGE = <<-PAGE
<html><head>
  <title>%s</title>
  <style type='text/css'>
table { width:100%%; }
.name { text-align:left; }
.size, .mtime { text-align:right; }
  </style>
</head><body>
<h1>%s</h1>
<hr />
<table>
  <tr>
    <th class='name'>Name</th>
    <th class='size'>Size</th>
    <th class='type'>Type</th>
    <th class='mtime'>Last Modified</th>
  </tr>
%s
</table>
<hr />
</body></html>
    PAGE

    attr_reader :files

    def initialize(root, app=nil)
      super(root)
      @app = app || Rack::File.new(@root)
    end

    def call(env)
      dup._call(env)
    end

    def _call(env)
      if env["PATH_INFO"].include? ".."
        return [403, {"Content-Type" => "text/plain"}, ["Forbidden\n"]]
      end

      @path = F.join(@root, Utils.unescape(env['PATH_INFO']))

      if F.exist?(@path) and F.readable?(@path)
        if F.file?(@path)
          return @app.call(env)
        elsif F.directory?(@path)
          @files = [['../','Parent Directory','','','']]
          sName, pInfo = env.values_at('SCRIPT_NAME', 'PATH_INFO')
          Dir.entries(@path).sort.each do |file|
            next if file[0] == ?.
            fl    = F.join(@path, file)
            sz    = F.size(fl)
            url   = F.join(sName, pInfo, file)
            type  = F.directory?(fl) ? 'directory' :
              MIME_TYPES.fetch(F.extname(file)[1..-1],'unknown')
            size  = (type!='directory' ? (sz<10240 ? "#{sz}B" : "#{sz/1024}KB") : '-')
            mtime = F.mtime(fl).httpdate
            @files << [ url, file, size, type, mtime ]
          end
          return [ 200, {'Content-Type'=>'text/html'}, self ]
        end
      end

      return [404, {"Content-Type" => "text/plain"},
              ["Directory not found: #{env["PATH_INFO"]}\n"]]
    end

    def each
      files = @files.map{|f| p f; DIR_FILE % f }*"\n"
      page  = DIR_PAGE % [ @path, @path , files ]
      page.each_line{|l| yield l }
    end

    def each_entry
      @files.each{|e| yield e }
    end
  end
end

require 'stringio'
require 'time'  # for Time#httpdate
require 'rack/deflater'
require 'rack/mock'
require 'zlib'

describe Rack::Deflater do
  def build_response(status, body, accept_encoding, headers = {})
    body = [body]  if body.respond_to? :to_str
    app = lambda { |env| [status, {}, body] }
    request = Rack::MockRequest.env_for("", headers.merge("HTTP_ACCEPT_ENCODING" => accept_encoding))
    response = Rack::Deflater.new(app).call(request)

    return response
  end

  def inflate(buf)
    inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)
    inflater.inflate(buf) << inflater.finish
  end

  should "be able to deflate bodies that respond to each" do
    body = Object.new
    class << body; def each; yield("foo"); yield("bar"); end; end

    response = build_response(200, body, "deflate")

    response[0].should.equal(200)
    response[1].should.equal({
      "Content-Encoding" => "deflate",
      "Vary" => "Accept-Encoding"
    })
    buf = ''
    response[2].each { |part| buf << part }
    inflate(buf).should.equal("foobar")
  end

  should "flush deflated chunks to the client as they become ready" do
    body = Object.new
    class << body; def each; yield("foo"); yield("bar"); end; end

    response = build_response(200, body, "deflate")

    response[0].should.equal(200)
    response[1].should.equal({
      "Content-Encoding" => "deflate",
      "Vary" => "Accept-Encoding"
    })
    buf = []
    inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)
    response[2].each { |part| buf << inflater.inflate(part) }
    buf << inflater.finish
    buf.delete_if { |part| part.empty? }
    buf.should.equal(%w(foo bar))
  end

  # TODO: This is really just a special case of the above...
  should "be able to deflate String bodies" do
    response = build_response(200, "Hello world!", "deflate")

    response[0].should.equal(200)
    response[1].should.equal({
      "Content-Encoding" => "deflate",
      "Vary" => "Accept-Encoding"
    })
    buf = ''
    response[2].each { |part| buf << part }
    inflate(buf).should.equal("Hello world!")
  end

  should "be able to gzip bodies that respond to each" do
    body = Object.new
    class << body; def each; yield("foo"); yield("bar"); end; end

    response = build_response(200, body, "gzip")

    response[0].should.equal(200)
    response[1].should.equal({
      "Content-Encoding" => "gzip",
      "Vary" => "Accept-Encoding",
    })

    buf = ''
    response[2].each { |part| buf << part }
    io = StringIO.new(buf)
    gz = Zlib::GzipReader.new(io)
    gz.read.should.equal("foobar")
    gz.close
  end

  should "flush gzipped chunks to the client as they become ready" do
    body = Object.new
    class << body; def each; yield("foo"); yield("bar"); end; end

    response = build_response(200, body, "gzip")

    response[0].should.equal(200)
    response[1].should.equal({
      "Content-Encoding" => "gzip",
      "Vary" => "Accept-Encoding"
    })
    buf = []
    inflater = Zlib::Inflate.new(Zlib::MAX_WBITS + 32)
    response[2].each { |part| buf << inflater.inflate(part) }
    buf << inflater.finish
    buf.delete_if { |part| part.empty? }
    buf.should.equal(%w(foo bar))
  end

  should "be able to fallback to no deflation" do
    response = build_response(200, "Hello world!", "superzip")

    response[0].should.equal(200)
    response[1].should.equal({ "Vary" => "Accept-Encoding" })
    response[2].should.equal(["Hello world!"])
  end

  should "be able to skip when there is no response entity body" do
    response = build_response(304, [], "gzip")

    response[0].should.equal(304)
    response[1].should.equal({})
    response[2].should.equal([])
  end

  should "handle the lack of an acceptable encoding" do
    response1 = build_response(200, "Hello world!", "identity;q=0", "PATH_INFO" => "/")
    response1[0].should.equal(406)
    response1[1].should.equal({"Content-Type" => "text/plain", "Content-Length" => "71"})
    response1[2].should.equal(["An acceptable encoding for the requested resource / could not be found."])

    response2 = build_response(200, "Hello world!", "identity;q=0", "SCRIPT_NAME" => "/foo", "PATH_INFO" => "/bar")
    response2[0].should.equal(406)
    response2[1].should.equal({"Content-Type" => "text/plain", "Content-Length" => "78"})
    response2[2].should.equal(["An acceptable encoding for the requested resource /foo/bar could not be found."])
  end

  should "handle gzip response with Last-Modified header" do
    last_modified = Time.now.httpdate

    app = lambda { |env| [200, { "Last-Modified" => last_modified }, ["Hello World!"]] }
    request = Rack::MockRequest.env_for("", "HTTP_ACCEPT_ENCODING" => "gzip")
    response = Rack::Deflater.new(app).call(request)

    response[0].should.equal(200)
    response[1].should.equal({
      "Content-Encoding" => "gzip",
      "Vary" => "Accept-Encoding",
      "Last-Modified" => last_modified
    })

    buf = ''
    response[2].each { |part| buf << part }
    io = StringIO.new(buf)
    gz = Zlib::GzipReader.new(io)
    gz.read.should.equal("Hello World!")
    gz.close
  end

  should "do nothing when no-transform Cache-Control directive present" do
    app = lambda { |env| [200, {'Cache-Control' => 'no-transform'}, ['Hello World!']] }
    request = Rack::MockRequest.env_for("", "HTTP_ACCEPT_ENCODING" => "gzip")
    response = Rack::Deflater.new(app).call(request)

    response[0].should.equal(200)
    response[1].should.not.include "Content-Encoding"
    response[2].join.should.equal("Hello World!")
  end

  should "check Content-Type is suitable for deflate" do
    # if Rack::Mime::MIME_TYPES changed, it would be tedious to check and update content_type_deflate_expectation
    content_type_deflate_expectation = {
      "application/vnd.yamaha.smaf-audio" => false,
      "text/vnd.in3d.spot" => true,
      "application/marc" => true,
      "application/vnd.acucobol" => false,
      "text/x-pascal" => true,
      "application/vnd.hydrostatix.sof-data" => false,
      "image/gif" => false,
      "text/vnd.wap.wmlscript" => true,
      "image/x-rgb" => false,
      "application/oda" => true,
      "application/vnd.shana.informed.interchange" => false,
      "application/vnd.grafeq" => false,
      "application/vnd.kde.karbon" => false,
      "application/vnd.novadigm.edx" => false,
      "application/x-mswrite" => false,
      "application/x-chat" => false,
      "image/vnd.ms-modi" => false,
      "application/x-msmoney" => false,
      "application/x-pkcs7-certreqresp" => false,
      "application/vnd.oasis.opendocument.chart-template" => false,
      "application/vnd.sus-calendar" => false,
      "application/vnd.kinar" => false,
      "chemical/x-pdb" => true,
      "application/vnd.kenameaapp" => false,
      "application/vnd.gmx" => false,
      "application/srgs" => true,
      "application/vnd.pocketlearn" => false,
      "application/vnd.mseq" => false,
      "application/vnd.trid.tpt" => false,
      "application/vnd.previewsystems.box" => false,
      "application/x-ms-wmz" => false,
      "application/vnd.vsf" => false,
      "video/x-flv" => false,
      "application/vnd.mcd" => false,
      "application/set-registration-initiation" => true,
      "application/xml" => true,
      "application/x-tex" => false,
      "application/xop+xml" => true,
      "application/vnd.ms-excel" => false,
      "video/mp4" => false,
      "application/vnd.ms-wpl" => false,
      "application/vnd.kidspiration" => false,
      "application/vnd.ms-ims" => false,
      "application/x-shockwave-flash" => false,
      "application/vnd.novadigm.ext" => false,
      "application/reginfo+xml" => true,
      "model/mesh" => true,
      "image/x-cmx" => false,
      "application/vnd.crick.clicker.palette" => false,
      "video/x-sgi-movie" => false,
      "application/x-msschedule" => false,
      "application/resource-lists-diff+xml" => true,
      "application/x-hdf" => false,
      "application/vnd.cosmocaller" => false,
      "application/vnd.fujitsu.oasys" => false,
      "chemical/x-cdx" => true,
      "application/vnd.solent.sdkm+xml" => true,
      "image/x-portable-bitmap" => false,
      "application/vnd.macports.portpkg" => false,
      "application/x-debian-package" => false,
      "application/vnd.ctc-posml" => false,
      "text/yaml" => true,
      "application/vnd.oasis.opendocument.text-template" => false,
      "video/vnd.fvt" => false,
      "audio/mpeg" => false,
      "application/vnd.framemaker" => false,
      "application/mp4" => false,
      "application/andrew-inset" => true,
      "application/voicexml+xml" => true,
      "application/vnd.micrografx.igx" => false,
      "application/x-redhat-package-manager" => false,
      "video/x-ms-wmv" => false,
      "application/vnd.lotus-approach" => false,
      "text/uri-list" => true,
      "application/vnd.mfmp" => false,
      "application/vnd.oasis.opendocument.image" => false,
      "application/vnd.pg.format" => false,
      "application/vnd.kahootz" => false,
      "video/x-ms-wmx" => false,
      "application/vnd.svd" => false,
      "application/vnd.llamagraphics.life-balance.exchange+xml" => true,
      "application/vnd.amiga.ami" => false,
      "application/vnd.ms-htmlhelp" => false,
      "application/vnd.yamaha.hv-dic" => false,
      "image/vnd.djvu" => false,
      "application/vnd.ms-cab-compressed" => false,
      "application/vnd.dna" => false,
      "application/vnd.ms-lrm" => false,
      "application/vnd.oasis.opendocument.spreadsheet-template" => false,
      "image/x-pcx" => false,
      "application/relax-ng-compact-syntax" => true,
      "text/vnd.sun.j2me.app-descriptor" => true,
      "application/atomsvc+xml" => true,
      "application/x-tcl" => false,
      "application/x-stuffitx" => false,
      "application/vnd.irepository.package+xml" => true,
      "application/vnd.hp-hpid" => false,
      "audio/basic" => false,
      "video/3gpp" => false,
      "application/x-msmediaview" => false,
      "application/vnd.recordare.musicxml" => true,
      "application/vnd.ezpix-package" => false,
      "application/x-msbinder" => false,
      "application/winhlp" => true,
      "text/x-fortran" => true,
      "application/vnd.intu.qbo" => false,
      "text/vnd.in3d.3dml" => true,
      "application/pgp-signature" => true,
      "application/vnd.proteus.magazine" => false,
      "application/scvp-vp-request" => true,
      "application/x-bzip" => false,
      "application/vnd.ms-xpsdocument" => false,
      "image/svg+xml" => false,
      "image/bmp" => false,
      "audio/x-ms-wax" => false,
      "application/vnd.chemdraw+xml" => true,
      "application/x-pkcs7-certificates" => false,
      "application/x-chess-pgn" => false,
      "application/vnd.jam" => false,
      "application/x-bzip2" => false,
      "application/vnd.enliven" => false,
      "application/vnd.3gpp.pic-bw-large" => false,
      "application/vnd.fsc.weblaunch" => false,
      "application/vnd.spotfire.sfs" => false,
      "application/vnd.3m.post-it-notes" => false,
      "application/vnd.koan" => false,
      "application/vnd.hp-pcl" => false,
      "application/vnd.ibm.secure-container" => false,
      "application/xml-dtd" => true,
      "model/vnd.gdl" => true,
      "application/vnd.groove-tool-message" => false,
      "video/ogg" => false,
      "application/vnd.lotus-freelance" => false,
      "application/vnd.mobius.dis" => false,
      "application/vnd.epson.salt" => false,
      "application/vnd.dolby.mlp" => false,
      "video/x-ms-wm" => false,
      "application/pgp-encrypted" => true,
      "application/vnd.ms-project" => false,
      "video/h261" => false,
      "application/vnd.ipunplugged.rcprofile" => false,
      "application/x-x509-ca-cert" => false,
      "x-conference/x-cooltalk" => true,
      "image/g3fax" => false,
      "audio/vnd.nuera.ecelp4800" => false,
      "video/h263" => false,
      "application/x-rar-compressed" => false,
      "application/vnd.lotus-screencam" => false,
      "application/vnd.dpgraph" => false,
      "video/h264" => false,
      "application/ogg" => false,
      "application/x-bzip-compressed-tar" => false,
      "image/vnd.fpx" => false,
      "application/vnd.crick.clicker" => false,
      "application/vnd.kodak-descriptor" => false,
      "application/font-tdpfr" => true,
      "application/vnd.groove-injector" => false,
      "text/x-uuencode" => true,
      "application/vnd.antix.game-component" => false,
      "application/vnd.apple.installer+xml" => true,
      "model/vnd.vtu" => true,
      "application/vnd.blueice.multipass" => false,
      "application/sbml+xml" => true,
      "audio/x-mpegurl" => false,
      "application/vnd.contact.cmsg" => false,
      "image/pict" => false,
      "application/x-cdlink" => false,
      "application/vnd.kde.kspread" => false,
      "application/vnd.tmobile-livetv" => false,
      "application/resource-lists+xml" => true,
      "application/vnd.kde.kontour" => false,
      "application/vnd.hp-jlyt" => false,
      "application/vnd.oma.dd2+xml" => true,
      "application/vnd.jcp.javame.midlet-rms" => false,
      "application/vnd.chipnuts.karaoke-mmd" => false,
      "application/vnd.fujixerox.docuworks.binder" => false,
      "application/vnd.oasis.opendocument.formula-template" => false,
      "video/quicktime" => false,
      "application/vnd.unity" => false,
      "application/vnd.crick.clicker.wordbank" => false,
      "application/pkix-crl" => true,
      "application/vnd.anser-web-certificate-issue-initiation" => false,
      "application/mac-compactpro" => true,
      "audio/mp4a-latm" => false,
      "application/lost+xml" => true,
      "application/vnd.clonk.c4group" => false,
      "chemical/x-xyz" => true,
      "application/scvp-cv-response" => true,
      "video/webm" => false,
      "application/vnd.nokia.n-gage.data" => false,
      "application/vnd.openofficeorg.extension" => false,
      "application/vnd.fujixerox.ddd" => false,
      "application/vnd.oasis.opendocument.text" => false,
      "video/vnd.ms-playready.media.pyv" => false,
      "application/x-stuffit" => false,
      "application/json" => true,
      "audio/vnd.digital-winds" => false,
      "image/png" => false,
      "application/x-mspublisher" => false,
      "application/vnd.yamaha.hv-script" => false,
      "application/vnd.frogans.ltf" => false,
      "application/vnd.yamaha.hv-voice" => false,
      "application/java-archive" => false,
      "application/vnd.tao.intent-module-archive" => false,
      "application/x-ustar" => false,
      "application/vnd.ibm.rights-management" => false,
      "application/vnd.oasis.opendocument.text-web" => false,
      "application/x-tar" => false,
      "application/vnd.curl" => false,
      "text/richtext" => true,
      "application/vnd.immervision-ivp" => false,
      "application/vnd.bmi" => false,
      "application/x-wais-source" => false,
      "video/jpm" => false,
      "image/x-portable-anymap" => false,
      "text/x-diff" => true,
      "application/patch-ops-error+xml" => true,
      "application/vnd.hp-hpgl" => false,
      "application/ecmascript" => true,
      "application/set-payment-initiation" => true,
      "application/vnd.acucorp" => false,
      "application/vnd.mobius.txf" => false,
      "application/vnd.3gpp.pic-bw-small" => false,
      "application/vnd.oasis.opendocument.graphics" => false,
      "application/vnd.nokia.n-gage.symbian.install" => false,
      "application/vnd.immervision-ivu" => false,
      "application/vnd.pvi.ptid1" => false,
      "application/vnd.ms-fontobject" => false,
      "application/rsd+xml" => true,
      "application/vnd.picsel" => false,
      "text/x-vcard" => true,
      "application/vnd.palm" => false,
      "image/cgm" => false,
      "application/vnd.intercon.formnet" => false,
      "application/x-java-jnlp-file" => false,
      "application/vnd.ufdl" => false,
      "application/vnd.wap.wmlscriptc" => false,
      "application/vnd.lotus-organizer" => false,
      "image/prs.btif" => false,
      "application/smil+xml" => true,
      "image/vnd.fst" => false,
      "application/vnd.triscape.mxs" => false,
      "application/mediaservercontrol+xml" => true,
      "audio/x-pn-realaudio-plugin" => false,
      "application/pkcs10" => true,
      "application/pkcs7-signature" => true,
      "image/tiff" => false,
      "application/vnd.is-xpr" => false,
      "image/vnd.adobe.photoshop" => false,
      "application/vnd.ecowin.chart" => false,
      "application/vnd.eszigno3+xml" => true,
      "text/x-script.perl" => true,
      "application/postscript" => false,
      "model/vrml" => true,
      "application/x-gtar" => false,
      "application/vnd.ms-powerpoint" => false,
      "application/x-netcdf" => false,
      "application/vnd.mif" => false,
      "application/vnd.oasis.opendocument.chart" => false,
      "application/davmount+xml" => true,
      "application/vnd.jisp" => false,
      "application/vnd.hbci" => false,
      "application/vnd.google-earth.kml+xml" => true,
      "application/ccxml+xml" => true,
      "application/vnd.hzn-3d-crossword" => false,
      "application/vnd.groove-account" => false,
      "image/x-quicktime" => false,
      "application/xspf+xml" => true,
      "application/vnd.groove-vcard" => false,
      "image/jpeg" => false,
      "application/vnd.commonspace" => false,
      "application/vnd.dreamfactory" => false,
      "application/vnd.flographit" => false,
      "application/vnd.epson.msf" => false,
      "application/vnd.genomatix.tuxedo" => false,
      "application/pkixcmp" => true,
      "application/vnd.ezpix-album" => false,
      "image/jp2" => false,
      "text/tab-separated-values" => true,
      "audio/vnd.nuera.ecelp7470" => false,
      "application/vnd.yellowriver-custom-menu" => false,
      "application/vnd.fluxtime.clip" => false,
      "application/atom+xml" => true,
      "application/vnd.pg.osasli" => false,
      "application/vnd.smaf" => false,
      "application/vnd.mobius.msl" => false,
      "application/scvp-vp-response" => true,
      "image/vnd.fastbidsheet" => false,
      "application/vnd.oasis.opendocument.presentation" => false,
      "application/vnd.fdf" => false,
      "application/vnd.nokia.radio-presets" => false,
      "audio/vnd.ms-playready.media.pya" => false,
      "image/x-macpaint" => false,
      "application/vnd.kde.kpresenter" => false,
      "video/x-msvideo" => false,
      "application/sparql-query" => true,
      "image/vnd.dwg" => false,
      "application/vnd.wap.wbxml" => true,
      "application/vnd.igloader" => false,
      "application/vnd.accpac.simply.aso" => false,
      "application/x-sv4crc" => false,
      "application/x-dvi" => false,
      "application/vnd.arastra.swi" => false,
      "application/vnd.noblenet-sealer" => false,
      "application/vnd.publishare-delta-tree" => false,
      "application/vnd.zzazz.deck+xml" => true,
      "text/troff" => true,
      "application/vnd.3gpp2.tcap" => false,
      "application/vnd.osgi.dp" => false,
      "application/pkcs7-mime" => true,
      "audio/vnd.nuera.ecelp9600" => false,
      "application/rss+xml" => true,
      "application/vnd.webturbo" => false,
      "audio/x-wav" => false,
      "application/xhtml+xml" => true,
      "application/mac-binhex40" => true,
      "application/pics-rules" => true,
      "application/vnd.simtech-mindmapper" => false,
      "audio/x-aiff" => false,
      "application/vnd.adobe.xdp+xml" => true,
      "application/vnd.hp-pclxl" => false,
      "audio/x-pn-realaudio" => false,
      "application/vnd.xfdl" => false,
      "video/mj2" => false,
      "application/vnd.shana.informed.formtemplate" => false,
      "application/ssml+xml" => true,
      "chemical/x-cml" => true,
      "application/vnd.kde.kword" => false,
      "text/x-setext" => true,
      "application/rtf" => true,
      "application/vnd.fujitsu.oasys2" => false,
      "text/css" => true,
      "image/vnd.fujixerox.edmics-rlc" => false,
      "application/vnd.ms-artgalry" => false,
      "application/wspolicy+xml" => true,
      "application/x-msdownload" => false,
      "text/calendar" => true,
      "application/vnd.umajin" => false,
      "application/vnd.fujitsu.oasys3" => false,
      "image/vnd.fujixerox.edmics-mmr" => false,
      "application/hyperstudio" => true,
      "application/vnd.nokia.radio-preset" => false,
      "application/vnd.groove-help" => false,
      "text/prs.lines.tag" => true,
      "application/vnd.anser-web-funds-transfer-initiation" => false,
      "application/mbox" => true,
      "text/csv" => true,
      "text/plain" => true,
      "video/x-mng" => false,
      "application/vnd.noblenet-directory" => false,
      "application/mathematica" => true,
      "application/x-csh" => false,
      "application/vnd.ibm.minipay" => false,
      "application/atomcat+xml" => true,
      "application/vnd.mobius.mbk" => false,
      "audio/vnd.lucent.voice" => false,
      "application/vnd.syncml+xml" => true,
      "application/vnd.medcalcdata" => false,
      "application/vnd.oasis.opendocument.formula" => false,
      "application/vnd.kde.kivio" => false,
      "text/x-component" => true,
      "application/vnd.xara" => false,
      "image/x-portable-graymap" => false,
      "application/xslt+xml" => true,
      "application/vnd.seemail" => false,
      "image/x-pict" => false,
      "application/x-pkcs12" => false,
      "application/vnd.criticaltools.wbs+xml" => true,
      "application/vnd.americandynamics.acc" => false,
      "application/x-msclip" => false,
      "application/vnd.neurolanguage.nlu" => false,
      "application/vnd.joost.joda-archive" => false,
      "application/vnd.quark.quarkxpress" => false,
      "application/vnd.3gpp.pic-bw-var" => false,
      "application/pkix-pkipath" => true,
      "image/vnd.wap.wbmp" => false,
      "text/x-vcalendar" => true,
      "application/vnd.cups-ppd" => false,
      "text/cache-manifest" => true,
      "application/vnd.frogans.fnc" => false,
      "video/jpeg" => false,
      "text/vnd.wap.wml" => true,
      "application/vnd.fuzzysheet" => false,
      "application/vnd.route66.link66+xml" => true,
      "audio/vnd.dts" => false,
      "text/x-java-source" => true,
      "application/vnd.vcx" => false,
      "application/vnd.visionary" => false,
      "application/sparql-results+xml" => true,
      "application/mxf" => true,
      "application/srgs+xml" => true,
      "text/x-script.ruby" => true,
      "text/vnd.graphviz" => true,
      "application/vnd.groove-tool-template" => false,
      "application/vnd.kde.kchart" => false,
      "application/vnd.sema" => false,
      "application/vnd.ms-works" => false,
      "application/vnd.fujitsu.oasysgp" => false,
      "application/vnd.llamagraphics.life-balance.desktop" => false,
      "application/vnd.olpc-sugar" => false,
      "application/vnd.crick.clicker.keyboard" => false,
      "application/vnd.epson.ssf" => false,
      "image/x-cmu-raster" => false,
      "text/vnd.fmi.flexstor" => true,
      "application/pdf" => false,
      "model/vnd.dwf" => true,
      "application/vnd.mobius.plc" => false,
      "message/rfc822" => true,
      "application/prs.cww" => true,
      "chemical/x-csml" => true,
      "video/x-dv" => false,
      "application/vnd.semd" => false,
      "application/vnd.muvee.style" => false,
      "application/vnd.wordperfect" => false,
      "application/shf+xml" => true,
      "application/vnd.accpac.simply.imp" => false,
      "application/vnd.groove-identity-message" => false,
      "video/x-ms-wvx" => false,
      "application/vnd.semf" => false,
      "application/octet-stream" => false,
      "application/vnd.powerbuilder6" => false,
      "text/sgml" => true,
      "image/x-xpixmap" => false,
      "model/vnd.gtw" => true,
      "audio/vnd.dts.hd" => false,
      "image/vnd.xiff" => false,
      "application/vnd.epson.quickanime" => false,
      "application/vnd.claymore" => false,
      "text/x-script.python" => true,
      "application/x-futuresplash" => false,
      "application/pls+xml" => true,
      "application/pkix-cert" => true,
      "application/vnd.wap.wmlc" => false,
      "audio/midi" => false,
      "application/vnd.oasis.opendocument.graphics-template" => false,
      "text/vnd.fly" => true,
      "application/x-bcpio" => false,
      "image/ief" => false,
      "text/x-script.perl-module" => true,
      "application/vnd.uiq.theme" => false,
      "application/vnd.shana.informed.formdata" => false,
      "application/vnd.data-vision.rdz" => false,
      "application/vnd.oasis.opendocument.spreadsheet" => false,
      "application/xenc+xml" => true,
      "application/wsdl+xml" => true,
      "application/vnd.lotus-wordpro" => false,
      "application/vnd.fujixerox.docuworks" => false,
      "audio/mp4" => false,
      "application/vnd.ibm.modcap" => false,
      "application/vnd.google-earth.kmz" => false,
      "application/vnd.lotus-notes" => false,
      "application/vnd.denovo.fcselayout-link" => false,
      "application/vnd.handheld-entertainment+xml" => true,
      "application/vnd.syncml.dm+wbxml" => true,
      "application/x-msmetafile" => false,
      "application/vnd.mobius.mqy" => false,
      "application/vnd.adobe.xfdf" => false,
      "video/vnd.vivo" => false,
      "application/vnd.rn-realmedia" => false,
      "chemical/x-cmdf" => true,
      "application/x-cpio" => false,
      "application/x-mscardfile" => false,
      "application/vnd.syncml.dm+xml" => true,
      "application/vnd.wt.stf" => false,
      "model/iges" => true,
      "application/vnd.crick.clicker.template" => false,
      "text/x-asm" => true,
      "application/vnd.intu.qfx" => false,
      "image/vnd.net-fpx" => false,
      "application/x-director" => false,
      "audio/x-ms-wma" => false,
      "application/x-msaccess" => false,
      "video/3gpp2" => false,
      "text/html" => true,
      "application/x-ms-wmd" => false,
      "image/x-xwindowdump" => false,
      "application/vnd.yamaha.smaf-phrase" => false,
      "application/javascript" => false,
      "application/vnd.mophun.certificate" => false,
      "application/zip" => false,
      "application/vnd.fujitsu.oasysprs" => false,
      "application/vnd.musician" => false,
      "application/x-shar" => false,
      "application/vnd.mobius.daf" => false,
      "image/x-xbitmap" => false,
      "application/vnd.cinderella" => false,
      "application/rdf+xml" => true,
      "application/vnd.businessobjects" => false,
      "image/vnd.microsoft.icon" => false,
      "application/x-ace-compressed" => false,
      "application/vnd.hp-hps" => false,
      "application/vnd.epson.esf" => false,
      "application/x-gzip" => false,
      "application/vnd.mfer" => false,
      "application/x-latex" => false,
      "application/x-sv4cpio" => false,
      "application/vnd.spotfire.dxp" => false,
      "application/x-texinfo" => false,
      "application/vnd.wqd" => false,
      "application/vnd.mediastation.cdkey" => false,
      "application/vnd.novadigm.edm" => false,
      "application/vnd.kde.kformula" => false,
      "application/vnd.lotus-1-2-3" => false,
      "application/scvp-cv-request" => true,
      "application/vnd.noblenet-web" => false,
      "application/vnd.hhe.lesson-player" => false,
      "video/x-fli" => false,
      "application/vnd.shana.informed.package" => false,
      "application/sdp" => true,
      "application/vnd.mophun.application" => false,
      "application/vnd.oasis.opendocument.image-template" => false,
      "application/x-msterminal" => false,
      "text/x-c" => true,
      "chemical/x-cif" => true,
      "application/vnd.visio" => false,
      "application/msword" => true,
      "application/x-sh" => false,
      "image/x-portable-pixmap" => false,
      "application/vnd.uoml+xml" => true,
      "model/vnd.mts" => true,
      "video/x-ms-asf" => false,
      "video/vnd.mpegurl" => false,
      "image/vnd.dxf" => false,
      "application/xv+xml" => true,
      "application/vnd.trueapp" => false,
      "video/mpeg" => false,
      "application/vnd.micrografx.flo" => false,
      "application/x-bittorrent" => false,
      "application/vnd.oasis.opendocument.text-master" => false,
      "application/mathml+xml" => true,
      "application/vnd.audiograph" => false,
      "audio/ogg" => false,
      "application/rls-services+xml" => true,
      "application/vnd.iccprofile" => false,
      "application/vnd.mozilla.xul+xml" => true
    }
    content_type_check_result = {}
    app = lambda { |env| [status, {}, body] }
    deflater = Rack::Deflater.new(app)
    Rack::Mime::MIME_TYPES.values.map { |mime|
      content_type_check_result[mime] = deflater.deflate_type?(mime)
    }
    content_type_check_result.should.equal(content_type_deflate_expectation)
  end
end

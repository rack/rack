#\ -d

options :recv => "tcp://*:6767", :ssid => "myone"
option  :send => "ipc:///socket.ipc"

run lambda { |env| [200, {'Content-Type' => 'text/plain'}, ['OK']] }

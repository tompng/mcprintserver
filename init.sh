#!/bin/sh
# chkconfig: 345 98 20
# description: mcprintserver
# processname: mcprintserver

export HOME=/home/ec2-user
source /home/ec2-user/.bash_profile
cd /home/ec2-user/mcprintserver
start(){
  if pgrep -f "ruby server.rb"
  then
    'already started'
  else
    nohup ruby server.rb > /dev/null &
  fi
}
stop(){
  if pgrep -f ruby.server.rb
  then
    kill -INT `pgrep -f "ruby server.rb"`
    kill -INT `pgrep -f java`
    sleep 2
    kill -KILL `pgrep -f "ruby server.rb"`
    kill -KILL `pgrep -f java`
  fi
}
test $1 = "start" && start
test $1 = "stop" && stop

# sudo cp init.sh /etc/init.d/mcprintserver
# sudo chmod +x /etc/init.d/mcprintserver
# sudo chkconfig --add mcprintserver
# service mcprintserver start

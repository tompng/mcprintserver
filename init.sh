#!/bin/sh
# chkconfig: 345 98 20
# description: mcprintserver
# processname: mcprintserver

export HOME=/home/ec2-user
source /home/ec2-user/.bash_profile
cd /home/ec2-user/mcprintserver
test $1 = "start" && nohup ruby server.rb > /dev/null &

# sudo cp init.sh /etc/init.d/mcprintserver
# sudo chmod +x /etc/init.d/mcprintserver
# chkconfig --add mcprintserver
# service mcprintserver start

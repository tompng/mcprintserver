#! /bin/sh
# install git ruby
yum install -y git gcc gcc-c++ openssl-devel readline-devel
git clone git://github.com/sstephenson/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile
echo 'eval "$(rbenv init -)"' >> ~/.bash_profile
exec $SHELL -l
git clone git://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
rbenv install 2.3.0
rbenv global 2.3.0
gem install bundler

git clone https://github.com/tompng/mcprintserver.git
cd mcprintserver

# build spigot
mkdir spigot
mkdir spigot_build
cd spigot_build
curl https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar > BuildTools.jar
java -jar BuildTools.jar
mv spigot*.jar ../spigot
cd ../spigot
java -jar spigot*.jar
sed -i -e "s/eula=false/eula=true/" eula.txt
rm eula.txt-e

# install worldedit worldguard
mkdir plugins
curl -L 'https://dev.bukkit.org/projects/worldedit/files/latest' -H 'User-Agent: Mozilla/5.0' > plugins/worldedit.jar
curl -L 'https://dev.bukkit.org/projects/worldguard/files/latest' -H 'User-Agent: Mozilla/5.0' > plugins/worldguard.jar

cp server.properties spigot/server.properties

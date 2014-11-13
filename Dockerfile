# Builds an OpenSuse 12 based docker with a fully working Synthese server using MySQL
# Dev tools installed

# MySQL root password : synthese_root
# MySQL synthese password : synthese
# root password : toto

FROM opensuse12-distcc
MAINTAINER Bastien Noverraz (TL)

# Install necessary librairies
RUN \
	zypper --non-interactive --no-gpg-checks install -y --auto-agree-with-licenses \
	wget pv unzip mariadb libopenssl0_9_8 glibc-locale sudo cmake make nano ccache \
	libbz2-devel zlib-devel libcurl-devel libpng12-devel gdb gdbserver libapr1-devel \
	libapr-util1-devel libmysqlclient-devel sqlite3 sqlite3-devel automake  libtool \
	 && \
	zypper clean
	
# Boost 1.42 install and build
RUN \
	wget "http://downloads.sourceforge.net/project/boost/boost/1.42.0/boost_1_42_0.tar.bz2?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fboost%2Ffiles%2Fboost%2F1.42.0%2F&ts=1403096902&use_mirror=cznic" -O /tmp/boost.tar.bz2  && \
	tar xjf /tmp/boost.tar.bz2 -C /opt/  && \
	cd /opt/boost_1_42_0 && \
	sed -i 's/TIME_UTC/TIME_UTC_/g' boost/thread/xtime.hpp && \
	sed -i 's/TIME_UTC/TIME_UTC_/g' libs/thread/src/pthread/timeconv.inl && \
	./bootstrap.sh --prefix=./dist --with-libraries=program_options,iostreams,test,date_time,filesystem,system,regex,thread && \
	./bjam -j4 install

# Subversion is needed for the compilation...
# Using a more recent version than the default one
RUN \
	wget http://mirror.switch.ch/mirror/apache/dist/subversion/subversion-1.8.10.tar.bz2 -O /tmp/subversion.tar.bz2 && \
	tar xjf /tmp/subversion.tar.bz2 -C /opt/ && \
	wget http://www.sqlite.org/sqlite-amalgamation-3071501.zip -O /tmp/sqlite-amalgamation.zip && \
	unzip /tmp/sqlite-amalgamation.zip -d /tmp && \
	mv /tmp/sqlite-amalgamation-3071501 /opt/subversion-1.8.10/sqlite-amalgamation && \
	cd /opt/subversion-1.8.10 && \
	./configure --prefix=/usr && \
	make -j$(distcc -j) && \
	make install && \
	rm -rf /opt/subversion-1.8.10

# Set rights
RUN \
	useradd synthese && \
	touch /var/log/synthese.log && \
	chown synthese:users /var/log/synthese.log

# MySQL setup & UDF plugin
RUN \
	sed -i 's|max_allowed_packet = 1M|max_allowed_packet	= 512M|g' /etc/my.cnf && \
	sed -i 's|/var/run/mysql/mysql.sock|/var/lib/mysql/mysql.sock|g' /etc/my.cnf && \
	/etc/init.d/mysql start && \
	mysql -u root -e "CREATE DATABASE synthese;" && \
	mysql -u root -e "CREATE DATABASE bdsi;" && \
	mysql -u root -e "grant all privileges on *.* to synthese@localhost identified by 'synthese';" && \
	mysql -u root -e "grant all privileges on *.* to root@'%';" && \
	mysql -u root -e "UPDATE mysql.user SET Password=PASSWORD('synthese_root') WHERE User='root'; FLUSH PRIVILEGES;" && \
	cp /opt/synthese/lib/mysql_udf_plugin/libsynthese_mysql_udf.so /usr/lib64/mysql/plugin/synthese_mysql_udf.so && \
	mysql -u root -psynthese_root mysql < /opt/synthese/share/synthese/mysql_udf_plugin/trigger_udf.sql && \
	ln -s /var/lib/mysql/mysql.sock /var/run/mysql/mysql.sock && \
	/etc/init.d/mysql stop

# Run the SSH server once so that it creates its keys
RUN /etc/init.d/sshd start

# Setup the root password
RUN echo root:toto | chpasswd

# Use our starter by default
ENTRYPOINT ["/opt/bin/env.sh"]

# By default, start bash
CMD bash

# Move the old env.sh script
RUN mv /opt/bin/{env,distcc}.sh && chmod +x /opt/bin/distcc.sh

# Create the source directory
RUN mkdir -p /src/synthese

# Add our own script to the path
ENV PATH $PATH:/opt/bin

# Add our starter and our builder
ADD env.sh /opt/bin/env.sh
ADD build.sh /opt/bin/build.sh

#!/bin/bash

# Startup script for Synthese
#
# This script is able to run, install and load synthese and its databases.


# Default args for s3-server
DEFAULT_ARGS="--dbconn mysql://host=localhost,user=synthese,passwd=synthese,db=synthese --pidfile - --param node_id=100 --param log_level=0 --param port=8080"
# Path for files
DATA="/src/synthese/data"
# Source directory
SRC="/src/synthese"

# Print the help & usage
function help ()
{
	echo "OpenSuse 12.3 docker for Synthese"
	echo ""
	echo "Note : all path are relative from $DATA inside the docker"
	echo "To map the docker instance's $DATA to a local directory outside the docker instance use :"
	echo "docker run -i -t -v /absolute/local/path:$DATA ..."
	echo ""
	echo -e "
Usage : 
help \t\t Show this help message 
db=XXX \t\t Load this synthese database at start 
bdsi=XXX \t Load this BDSI database at start 
install=XXX \t Install the Synthese software from this file (tar.bz2 or tar.gz) 
autoload \t If this flag is given, the synthese database will be loaded from $DATA/synthese.sql, the bdsi from $DATA/bdsi.sql and the executable from $DATA/synthese.tar.bz2. Any file not found will be ignored.
bash \t\t Will run /bin/bash instead of synthese, ignoring every other parameters
run XXX \t Will run the arguments as an exectuable and its parameters 
gdb \t\t Will run Synthese under GDB
save=XXX\t Will save the database after s3-server is stopped to $DATA/XXX
data=XXX\t Change the $DATA directory
icecc_master=XXX\t Use this IP as master for the Icecc network
icecc_password=XXX\t Use this password for the Icecc network

All the other parameters will be directly passed to the s3-server executable.
If no arguments are given for s3-server, the default one will be used : 
$DEFAULT_ARGS
"

echo -e "
Examples :

Run a simple hello world instead of Synthese :
run echo hello world

Run synthese with default parameters (use mysql connexion):
(no arguments)

Run a specific Synthese executable with the specified database (which are in $DATA):
install=synthese.tar.bz2 db=synthese.sql
"
}


INSTALL=""
DB=""
BDSI=""
AUTOLOAD=""
ARGS=""
GDB=""
SAVE=""
RUN=""
MASTER=""
PASSWORD=""

# Parse the arguments
cnt=0
for a in $*; do

	case "$a" in
		"help" )
			help
			exit 0;;
		"bash" )
			RUN="/bin/bash"
			;;
		"run" )
			RUN="${*:$((cnt+2))}"
			;;
		
		db* )
			DB=${a:3} ;;
		bdsi* )
			BDSI=${a:5} ;;
		save* )
			SAVE=${a:5} ;;
		data* )
			DATA=${a:5} ;;
		install* )
			INSTALL=${a:8} ;;
		icecc_master* )
			MASTER=${a:13} ;;
		icecc_password* )
			PASSWORD=${a:15} ;;
		autoload )
			AUTOLOAD="1" ;;
		gdb )
			GDB="gdb -ex run --args" ;;
			
		* )
			ARGS="$ARGS $a" ;;
	esac
	
	cnt=$((cnt+1))
	
done



# If the autoload option is given, search for the default files
if [[ $AUTOLOAD == "1" ]]; then
	echo "Autoload enabled, searching in $DATA"
	[[ -s "$DATA/synthese.tar.bz2" ]] && INSTALL="synthese.tar.bz2"
	[[ -s "$DATA/synthese.sql" ]] && DB="synthese.sql"
	[[ -s "$DATA/bdsi.sql" ]] && BDSI="bdsi.sql"
fi

# Start MySQL & SSH
/etc/init.d/sshd start
/etc/init.d/mysql start

# Start VPN and distcc if the master and password have been given
if [[ $PASSWORD != "" && $MASTER != "" ]]; then
	
	echo "Starting the Distcc network"
	/opt/bin/distcc.sh auto $MASTER $PASSWORD

else # If no distcc is used, disable it
	export DISTCC_HOSTS="localhost"
fi

# DB given, load it
if [[ $DB != "" ]]; then
	echo "Loading synthese database $DATA/$DB"
	pv "$DATA/$DB" | mysql -psynthese_root synthese
fi

# DBSI given, load it
if [[ $BDSI != "" ]]; then
	echo "Loading bdsi database $DATA/$BDSI"
	pv "$DATA/$BDSI" | mysql -psynthese_root bdsi
fi

# Install if asked
if [[ $INSTALL != "" ]]; then
	echo "Installing Synthese from $DATA/$INSTALL"
	rm -rf /opt/synthese
	tar xf "$DATA/$INSTALL" -C /opt/
	
	# If the synthese directory is prefixed, add a link
	DIRNAME=$(ls /opt | grep synthese)
	if [[ $DIRNAME != "synthese" ]]; then
		echo "Adding a link from $DIRNAME to synthese"
		ln -s /opt/$DIRNAME /opt/synthese
	fi
fi

# If a run is specified, run it instead of Synthese
if [[ "$RUN" != "" ]]; then
	cd "$SRC"
	$RUN
	exit 0
fi

# If no arguments are given, use the default ones
[[ $ARGS == "" ]] && ARGS="$DEFAULT_ARGS"

# Run Synthese
echo ""
echo "Running Synthese version $(/opt/synthese/bin/s3-server --version) with arguments :"
echo $ARGS
echo ""
$GDB /opt/synthese/bin/s3-server $ARGS

# If the save option is specified, backup the database
if [[ $SAVE != "" ]]; then
	echo "Dumping the database to $DATA/$SAVE"
	mysqldump -u root -psynthese_root synthese | pv > "$DATA/$SAVE"
fi

# Stop MySQL if we ever go here
/etc/init.d/mysql stop
/etc/init.d/sshd stop

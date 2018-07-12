# trittium masternode install script
# Edited by Robbowz
VERSION="0.1"
NODEPORT='30001'
RPCPORT='30002'

# Useful variables
declare -r DATE_STAMP="$(date +%y-%m-%d-%s)"
declare -r SCRIPT_LOGFILE="/tmp/trittium_node_${DATE_STAMP}_out.log"
declare -r SCRIPTPATH=$( cd $(dirname ${BASH_SOURCE[0]}) > /dev/null; pwd -P )
declare -r WANIP=$(dig +short myip.opendns.com @resolver1.opendns.com)


function print_greeting() {
	echo -e "[0;35m trittium masternode install script[0m\n"
}


function print_info() {
	echo -e "[0;35m Install script version:[0m ${VERSION}"
	echo -e "[0;35m Your ip:[0m ${WANIP}"
	echo -e "[0;35m Masternode port:[0m ${NODEPORT}"
	echo -e "[0;35m RPC port:[0m ${RPCPORT}"
	echo -e "[0;35m Date:[0m ${DATE_STAMP}"
	echo -e "[0;35m Logfile:[0m ${SCRIPT_LOGFILE}"
}


function install_packages() {
	echo "Install packages..."
	add-apt-repository -yu ppa:bitcoin/bitcoin  &>> ${SCRIPT_LOGFILE}
	apt-get -y update &>> ${SCRIPT_LOGFILE}
  	sudo apt-get install p7zip-full &>> ${SCRIPT_LOGFILE}
	apt-get -y install wget make automake autoconf build-essential libtool autotools-dev \
	git nano python-virtualenv pwgen virtualenv \
	pkg-config libssl-dev libevent-dev bsdmainutils software-properties-common \
	libboost-all-dev libminiupnpc-dev libdb4.8-dev libdb4.8++-dev &>> ${SCRIPT_LOGFILE}
	echo "Install done..."
}


function swaphack() {
	echo "Setting up disk swap..."
	free -h
	rm -f /var/trittium_node_swap.img
	touch /var/trittium_node_swap.img
	dd if=/dev/zero of=/var/trittium_node_swap.img bs=1024k count=2000 &>> ${SCRIPT_LOGFILE}
	chmod 0600 /var/trittium_node_swap.img
	mkswap /var/trittium_node_swap.img &>> ${SCRIPT_LOGFILE}
	free -h
	echo "Swap setup complete..."
}


function remove_old_files() {
	echo "Removing old files..."
	sudo killall trittiumd
	sudo rm -rf /root/trittium
	sudo rm -rf /root/.trittium2
    sudo rm -rf trittiumd
    sudo rm -rf trittium-cli
	echo "Done..."
}


function download_wallet() {
	echo "Downloading wallet..."
	mkdir /root/trittium
    cd trittium
	mkdir /root/.trittium2
	wget https://github.com/Trittium/trittium/releases/download/2.1.1/Trittium-2.1.1-Ubuntu-daemon.tgz
	tar -zxvf Trittium-2.1.1-Ubuntu-daemon.tgz
	rm /root/trittium/Trittium-2.1.1-Ubuntu-daemon.tgz
	chmod +x /root/trittium/
	chmod +x /root/trittium/trittiumd
	chmod +x /root/trittium/trittium-cli
	echo "Done..."
}


function configure_firewall() {
	echo "Configuring firewall rules..."
	apt-get -y install ufw			&>> ${SCRIPT_LOGFILE}
	# disallow everything except ssh and masternode inbound ports
	ufw default deny			&>> ${SCRIPT_LOGFILE}
	ufw logging on				&>> ${SCRIPT_LOGFILE}
	ufw allow ssh/tcp			&>> ${SCRIPT_LOGFILE}
	ufw allow 30001/tcp			&>> ${SCRIPT_LOGFILE}
	ufw allow 30002/tcp			&>> ${SCRIPT_LOGFILE}
	# This will only allow 6 connections every 30 seconds from the same IP address.
	ufw limit OpenSSH			&>> ${SCRIPT_LOGFILE}
	ufw --force enable			&>> ${SCRIPT_LOGFILE}
	echo "Done..."
}


function configure_masternode() {
	echo "Configuring masternode..."
	conffile=/root/.trittium2/trittium.conf
	PASSWORD=`pwgen -1 20 -n` &>> ${SCRIPT_LOGFILE}
	if [ "x$PASSWORD" = "x" ]; then
	    PASSWORD=${WANIP}-`date +%s`
	fi
	echo "Loading and syncing wallet..."
	echo "    if you see *error: Could not locate RPC credentials* message, do not worry"
	/root/trittium/trittium-cli stop
	echo "It's okay."
	sleep 10
	echo -e "rpcuser=trittiumuser\nrpcpassword=${PASSWORD}\nrpcport=${RPCPORT}\nrpcallowip=127.0.0.1\nport=${NODEPORT}\nexternalip=${WANIP}\nlisten=1\nmaxconnections=250" >> ${conffile}
	echo ""
	echo -e "[0;35m==================================================================[0m"
	echo -e "     DO NOT CLOSE THIS WINDOW OR TRY TO FINISH THIS PROCESS"
	echo -e "                        PLEASE WAIT 2 MINUTES"
	echo -e "[0;35m==================================================================[0m"
	echo ""
	/root/trittium/trittiumd -daemon 
	echo "2 MINUTES LEFT"
	sleep 60
	echo "1 MINUTE LEFT"
	sleep 60
	masternodekey=$(/root/trittium/trittium-cli masternode genkey)
	/root/trittium/trittium-cli stop
	sleep 20
	echo "Creating masternode config..."
	echo -e "daemon=1\nmasternode=1\nmasternodeprivkey=$masternodekey" >> ${conffile}
	echo "Done...Starting daemon..."
	/root/trittium/trittiumd -daemon
}

function addnodes() {
	echo "Adding nodes..."
	conffile=/root/.trittium2/trittium.conf
	echo -e "\naddnode=seed.trittiumnet.com" 	>> ${conffile}
	echo -e "addnode=seed2.trittiumnet.com" 	>> ${conffile}
	echo -e "addnode=seed3.trittiumnet.com" 	>> ${conffile}
    echo -e "addnode=seed4.trittiumnet.com" 	>> ${conffile}
    echo -e "addnode=seed5.trittiumnet.com" 	>> ${conffile}
	echo -e "addnode=explorer.trittium.cc\n" >> ${conffile}
	echo "Done..."
}


function show_result() {
	echo ""
	echo -e "[0;35m==================================================================[0m"
	echo "DATE: ${DATE_STAMP}"
	echo "LOG: ${SCRIPT_LOGFILE}"
	echo "rpcuser=trittiumuser"
	echo "rpcpassword=${PASSWORD}"
	echo ""
	echo -e "[0;35m INSTALLED WITH VPS IP: ${WANIP}:${NODEPORT} [0m"
	echo -e "[0;35m INSTALLED WITH MASTERNODE PRIVATE GENKEY: ${masternodekey} [0m"
	echo ""
	echo -e "If you get \"Masternode not in masternode list\" status, don't worry,\nyou just have to start your MN from your local wallet and the status will change"
	echo -e "[0;35m==================================================================[0m"
}


function cleanup() {
	echo "Cleanup..."
	apt-get -y autoremove 	&>> ${SCRIPT_LOGFILE}
	apt-get -y autoclean 		&>> ${SCRIPT_LOGFILE}
	echo "Done..."
}


#Setting auto start cron job for trittiumd
cronjob="@reboot sleep 30 && /root/trittium/trittiumd"
crontab -l > tempcron
if ! grep -q "$cronjob" tempcron; then
    echo -e "Configuring crontab job..."
    echo $cronjob >> tempcron
    crontab tempcron
fi
rm tempcron


# Flags
compile=0;
swap=0;
firewall=0;


#Bad arguments
if [ $? -ne 0 ];
then
    exit 1
fi


# Check arguments
while [ "$1" != "" ]; do
    case $1 in
        -sw | --swap )
            swap=1
            ;;
        -f | --firewall )
            firewall=1
            ;;
        -n | --addnodes )
            addnodes=1
            ;;
        * )
            exit 1
    esac
    if [ "$#" -gt 0 ]; then shift; fi
done


# main routine
print_greeting
print_info
install_packages
if [ "$swap" -eq 1 ]; then
	swaphack
fi

if [ "$firewall" -eq 1 ]; then
	configure_firewall
fi

remove_old_files
download_wallet
addnodes
configure_masternode

show_result
cleanup
echo "All done!"
cd ~/
sudo rm /root/trtt_install.sh

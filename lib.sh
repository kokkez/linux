#!/bin/bash
# ==============================================================================
# companion library of the script for install Linux OSes
# ==============================================================================

#	DEFAULT VARIABLES
#	----------------------------------------------------------------------------
	ENV_product="unknown"				# linux distribution
	ENV_version="unknown"				# version of the distribution
	ENV_release="unknown"				# linux <product>-<version>
	ENV_codename="unknown"				# codename of the distribution
	ENV_arch="unknown"					# kernel architecture

	TARGET="unknown"
	TIME_ZONE="Europe/Rome"
	SSHD_PORT="64128"

	HOST_NICK=$(command hostname -s)
	HOST_FQDN=$(command hostname -f)
	ROOT_MAIL="k-${HOST_NICK}@rete.us"
	LENC_MAIL="k-letsencrypt@rete.us"	# letsencrypt account email

	MAIL_NAME="$HOST_FQDN"
	DB_rootpw=""
	ASSP_ADMINPW="zeroSpam4me"

	CERT_C="IT"
	CERT_ST="Reggio Emilia"
	CERT_L="Bagnolo in Piano"
	CERT_O="italmedia.net"
	CERT_OU="internet-server"
	CERT_CN="${HOST_FQDN}"
	CERT_E="${ROOT_MAIL}"

	HTTP_SERVER="apache2"
	ISP3_MULTISERVER="n"   # "n" or "y"
	ISP3_MASTERHOST=""     # fqdn of the master ispconfig multiserver db, or empty
	ISP3_MASTERUSER="root" # username of the master db, usually root
	ISP3_MASTERPASS=""     # password of the master db, if empty will be asked

	# -- bash colors -----------------------------------------------------------
	Dye.as() {
		# output painted text
		# $1 num : type (default 0, dark)
		# $2 num : color (default 37, gray)
		# $3 text: message to colorize
		echo -e "\e[${1:-0};${2:-37}m${@:3}\e[0m";
	}
	Dye.fg.red()         { Dye.as 0 31 "$@"; };
	Dye.fg.red.lite()    { Dye.as 1 31 "$@"; };
	Dye.fg.green()       { Dye.as 0 32 "$@"; };
	Dye.fg.green.lite()  { Dye.as 1 32 "$@"; };
	Dye.fg.yellow()      { Dye.as 0 33 "$@"; };
	Dye.fg.yellow.lite() { Dye.as 1 33 "$@"; };
	Dye.fg.blue()        { Dye.as 0 34 "$@"; };
	Dye.fg.blue.lite()   { Dye.as 1 34 "$@"; };
	Dye.fg.purple()      { Dye.as 0 35 "$@"; };
	Dye.fg.purple.lite() { Dye.as 1 35 "$@"; };
	Dye.fg.cyan()        { Dye.as 0 36 "$@"; };
	Dye.fg.cyan.lite()   { Dye.as 1 36 "$@"; };
	Dye.fg.gray()        { Dye.as 0 37 "$@"; };
	Dye.fg.white()       { Dye.as 1 37 "$@"; };
	Dye.fg.orange()      { Dye.as "38;5" 214 "$@"; };



#	MESSENGERS
#	----------------------------------------------------------------------------
	Msg.debug() { Dye.as 1 32 "$@"; }					# green lite
	Msg.info()  { Dye.as 1 36 "$@"; }					# cyan lite
	Msg.warn()  { Dye.as 1 33 "$@"; }					# yellow lite
	Msg.error() { Dye.as 1 31 "ERROR: $@"; exit 1; }	# red lite



#	FUNCTIONS
#	companion functions for the entire system
#	----------------------------------------------------------------------------
	Arg.expect() {
		# helper function for verifying args in functions
		# expects: variable number of arguments ( $1 [, $2 [, $3 ... ]] )
		local i=1
		for (( ; i<=$#; i++ )); do
			[ -z "${!i}" ] \
				&& Msg.warn "Missing argument #$i to ${FUNCNAME[1]}()" \
				&& return 1
		done
		return 0
	};


	cmd() {
		# try to run the real command, not an aliased version
		# on missing command, or error, it return silently
		Arg.expect "$1" || return 0
		local c="$( command -v $1 )"
		shift && [ -n "$c" ] && "$c" "$@"
	}	# end cmd


	Date.fmt() {
		# return a formatted date/time, providing a custom default
		echo -e $(cmd date "${@-+'%F %T'}")
	}	# end Date.fmt


	Dir.delete() {
		# if directory exists then delete it
		# $1: path to folder
		# $2: optional message
		Arg.expect "$1" && [ -d "$1" ] && {
			[ -n "$2" ] && echo -e "${@:2}"
			cmd rm -rf "$1"
		}
	}	# end Dir.delete


	Sess.clean() {
		# try to delete the folder in $1
		Dir.delete "$1" "Cleaning up the lock folder:" $( Dye.fg.white "$1" )
	}	# end Sess.clean


	Sess.lock() {
		# give lockdir the name in $1, or a default one
		local d=/tmp/${1-myapp}
		# if directory exists exit here
		[ -d "$d" ] && {
			Msg.warn "Job is already running with pid: $(< $d/PID)"
			exit 6
		}
		# this is a new instance
		echo -e "Locking the job in:" $( Dye.fg.white "$d" )
		# create folder & store the pid
		mkdir -p "$d"
		echo $$ > $d/PID
		# then set traps to cleanup upon script termination
		# ref http://www.shelldorado.com/goodcoding/tempfiles.html
		trap "Sess.clean $d" 0
		trap "exit 2" 1 2 3 13 15
	}	# end Sess.lock


	File.backup() {
		# if backup exists do nothing
		Arg.expect "$1" && [ -e "$1.backup" ] && return
		# if original is not empty, copy it to backup
		[ -s "$1" ] && cp "$1" "$1.backup"
	}	# end File.backup


	File.recopy() {
		# copy the file in $1 to the destination in $2, forcing unix EOLs
		File.backup "$2"				# do backup first
		sed -e 's|\r||g' "$1" > "$2"	# copy forcing unix EOLs
	}	# end File.recopy


	File.islink() {
		# exits with 0 (success) if symlink is valid, or 1 if broken/missing
		# $1: path to a symlink
		Arg.expect "$1" && [ -L "$1" ] && [ -e "$1" ]
	}	# end File.islink


	File.path() {
		# return the full path to a single file into one of the "files" folders,
		# looking first into distro-xx/files
		# return an empty string if nothing is found
		# $1 - relative path to search
		Arg.expect "$1" || return
		cmd readlink -e "$ENV_dir/distro-$ENV_codename/files/$1" \
			|| cmd readlink -e "$ENV_dir/files/$1" \
			|| return 1
	}	# end File.path


	File.place() {
		# copy a single file, from one of the "files" folders, to
		# the destination path in $2, with precedence to "distro-xx/files"
		# $1 - file path relative to one of the "files" folders
		# $2 - destination full path
		Arg.expect "$1" "$2" || return
		local f=$( File.path "$1" ) d="$2"
		[ -n "$f" ] && {
			[ -d "$d" ] && d="$d/$1"	# build destination
			File.recopy "$f" "$d"		# backup & copy
		}
	}	# end File.place


	File.paths() {
		# return the full path to all files matching $1
		# $1 - file path relative to one of the "files" folders
		Arg.expect "$1" || return
		local f=$( cmd find $ENV_dir/distro-$ENV_codename/files -wholename "*$1" )
		[ -z "$f" ] && f=$( cmd find $ENV_dir/files -wholename "*$1" )
		echo "$f"
	}	# end File.paths


	File.into() {
		# copy into the destination folder in $1, the files from ${@:2}
		# that can comes exclusively from one of the "files" folders,
		# with precedence to "distro-xx/files"
		# $1     - destination folder path
		# ${@:2} - file path relative to one of the "files" folders
		Arg.expect "$1" "$2" || return

		# detect the real destination
		local a f d=$( cmd readlink -e "$1" )
		[ -d "$d" ] || return				# abort if dest. is not a folder

		for a in "${@:2}"; do				# iterating from 2nd arguments
			for f in $( File.paths "$a" )	# iterating files
			do
				File.recopy "$f" "$d/${f##*/}"
			done
		done
	}	# end File.into


	Cmd.usable() {
		# test argument $1 for: not empty & callable
		Arg.expect "$1" && command -v "$1" &> /dev/null
	}	# end Cmd.usable


	Pkg.installed() {
		# > /my/file  redirects stdout to /my/file
		# 1> /my/file redirects stdout to /my/file
		# 2> /my/file redirects stderr to /my/file
		# &> /my/file redirects stdout and stderr to /my/file

		# redirects stderr to the black hole
		[ -n "${1}" ] && dpkg -l "${1}" 2> /dev/null | grep -q ^ii
	}	# end Pkg.installed


	Pkg.install() {
		Pkg.update	# update packages lists
		export DEBIAN_FRONTEND=noninteractive
		apt-get -qy \
			-o Dpkg::Options::="--force-confdef" \
			-o Dpkg::Options::="--force-confnew" \
			install "${@}"
	}	# end Pkg.install


	Pkg.update() {
		# the "apt-get update", to run before install any package
		cmd dpkg --configure -a	# in case apt is in a bad state

		# if an argument is given then forcing run apt-get
		[ -z "$1" ] || {
			Msg.info "Coerce the update of the package list for ${ENV_os}..."
			DOCLEANAPT=
		}

		[ -z "$DOCLEANAPT" ] && {
			DOCLEANAPT=1		# signal to do apt cleanup on exit
			cmd apt -qy update || {
				Msg.error "An errors occurred executing 'apt update'. Try again later..."
			}
		}
	}	# end Pkg.update


	Pkg.requires() {
		# check that the given packages are installed, if not
		# then it install all at once
		Arg.expect "$1" || return
		local p
		for p in "$@"
			do Pkg.installed "$p" || {
				Msg.info "Installing required packages: [ $@ ]"
				Pkg.install "$@"
				break
			}
		done
	}	# end Pkg.requires


	Pkg.purge() {
		# remove a single package via apt-get
		Arg.expect "$1" || return

		# it can be a command
		local c=$(command -v $1)

		# detect package from command
		c=${c:+$(dpkg -S "$c" 2> /dev/null)}
		c=${c%:*}	# remove optional arch (all char from the last ":")

		# do the real deletion
		Pkg.installed "$c" && {
			export DEBIAN_FRONTEND=noninteractive
			apt-get -qy purge --auto-remove "$c"
			Msg.info "Removing package '$c' (from '$1') completed!"
			return
		}

		Msg.warn "No package for '$1' is installed"
	}	# end Pkg.purge


	File.download() {
		# download via wget, returning an error on failure
		# $1 url
		# $2 destination name
		Arg.expect "$1" "$2" || exit

		Pkg.requires wget
		cmd wget -nv --no-check-certificate "$1" -O "$2" || {
			Msg.info "Download failed ( $2 ), exiting here..."
			exit
		}
	}	# end File.download


	Menu.password() {
		# generate a random password (min 6 max 32 chars)
		# $1 number of characters (defaults to 24)
		# $2 flag for strong password (defaults no)
		local c="[:alnum:]" n=$(cmd awk '{print int($1)}' <<< ${1:-24})

		# constrain number of characters
		n=$(( n > 31 ? 32 : n < 7 ? 6 : n ))

		# add special chars for strong password
		[ -n "$2" ] && c="!#\$%&*+\-.:<=>?@[]^~$c"

		echo $( cmd tr -dc "$c" < /dev/urandom | cmd head -c $n )
	}	# end Menu.password


	Menu.iotest() {
		# classic disk I/O test
		Msg.info "Performing classic I/O test..."
		cmd dd if=/dev/zero of=~/tmpf bs=64k count=16k conv=fdatasync && rm -rf ~/tmpf
	}	# end Menu.iotest


	done_deps() {
		# test that the step "Menu.deps" was already executed

		# simply check that /etc/apt/apt.conf.d/99norecommend exists
		[ -f "/etc/apt/apt.conf.d/99norecommend" ] || {
			Msg.warn "Need to execute '$(cmd basename "$0") deps' step before..."
			return 1
		}
	}	# end done_deps


	Port.audit() {
		# set port in $1 to be strictly numeric & in a known range
		# $1 - port number, optional, defaults to 22 (ssh)
		local t l p=$( cmd awk '{print int($1)}' <<< ${1:-22} )
		(( p == 22 )) || {
			# limit min & max range
			p=$(( p > 65534 ? 65535 : p < 1025 ? 1024 : p ))
			# exclude net.ipv4.ip_local_port_range (32768-60999)
			t=$( cmd sysctl -e -n net.ipv4.ip_local_port_range )
			l=$( cmd awk '{print int($1)}' <<< $t )
			t=$( cmd awk '{print int($2)}' <<< $t )
			p=$(( p < l ? p : p > t ? p : 64128 ))
		}
		echo $p
	}	# end Port.audit


	Version.numeric() {
		# return the cleaned numeric version of a program
		cmd awk -F. '{ printf("%d.%d.%d\n",$1,$2,$3) }' <<< "$@"
	}	# end Version.numeric


	Version.php() {
		# return the dotted number of the cli version of PHP
		# $1 - word to specify the wanted result like this: given 7.2.24
		#  major will return 7
		#  minor will return 7.2
		#  otherwise 7.2.24
		local v=$( cmd php -v | grep -oP 'PHP [\d\.]+' | awk '{print $2}' )
		[ "$1" = "major" ] && v=$( cmd awk -F. '{print $1}' <<< "$v" )
		[ "$1" = "minor" ] && v=$( cmd awk -F. '{print $1"."$2}' <<< "$v" )
		echo "$v"
	}	# end Version.php


	ISPConfig.installed() {
		# exits with 0 (success) if ispconfig is installed
		# no arguments expected
		[ -s '/usr/local/ispconfig/server/lib/config.inc.php' ]
	}	# end ISPConfig.installed



#	MAIN MENU
#	----------------------------------------------------------------------------

	ENV.clean() {
		# do apt cleanup if $1 is not empty
		[ -n "${DOCLEANAPT}" ] && {
			unset DOCLEANAPT
			apt-get -qy purge				# remove packages and config files
			apt-get -qy autoremove			# remove unused packages automatically
			apt-get -qy autoclean			# erase old downloaded archive files
			apt-get -qy clean				# erase downloaded archive files
			rm -rf /var/lib/apt/lists/*		# delete the entire cache
		}
	}	# end ENV.clean


	ENV.init() {
		# initializes the environment
		# no arguments expected

		# user must be root (id == 0)
		(( $(cmd id -u) )) && {
			Msg.error "This app must be run as:" $(Dye.fg.white root)
		}
		local x t

		# test the availability of some required commands
		for x in awk apt-get cat cd cp debconf-set-selections dpkg \
			dpkg-reconfigure find grep head mkdir mv perl rm sed tr;
		do
			Cmd.usable "$x" || Msg.error "Missing command: $x"
		done

		# detect OS info (ENV_product, ENV_version, ENV_codename)
		# thanks to Mikel (http://unix.stackexchange.com/users/3169/mikel) for idea
		if [ -f /etc/lsb-release ]; then
			. /etc/lsb-release
			ENV_product=${DISTRIB_ID,,}			# lowercase debian, ubuntu, ...
			ENV_version=${DISTRIB_RELEASE,,}	# lowercase 9, 18.04, ...
		elif [ -f /etc/os-release ]; then
			. /etc/os-release
			ENV_product=${ID,,}					# lowercase debian, ubuntu, ...
			ENV_version=${VERSION_ID,,}			# lowercase 9, 18.04, ...
		elif [ -f /etc/issue.net ]; then
			t=$(head -1 /etc/issue.net)
			ENV_product=$(awk '{print $1}' <<< ${t,,})
			ENV_version=$(perl -pe '($_)=/(\d+([.]\d+)+)/' <<< ${t,,})
		fi;

		# setup some environment variables
		ENV_release="${ENV_product}-$ENV_version"
		ENV_arch=$( cmd uname -m )

		case $ENV_release in
		#	"debian-7")     ENV_codename="wheezy"  ;;
			"debian-8")     ENV_codename="jessie"  ;;
			"debian-9")     ENV_codename="stretch" ;;
			"debian-10")    ENV_codename="buster"  ;; # 2020-05
			"ubuntu-16.04") ENV_codename="xenial"  ;;
			"ubuntu-18.04") ENV_codename="bionic"  ;; # 2020-04
			"ubuntu-20.04") ENV_codename="focal"   ;; # 2021-01
		esac;

		# control that release isnt unknown
		[ "$ENV_codename" = "unknown" ] && {
			Msg.error "This distribution is not supported: $ENV_release"
		}

		# append to parent folder name the discovered infos
		t=${ENV_dir%/*}/linux.${ENV_release}.${ENV_codename}.${ENV_arch}
		[ -d "$t" ] || {
			mv ~/linux* "$t"
			ENV_dir="$t"
		}

		# setup other environment variables
		ENV_os="$ENV_release ($ENV_codename)"

		# removing unneeded distros
		for x in $ENV_dir/distro-*
			do [ "$x" = "$ENV_dir/distro-$ENV_codename" ] || rm -rf "$x"
		done

		# sourcing all common functions
		for x in $ENV_dir/functions/fn_*
			do . "$x"
		done

		# sourcing all distro's functions, that can redefine the previous
		for x in $ENV_dir/distro-$ENV_codename/fn_*
			do . "$x"
		done

		Cmd.usable 'nginx' && HTTP_SERVER='nginx'
	}	# end ENV.init


	OS.menu() {
		# display the main menu on screen
		local s o=""

		# One time actions
		s=""
		Cmd.usable "Menu.ssh" && {
			s+="   . $(Dye.fg.orange ssh)         setup private key, shell, SSH on port $(Dye.fg.white $SSHD_PORT)\n"; }
		Cmd.usable "Menu.deps" && {
			s+="   . $(Dye.fg.orange deps)        check dependencies, update the base system, setup firewall\n"; }
		[ -z "$s" ] || {
			o+=" [ . $(Dye.fg.white One time actions) ---------------------------------------------- (in recommended order) -- ]\n$s"; }

		# Standalone utilities
		s=""
		Cmd.usable "Menu.upgrade" && {
			s+="   . $(Dye.fg.orange upgrade)     apt full upgrading of the system\n"; }
		Cmd.usable "Menu.password" && {
			s+="   . $(Dye.fg.orange password)    print a random pw: \$1: length (6 to 32, 24), \$2: flag strong\n"; }
		Cmd.usable "Menu.iotest" && {
			s+="   . $(Dye.fg.orange iotest)      perform the classic I/O test on the server\n"; }
		Cmd.usable "Menu.resolv" && {
			s+="   . $(Dye.fg.orange resolv)      set $(Dye.fg.white /etc/resolv.conf) with public dns\n"; }
		Cmd.usable "Menu.mykeys" && {
			s+="   . $(Dye.fg.orange mykeys)      set my authorized_keys, for me & backuppers\n"; }
		Cmd.usable "Menu.tz" && {
			s+="   . $(Dye.fg.orange tz)          set the server timezone to $(Dye.fg.white $TIME_ZONE)\n"; }
		Cmd.usable "Menu.motd" && {
			s+="   . $(Dye.fg.orange motd)        customize the dynamic Message of the Day (motd)\n"; }
		[ -z "$s" ] || {
			o+=" [ . $(Dye.fg.white Standalone utilities) ---------------------------------------- (in no particular order) -- ]\n$s"; }

		# Main applications
		s=""
		Cmd.usable "Menu.mailserver" && {
			s+="   . $(Dye.fg.orange mailserver)  full mailserver with postfix, dovecot & aliases\n"; }
		Cmd.usable "Menu.dbserver" && {
			s+="   . $(Dye.fg.orange dbserver)    the DB server MariaDB, root pw stored in $(Dye.fg.white ~/.my.cnf)\n"; }
		Cmd.usable "Menu.webserver" && {
			s+="   . $(Dye.fg.orange webserver)   webserver apache2 or nginx, with php, selfsigned cert, adminer\n"; }
		[ -z "$s" ] || {
			o+=" [ . $(Dye.fg.white Main applications) --------------------------------------------- (in recommended order) -- ]\n$s"; }

		# Target system
		s=""
		Cmd.usable "Menu.dns" && {
			s+="   . $(Dye.fg.orange dns)         bind9 DNS server with some related utilities\n"; }
		Cmd.usable "Menu.assp1" && {
			s+="   . $(Dye.fg.orange assp1)       the AntiSpam SMTP Proxy version 1 (min 768ram 1core)\n"; }
		Cmd.usable "Menu.ispconfig" && {
			s+="   . $(Dye.fg.orange ispconfig)   historical Control Panel, with support at $(Dye.fg.white howtoforge.com)\n"; }
		[ -z "$s" ] || {
			o+=" [ . $(Dye.fg.white Target system) ----------------------------------------------- (in no particular order) -- ]\n$s"; }

		# Others applications
		s=""
		Cmd.usable "Menu.dumpdb" && {
			s+="   . $(Dye.fg.orange dumpdb)      to backup all databases, or the one given in $(Dye.fg.white \$1)\n"; }
		Cmd.usable "Menu.roundcube" && {
			s+="   . $(Dye.fg.orange roundcube)   full featured imap web client\n"; }
		Cmd.usable "Menu.nextcloud" && {
			s+="   . $(Dye.fg.orange nextcloud)   on-premises file share and collaboration platform\n"; }
		Cmd.usable "Menu.espo" && {
			s+="   . $(Dye.fg.orange espo)        EspoCRM full featured CRM web application\n"; }
		Cmd.usable "Menu.acme" && {
			s+="   . $(Dye.fg.orange acme)        shell script for Let's Encrypt free SSL certificates\n"; }
		[ -z "$s" ] || {
			o+=" [ . $(Dye.fg.white Others applications) ----------------------------------- (depends on main applications) -- ]\n$s"; }

		echo -e " $(Date.fmt +'%F %T %z') :: $(Dye.fg.orange $ENV_os $ENV_arch) :: ${ENV_dir}\n$o" \
			"[ ------------------------------------------------------------------------------------------- ]"
	}	# end OS.menu

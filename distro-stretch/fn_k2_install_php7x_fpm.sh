# ------------------------------------------------------------------------------
# install PHP as MOD-PHP, PHP-FPM and FastCGI
# ------------------------------------------------------------------------------

install_php7x_fpm() {
	# abort if package was already installed
	is_installed "libapache2-mod-fcgid" && {
		msg_alert "PHP as PHP-FPM is already installed..."
		return
	}

	# add external repository for updated php
	is_installed "apt-transport-https" || {
		msg_info "Installing required packages..."
		pkg_install apt-transport-https lsb-release ca-certificates
	}
	down_load https://packages.sury.org/php/apt.gpg /etc/apt/trusted.gpg.d/php.gpg
	cat <<EOF > /etc/apt/sources.list.d/php.list
# https://www.patreon.com/oerdnj
deb http://packages.sury.org/php stretch main
#deb-src http://packages.sury.org/php stretch main
EOF

	# forcing apt update
	pkg_update true

	# now install php packages, 2 versions, 7.0 and 7.3, and some modules
	pkg_install libapache2-mod-fcgid \
		php5.6 libapache2-mod-php5.6 \
		php5.6-{cli,cgi,fpm,mysql,gd,curl,imap,intl,mbstring,pspell,recode,soap,sqlite3,tidy,xmlrpc,xsl,zip,mcrypt} \
		php7.3 libapache2-mod-php7.3 \
		php7.3-{cli,cgi,fpm,mysql,gd,curl,imap,intl,mbstring,pspell,recode,soap,sqlite3,tidy,xmlrpc,xsl,zip} \
		php-{apcu,apcu-bc,gettext,imagick,memcache,pear} imagemagick memcached mcrypt

	# enable apache2 modules
	a2enmod proxy_fcgi setenvif fastcgi alias

	msg_info "Configuring PHP as PHP-FPM for apache2..."
	cd /etc/apache2

	# setting up the default DirectoryIndex
	[ -r mods-available/dir.conf ] && {
		sed -ri 's|^(\s*DirectoryIndex).*|\1 index.php index.html|' mods-available/dir.conf
	}

	# adjust date.timezone in all php.ini
	sed -ri "s|^;(date\.timezone =).*|\1 '${TIME_ZONE}'|" /etc/php/*/*/php.ini

	# cgi.fix_pathinfo provides *real* PATH_INFO/PATH_TRANSLATED support for CGI
	sed -ri 's|^;(cgi.fix_pathinfo).*|\1 = 1|' /etc/php/*/fpm/php.ini

	svc_evoke apache2 restart
	msg_info "Installation of PHP as PHP-FPM completed!"
}	# end install_php7x_fpm
# ------------------------------------------------------------------------------
# install EspoCRM
# https://www.espocrm.com/
# ------------------------------------------------------------------------------

menu_espo() {
	local u v="5.0.3"						# use with php 5.6 or 7

	Msg.info "Installing EspoCRM ${v}..."

	# install some php modules before install EspoCRM
	pkg_install libapache2-mod-php5 php5-mysqlnd php5-json php5-gd \
		php5-mcrypt php5-imap php5-curl

	# new database with related user, info saved in ~/.dbdata.txt
	create_database "espocrm" "espocrm"

	# go, install EspoCRM
	cd /var/www
	u="https://www.espocrm.com/downloads/EspoCRM-${v}.zip"
	down_load "$u" "espo.zip"
	unzip -qo espo.zip
	rm -rf espo.zip
	mv EspoCRM-* espo
	cd espo
	mkdir -p data/cache data/cache/application data/logs
	chown -R 33:0 . # set user to www-data
	find . -type d -exec chmod 755 {} + && find . -type f -exec chmod 644 {} +;
	sed -ri 's|^#\s*(RewriteBase).*|\1 /espo/api/v1/|' api/v1/.htaccess

	# apache configuration
	cd /etc/apache2
	File.into sites-available espocrm.conf
	sed -i "s|ALLOWALL|Require all granted|" sites-available/espocrm.conf
	[ -L sites-enabled/120-espocrm.conf ] || {
		ln -s ../sites-available/espocrm.conf sites-enabled/120-espocrm.conf
	}
	cmd a2enmod rewrite headers env dir mime
	cmd systemctl restart apache2

	# cron configuration
	[ -s /etc/crontab ] && grep -q EspoCRM /etc/crontab || {
		File.backup /etc/crontab
		cat <<EOF >> /etc/crontab

# EspoCRM
* * * * * root cd /var/www/espo; /usr/bin/php -f cron.php > /dev/null 2>&1
EOF
	}

	Msg.info "Now install EspoCRM $v via browser..."
}	# end menu_espo

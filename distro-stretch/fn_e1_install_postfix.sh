# ------------------------------------------------------------------------------
# install postfix mailserver
# ------------------------------------------------------------------------------

install_postfix() {
	is_installed "postfix-mysql" && {
		msg_alert "Postfix is already installed..."
		return
	}

	# install postfix & saslauthd, this add openssl ssl-cert
	msg_info "Installing postfix..."

	# preseed postfix
	debconf-set-selections <<EOF
postfix postfix/main_mailer_type select Internet Site
postfix postfix/mailname string ${MAIL_NAME}
postfix postfix/destinations string ${HOST_FQDN}, localhost
EOF

	# install required & useful packages
	pkg_install postfix postfix-mysql libsasl2-modules pfqueue swaks

	# purge exim4 on pure debian
	is_available "exim" && {
		msg_info "Purging exim4 and the like..."
		export DEBIAN_FRONTEND=noninteractive
		apt-get -qy purge --auto-remove exim4 exim4-*
	}

	# set basic parameters in main.cf
	cmd postconf \
		myorigin=${HOST_FQDN} \
		myhostname=${MAIL_NAME} \
		mydestination=${MAIL_NAME},localhost

	# install /etc/aliases
	copy_to /etc postfix/aliases
	sed -i "s|ROOT_MAIL|${ROOT_MAIL}|" /etc/aliases
	cmd newaliases

	# activating ports on firewall
	firewall_allow "ssltls"

	msg_info "Installation of postfix & aliases completed!"
}	# end install_postfix
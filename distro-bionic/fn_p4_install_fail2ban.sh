# ------------------------------------------------------------------------------
# install fail2ban 0.10.2 for ubuntu 18.04 bionic
# https://reposcope.com/package/fail2ban
# ------------------------------------------------------------------------------

install_fail2ban() {
	# abort if fail2ban is already installed
	Pkg.installed "fail2ban" && {
		Msg.warn "fail2ban is already installed..."
		return
	}

	Msg.info "Installing fail2ban for ${ENV_os}..."
	Pkg.install fail2ban

	Msg.info "Configuring fail2ban..."

	# make fail2ban do some monitoring
	local p="/etc/fail2ban"
	File.into $p fail2ban/jail.local
	sed -i $p/jail.local -e "s|HOST_NICK|$HOST_NICK|"

	# creating filter files
	p+="/filter.d"
	[ -r $p/postfix-failedauth.conf ] || {
		File.into $p fail2ban/postfix-failedauth.conf
	}
	[ -r $p/dovecot-pop3imap.conf ] || {
		File.into $p fail2ban/dovecot-pop3imap.conf
	}

	# fix a systemd bug found on xenial 16.04
	p=/usr/lib/tmpfiles.d/fail2ban-tmpfiles.conf
	grep -q '/var' $p && {
		Msg.info "Fixing a little systemd bug that prevent fail2ban to start"
		sed -i $p -e 's|/var||'
	}

	cmd systemctl restart fail2ban
	Msg.info "Installation of Fail2ban completed!"
}	# end install_fail2ban

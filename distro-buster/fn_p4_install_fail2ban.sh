# ------------------------------------------------------------------------------
# install fail2ban 0.10.2 for debian 10 buster
# https://reposcope.com/package/fail2ban
# ------------------------------------------------------------------------------

install_fail2ban() {
	# abort if fail2ban is already installed
	Pkg.installed "fail2ban" && {
		Msg.warn "fail2ban is already installed..."
		return
	}

	Msg.info "Installing fail2ban for ${ENV_os}..."
	pkg_install fail2ban

	Msg.info "Configuring fail2ban..."

	# make fail2ban do some monitoring
	cd /etc/fail2ban
	File.into . fail2ban/jail.local
	sed -i "s|HOST_NICK|${HOST_NICK}|" jail.local

	# creating filter files
	cd filter.d
	[ -r postfix-failedauth.conf ] || {
		File.into . fail2ban/postfix-failedauth.conf
	}
	[ -r dovecot-pop3imap.conf ] || {
		File.into . fail2ban/dovecot-pop3imap.conf
	}

	# fix a systemd bug found on xenial 16.04
	local X=/usr/lib/tmpfiles.d/fail2ban-tmpfiles.conf
	grep -q '/var' ${X} && {
		Msg.info "Fixing a little systemd bug that prevent fail2ban to start"
		sed -i 's|/var||' ${X}
	}

	cmd systemctl restart fail2ban
	Msg.info "Installation of Fail2ban completed!"
}	# end install_fail2ban

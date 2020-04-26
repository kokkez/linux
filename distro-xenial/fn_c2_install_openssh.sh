# ------------------------------------------------------------------------------
# configure SSH server & firewall
# ------------------------------------------------------------------------------

install_openssh() {
	# $1: port - strictly in numerical range
	local s p=$(port_validate ${1})

	# configure SSH server arguments
	sed -ri /etc/ssh/sshd_config \
		-e "s|^#?Port.*|Port ${p}|" \
		-e 's|^#?(PasswordAuthentication).*|\1 no|' \
		-e 's|^#?(PermitRootLogin).*|\1 without-password|' \
		-e 's|^#?(RSAAuthentication).*|\1 yes|' \
		-e 's|^#?(PubkeyAuthentication).*|\1 yes|'

	# mitigating ssh hang on reboot on systemd capables OSes
	s=ssh-user-sessions.service
	[ -s /etc/systemd/system/${s} ] || {
		msg_info "Mitigating the SSH hang on reboot's problem"
		copy_to /etc/systemd/system ssh/${s}
		cmd systemctl enable ${s}
		cmd systemctl daemon-reload
		cmd systemctl start ${s}
	}

	# fix a systemd bug of xenial 16.04
	# https://askubuntu.com/questions/1109934/ssh-server-stops-working-after-reboot-caused-by-missing-var-run-sshd
	[ -s /usr/lib/tmpfiles.d/sshd.conf ] || {
		msg_info "Fixing a little systemd bug that prevent SSHd to start"
		sed -i 's|/var||' /usr/lib/tmpfiles.d/sshd.conf
	}

	# activate on firewall & restart SSH
	firewall_allow "${p}"
	svc_evoke ssh restart
	msg_info "The SSH server is listening on port: ${p}"
}	# end install_openssh

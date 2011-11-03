# mailman setup for lists.wm
class mailman::base {

	require lighttpd::mailman

	package { [ "mailman" ]:
		ensure => latest;
	}

	file {
		"/etc/aliases":
			owner => root,
			group => root,
			mode => 0444,
			source => "puppet:///files/mailman/aliases";
		"/etc/mailman/mm_cfg.py":
			require => Package[mailman],
			owner => root,
			group => root,
			mode => 0644,
			source => "puppet:///files/mailman/mm_cfg.py";

	}
}
	
# lighttpd setup as used by the mailman UI (lists.wm)
class lighttpd::mailman {

	package { [ "lighttpd" ]:
			ensure => latest;
	}

	file { 
		"/etc/lighttpd":
			ensure => directory,
			# puppet will automatically set +x for directories
			mode => 0644,
			owner => root,
			group => root;
		"lighttpd.conf":
			mode => 0444,
			owner => root,
			group => root,
			path => "/etc/lighttpd/lighttpd.conf",
			source => "puppet:///files/lighttpd/list-server.conf";
		"mailman-private-archives.conf":
			mode => 0444,
			owner => root,
			group => root,
			path => "/etc/lighttpd/mailman-private-archives.conf",
			source => "puppet:///files/lighttpd/mailman-private-archives.conf";
		"/etc/lighttpd/ssl":
			ensure => directory,
			mode => 0644,
			owner => root,
			group => root;
		"/etc/lighttpd/ssl/lists.wikimedia.org.pem":
			mode => 0400,
			owner => root,
			group => root,
			source => "puppet:///private/mailman/lists.wikimedia.org.pem";
		"/etc/lighttpd/ssl/*.wikimedia.org.pem":
			mode => 0400,
			owner => root,
			group => root,
			source => "puppet:///private/mailman/*.wikimedia.org.pem";
			
	}

	service { "lighttpd":
			require => [ File["lighttpd.conf"], File["mailman-private-archives.conf"], Package[lighttpd] ],
			subscribe => [ File["lighttpd.conf"], File["mailman-private-archives.conf"] ],
			ensure => running;
	}

	# monitoring
	monitor_service { "http": description => "HTTP", check_command => "check_http" }
	monitor_service { "https": description => "HTTPS", check_command => "check_ssl_cert!lists.wikimedia.org" }
}

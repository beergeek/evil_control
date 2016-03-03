class profiles::web_services {

  $website_hash 	    = hiera('profiles::web_services::website_hash')
  $website_defaults 	= hiera('profiles::web_services::website_defaults')
  $enable_firewall    = hiera('profiles::web_services::enable_firewall')
  $lb                 = hiera('profiles::web_services::lb', true)

  #build base web server
  case $::kernel {
    'linux': {
      require apache
      require apache::mod::php
      require apache::mod::ssl
      include app_update

      if $enable_firewall {
        # add firewall rules
        firewall { '100 allow http and https access':
          port   => [80, 443],
          proto  => tcp,
          action => accept,
        }
      }

      @@nagios_service { "${::fqdn}_http":
        ensure              => present,
        use                 => 'generic-service',
        host_name           => $::fqdn,
        service_description => "HTTP",
        check_command       => 'check_http',
        target              => "/etc/nagios/conf.d/${::fqdn}_service.cfg",
        notify              => Service['nagios'],
        require             => File["/etc/nagios/conf.d/${::fqdn}_service.cfg"],
      }

    }
    'windows': {
      case $::kernelmajversion {
        '6.1': {
          windowsfeature { 'IIS':
            feature_name => [
              'Web-Server',
              'Web-WebServer',
              'Web-Asp-Net',
              'Web-ISAPI-Ext',
              'Web-ISAPI-Filter',
              'NET-Framework',
              'WAS-NET-Environment',
              'Web-Http-Redirect',
              'Web-Filtering',
              'Web-Mgmt-Console',
              'Web-Mgmt-Tools'
            ]
          }
        }
        '6.3': {
          windowsfeature { 'IIS':
            feature_name => [
              'Web-Server',
              'Web-WebServer',
              'Web-Common-Http',
              'Web-Asp',
              'Web-Asp-Net45',
              'Web-ISAPI-Ext',
              'Web-ISAPI-Filter',
              'Web-Http-Redirect',
              'Web-Health',
              'Web-Http-Logging',
              'Web-Filtering',
              'Web-Mgmt-Console',
              'Web-Mgmt-Tools'
              ],
          }
        }
        default: {
          fail("You must be running a 19th centery version of Windows")
        }
      }

      # disable default website
      iis::manage_site { 'Default Web Site':
        ensure    => absent,
        site_path => 'C:\inetpub\wwwroot',
        app_pool  => 'Default Web Site',
      }

      iis::manage_app_pool { 'Default Web Site':
        ensure => absent,
      }
    }
    default: {
      fail("${::kernel} is a non-supported OS Kernel")
    }
  }

  #create web sites
  # old school
  # create_resources('profiles::web_sites',$website_hash,$website_defaults)
  # new school
  $website_hash.each |String $site_name, Hash $site_hash| {
    profiles::web_sites { $site_name:
      * => $site_hash,;
      default:
        * => $website_defaults,;
    }
  }

  if $lb {
    @@haproxy::balancermember { "http00-${::fqdn}":
      listening_service => 'http00',
      server_names      => $::fqdn,
      ipaddresses       => $::ipaddress_eth1,
      ports             => '80',
      options           => 'check',
    }
    @@haproxy::balancermember { "https00-${::fqdn}":
      listening_service => 'https00',
      server_names      => $::fqdn,
      ipaddresses       => $::ipaddress_eth1,
      ports             => '443',
      options           => 'check',
    }
  }

}

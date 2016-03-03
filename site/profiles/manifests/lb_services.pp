class profiles::lb_services {

  $listeners        = hiera('profiles::lb_services::listeners',undef)
  $enable_firewall  = hiera('profiles::lb_services::enable_firewall')

  Firewall {
    before  => Class['profiles::fw::post'],
    require => Class['profiles::fw::pre'],
  }

  @@host { 'puppet.puppetlabs.vm':
    ensure       => present,
    host_aliases => ['puppet'],
    ip           => $::ipaddress_eth1,
  }

  include haproxy

  if $listeners {
    $listeners.each |$key,$value| {
      haproxy::listen { $key:
        collect_exported => $value['collect_exported'],
        ipaddress        => $value['ipaddress'],
        ports            => $value['ports'],
        options          => $value['options'],
      }

      if $enable_firewall {
        firewall { "100 ${key}":
          port   => [$value['ports']],
          proto  => 'tcp',
          action => 'accept',
        }
      }
    }
  }

}

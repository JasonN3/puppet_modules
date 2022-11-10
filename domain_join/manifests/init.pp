# This class will domain join a system to Active Directory
# The machine's hostname should be set to the FQDN
#
# @param username           The username used to domain join
# @param sensitive_password The password used to domain join
# @param global_admins      An AD group that will have full sudo access on all machines. This will also include ssh access
# @param global_ssh         Ad AD group that will have ssh access to all machines. Sudo privileges can be specified separately
# @param local_admins       A template for an AD group that will have full sudo access on the specific machine. `%HOSTNAME%` will be 
#                           replaced with the machine's shortname
# @param local_ssh          A template for an AD group that will have ssh access to the specific machine. `%HOSTNAME%` will be replaced 
#                           with the machine's shortname
# @param sssd_home          The directory where all home directories should be created. Defaults to /home
# @param override_domain    Force the name of the domain to join. This can allow the machine's hostname to be set to the short name, but
#                           with less sucess
# @param domain_short       The NetBIOS name for the domain
# @param dns_subdomain      The subdomain that the dns records should be registered to. Example: for machine1.sd.example.com, sd would be
#                           the subdomain
# @param dnsupdate          If SSSD should create the dns record for the machine. Secure updates are supported
# @param file_header        A commented header to put on each of the managed files
# @param time_servers       A list of time servers. The domain will automatically be added to the end of the list
class domainjoin (
  String            $username,
  Sensitive[String] $sensitive_password,
  String            $global_admins,
  String            $global_ssh,
  String            $local_admins,
  String            $local_ssh,
  String            $sssd_home = '/home',
  String            $override_domain = undef,
  String            $domain_short = undef,
  String            $dns_subdomain = undef,
  Boolean           $dnsupdate = true,
  String            $file_header = undef,
  Array             $time_servers = []
) {
  if $override_domain {
    $currdomain = $override_domain
    # This is only used if $override_domain is defined
    $forced_fqdn = sprintf('%s.%s', $facts['networking']['hostname'], $currdomain)
  } else {
    if $dns_subdomain {
      $currdomain = regsubst($facts['networking']['domain'], "${dns_subdomain}\\.", '')
    } else {
      $currdomain = $facts['networking']['domain']
    }
  }

  if $domain_short {
    $shortdomain = split($currdomain, '[.]')[0]
  } else {
    $shortdomain = $domain_short
  }

  class { 'chrony':
    servers => $time_servers + [$currdomain],
  }

  package { 'adcli':
    ensure => installed,
  }

  case $facts['os']['family'] {
    'RedHat': {
      package { 'krb5-workstation':
        ensure => installed,
      }
      package { 'samba-common-tools':
        ensure => installed,
      }
    }
    'Debian': {
      package { 'krb5-workstation':
        ensure => installed,
        name   => 'krb5-user',
      }
      package { 'samba-common-tools':
        ensure => installed,
        name   => 'samba-common-bin',
      }
    }
    default: {
      err('Unknown OS')
    }
  }
  package { 'oddjob-mkhomedir':
    ensure => installed,
  }
  package { 'samba-common':
    ensure => installed,
  }
  package { 'sssd':
    ensure => installed,
  }

  if($override_domain != '') {
    # lint:ignore:strict_indent
    $command = Sensitive(@("EOT"/)
      bash -c '
        source /etc/os-release; 
        echo -n \"${$sensitive_password.unwrap}\" | 
          adcli join 
            -H ${forced_fqdn} 
            -D ${currdomain} 
            -U \"${username}\" 
            --stdin-password 
            --os-name=\"\${NAME}\" 
            --os-version=\"\${VERSION}\" 
            --os-service-pack=\"\${VERSION_ID}\"
        '
      EOT
    )
    # lint:endignore
  } else {
    # lint:ignore:strict_indent
    $command = Sensitive(@("EOT"/)
      bash -c '
        source /etc/os-release; 
        echo -n \"${$sensitive_password.unwrap}\" | 
          adcli join 
            -D ${currdomain} 
            -U \"${username}\" 
            --stdin-password 
            --os-name=\"\${NAME}\" 
            --os-version=\"\${VERSION}\" 
            --os-service-pack=\"\${VERSION_ID}\"
        '
      EOT
    )
    # lint:endignore
  }

  exec { 'Join':
    command => $command,
    path    => '/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin',
    notify  => Service['sssd'],
    creates => '/etc/krb5.keytab',
    require => [
      Package['adcli'],
      Package['krb5-workstation'],
      Package['samba-common'],
      Package['samba-common-tools'],
      Package['sssd'],
      File['/etc/krb5.conf'],
      File['/etc/samba/smb.conf'],
      File['/etc/sssd/sssd.conf'],
    ],
  }

  file { '/etc/krb5.conf':
    ensure  => file,
    content => template('domainjoin/krb5.conf.erb'),
    notify  => Service['sssd'],
    require => Package['krb5-workstation'],
  }

  file { '/etc/samba/smb.conf':
    ensure  => file,
    content => template('domainjoin/smb.conf.erb'),
    notify  => Service['sssd'],
    require => Package['samba-common'],
  }

  file { '/etc/sssd/sssd.conf':
    ensure  => file,
    content => template('domainjoin/sssd.conf.erb'),
    owner   => root,
    group   => root,
    mode    => '0400',
    notify  => Service['sssd'],
    require => Package['sssd'],
  }

  file { '/var/log/sssd/':
    ensure  => directory,
    owner   => sssd,
    group   => sssd,
    require => Package['sssd'],
  }

  service { 'oddjobd':
    ensure  => running,
    enable  => true,
    require => Package['oddjob-mkhomedir'],
  }

  file { '/etc/sudoers.d/admins':
    ensure  => file,
    content => template('domainjoin/sudoers.erb'),
  }

  case $facts['os']['family'] {
    'Debian': {
      $enablesssd = 'pam-auth-update --enable mkhomedir'
      Package { 'authconfig':
        ensure => installed,
        name   => libpam-runtime,
      }
      package { 'libpam-sss':
        ensure => installed,
        before => Package['authconfig'],
      }
      package { 'libnss-sss':
        ensure => installed,
        before => Package['authconfig'],
      }
    }

    'RedHat': {
      case $facts['os']['release']['major'] {
        '7': {
          $enablesssd = 'authconfig --enablesssd --enablesssdauth --enablemkhomedir --update'
          package { 'authconfig':
            ensure => installed,
          }
        }
        '8': {
          $enablesssd = 'authselect select sssd with-mkhomedir --force'
          package { 'authconfig':
            ensure => installed,
            name   => authselect,
          }
        }
        '9': {
          $enablesssd = 'authselect select sssd with-mkhomedir --force'
          package { 'authconfig':
            ensure => installed,
            name   => authselect,
          }
        }
        default: {
          err('Unknown OS')
        }
      }
    }

    default: {
      err('Unknown OS')
    }
  }

  exec { 'Enable SSSD Authentication':
    command     => $enablesssd,
    subscribe   => [
      Exec['Join'],
    ],
    path        => $facts['path'],
    refreshonly => true,
    require     => [
      Package['authconfig'],
      Package['oddjob-mkhomedir'],
      Service['oddjobd'],
      Package['sssd'],
      Service['sssd'],
    ],
  }

  service { 'sssd':
    ensure  => running,
    enable  => true,
    require => [
      File['/etc/sssd/sssd.conf'],
      File['/var/log/sssd'],
      Package['sssd'],
    ],
  }

  if $facts['mountpoints']['/']['device'] == 'overlay' {
    file_line { 'remove systemd from system-auth':
      ensure            => absent,
      path              => '/etc/pam.d/system-auth',
      line              => '',
      match             => '.*pam_systemd\.so.*',
      match_for_absence => true,
      require           => Exec['Enable SSSD Authentication'],
    }

    file_line { 'remove systemd from password-auth':
      ensure            => absent,
      path              => '/etc/pam.d/password-auth',
      match             => '.*pam_systemd\.so.*',
      match_for_absence => true,
      require           => Exec['Enable SSSD Authentication'],
    }
  }
}

# Library class that will install vault
# This class should not be directly called
#
class hashicorp_vault::lib_binary {
  case $facts['os']['family'] {
    'RedHat': {
      file { '/etc/yum.repos.d/vault.repo':
        source => 'https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo',
        owner  => root,
        group  => root,
        mode   => '0444',
      }

      package { 'vault':
        ensure => present,
      }
    }
    'Debian': {
      file { '/etc/apt/sources.list.d/hashicorp.list':
        content => "deb https://apt.releases.hashicorp.com ${$facts['os']['distro']['codename']} main",
        owner   => root,
        group   => root,
        mode    => '0444',
      }

      file { '/etc/apt/trusted.gpg.d/hashicorp.gpg':
        content => file('vault/hashicorp.gpg'),
        owner   => root,
        group   => root,
        mode    => '0444',
        before  => File['/etc/apt/sources.list.d/hashicorp.list'],
      }

      package { 'vault':
        ensure => present,
      }
    }
    default: {
      fail('Unknown OS')
    }
  }
}

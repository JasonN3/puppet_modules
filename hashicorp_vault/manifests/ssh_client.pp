# This class will configure the function `vault_ssh` to make it easier to ssh to machines using keys signed by Hashicorp Vault
# Usage: `vault_ssh ${server}`
#
# @param vault_server       The url for the Hashicorp Vault server
# @param auth_method        The authentication method that will be used with Hasicorp Vault
class hashicorp_vault::ssh_client (
  String $vault_server,
  Enum['ldap'] $auth_method
) {
  require hashicorp_vault::lib_binary

  file { '/etc/profile.d/vault_ssh.sh':
    content => template('vault/vault_ssh.sh.erb'),
    owner   => root,
    group   => root,
    mode    => '0444',
  }
}

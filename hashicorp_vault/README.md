# hashicorp_vault Module


Configires the node to use client/host certificates from Hashicorp Vault
## Class hashicorp_vault::ssh_client
 This class will configure the function `vault_ssh` to make it easier to ssh to machines using keys signed by Hashicorp Vault  
 Usage: `vault_ssh ${server}`  
### Parameters
|Name|Description|
|---|---|
|vault_server|      The url for the Hashicorp Vault server|
|auth_method|       The authentication method that will be used with Hasicorp Vault|

---

## Class hashicorp_vault::ssh_server
 This class will configure the node to use a host key signed by Hashicorp Vault  
 Authentication to the Vault server will be done using the Puppet node's certificate  
### Parameters
|Name|Description|
|---|---|
|vault_server|      The url for the Hashicorp Vault server|
|vault_public_key|  The public key from the SSH engine that will be trusted. vault_ssh_engine is not needed if this is defined|
|vault_ssh_engine|  The engine name within the Hashicorp Vault server for the ssh CA so the key can be downloaded from the server. vault_public_key is not needed if this is defined.<br />NOTICE: Because Hashicorp Vault dynamically generates the page, Puppet will always see the file as changed and will re-write the CA file.|

---


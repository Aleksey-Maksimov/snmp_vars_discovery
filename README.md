## About

**snmp_vars_discovery** - Icinga Plugin Script (Check Command) for pull Icinga Host variables from SNMP data

Tested on **Debian GNU/Linux 9.11 (stretch)** with **Icinga r2.11.1-1** / **Director 1.7.1** / **NET-SNMP 5.7.3**

PreReq: **snpmget** tool

 
## Usage

Options:

```
$ ./snmp_vars_discovery.sh [OPTIONS]

Option  GNU long option   Meaning
------  ---------------   -------
 -H     --hostname        Host name (Icinga object Host.name)
 -h     --hostaddr        Host address (Icinga object Host.address)
 -P     --protocol        SNMP protocol version. Possible values: 1|2c|3
 -C     --community       SNMPv1/2c community string for SNMP communication (for example,public)
 -L     --seclevel        SNMPv3 securityLevel. Possible values: noAuthNoPriv|authNoPriv|authPriv
 -a     --authproto       SNMPv3 auth proto. Possible values: MD5|SHA
 -x     --privproto       SNMPv3 priv proto. Possible values: DES|AES
 -U     --secname         SNMPv3 username
 -A     --authpassword    SNMPv3 authentication password
 -X     --privpasswd      SNMPv3 privacy password
 -q     --help            Show this message
 -v     --version         Print version information and exit
 ```
Usage example for SNMPv1:

```
$ ./snmp_vars_discovery.sh -H netdev10.holding.com -h 10.10.10.10 -P 1 -C public
```

Usage example for SNMPv3:

```
$ ./snmp_vars_discovery.sh -H netdev10.holding.com -h 10.10.10.10 \
-P 3 -L authPriv -U icinga -a MD5 -A myAuthPwD -x DES -X myPrivPwd
```
Icinga Director integration manual (in Russian):

[Icinga плагин snmp_vars_discovery для инвентаризации расширенного набора свойств Хостов по данным, полученным по SNMP (для использования с Icinga Director)](https://blog.it-kb.ru/2017/11/05/icinga-plugin-snmp_vars_discovery-for-inventory-of-extended-host-properties-obtained-via-snmp-for-use-with-icinga-director-and-icingacli/)

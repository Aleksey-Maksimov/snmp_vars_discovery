#!/bin/sh
#
# Icinga Plugin Script (Check Command) for pull Icinga Host variables from SNMP data
# Aleksey Maksimov <aleksey.maksimov@it-kb.ru>
# Tested on Debian GNU/Linux 8.7 (Jessie) with Icinga r2.6.2-1 / Director 1.3.1 / NET-SNMP 5.7.2.1
# Put here /usr/lib/nagios/plugins/snmp_vars_discovery.sh
#
PLUGIN_NAME="Icinga Plugin Check Command for pull Icinga Host variables (from SNMP data)"
PLUGIN_VERSION="2017.05.24"
PRINTINFO=`printf "\n%s, version %s\n \n" "$PLUGIN_NAME" "$PLUGIN_VERSION"`
#
# Exit codes
#
codeOK=0
codeWARNING=1
codeCRITICAL=2
codeUNKNOWN=3


# ---------- Script options help ----------
#
Usage() {
  echo "$PRINTINFO"
  echo "Usage: $0 [OPTIONS]

Option   GNU long option        Meaning
------   ---------------        -------
 -H      --hostname             Host name (Icinga object Host.name)
 -h      --hostaddr             Host address (Icinga object Host.address)
 -P      --protocol             SNMP protocol version. Possible values: 1|2c|3
 -C      --community            SNMPv1/2c community string for SNMP communication (for example,"public")
 -L      --seclevel             SNMPv3 securityLevel. Possible values: noAuthNoPriv|authNoPriv|authPriv
 -a      --authproto            SNMPv3 auth proto. Possible values: MD5|SHA
 -x      --privproto            SNMPv3 priv proto. Possible values: DES|AES
 -U      --secname              SNMPv3 username
 -A      --authpassword         SNMPv3 authentication password
 -X      --privpasswd           SNMPv3 privacy password
 -q      --help                 Show this message
 -v      --version              Print version information and exit

Usage examples.
For SNMPv1:
$0 -H netdev10.holding.com -h 10.10.10.10 -P 1 -C public
For SNMPv3:
$0 -H netdev10.holding.com -h 10.10.10.10 -P 3 -L authPriv -U icinga -a MD5 -A myAuthPzwD -x DES -X myPrivPw0d

"
}


# ---------- Parse script arguments ----------
#
if [ -z $1 ]; then
    Usage; exit $codeUNKNOWN;
fi
#
OPTS=`getopt -o H:h:P:C:L:a:x:U:A:X:qv -l hostname:,hostaddr:,protocol:,community:,seclevel:,authproto:,privproto:,secname:,authpassword:,privpasswd:,help,version -- "$@"`
eval set -- "$OPTS"
while true; do
   case $1 in
     -H|--hostname) HOSTNAME=$2 ; shift 2 ;;
     -h|--hostaddr) HOST=$2 ; shift 2 ;;
     -P|--protocol)
        case "$2" in
        "1"|"2c"|"3") PROTOCOL=$2 ; shift 2 ;;
        *) printf "Unknown value for option %s. Use '1' or '2c' or '3'\n" "$1" ; exit $codeUNKNOWN ;;
        esac ;;
     -C|--community)     COMMUNITY=$2 ; shift 2 ;;
     -L|--seclevel)
        case "$2" in
        "noAuthNoPriv"|"authNoPriv"|"authPriv") v3SECLEVEL=$2 ; shift 2 ;;
        *) printf "Unknown value for option %s. Use 'noAuthNoPriv' or 'authNoPriv' or 'authPriv'\n" "$1" ; exit $codeUNKNOWN ;;
        esac ;;
     -a|--authproto)
        case "$2" in
        "MD5"|"SHA") v3AUTHPROTO=$2 ; shift 2 ;;
        *) printf "Unknown value for option %s. Use 'MD5' or 'SHA'\n" "$1" ; exit $codeUNKNOWN ;;
        esac ;;
     -x|--privproto)
        case "$2" in
        "DES"|"AES") v3PRIVPROTO=$2 ; shift 2 ;;
        *) printf "Unknown value for option %s. Use 'DES' or 'AES'\n" "$1" ; exit $codeUNKNOWN ;;
        esac ;;
     -U|--secname)       v3SECNAME=$2 ; shift 2 ;;
     -A|--authpassword)  v3AUTHPWD=$2 ; shift 2 ;;
     -X|--privpasswd)    v3PRIVPWD=$2 ; shift 2 ;;
     -q|--help)          Usage ; exit $codeOK ;;
     -v|--version)       echo "$PRINTINFO" ; exit $codeOK ;;
     --) shift ; break ;;
     *)  Usage ; exit $codeUNKNOWN ;;
   esac
done


# ---------- Set SNMP connection paramaters ----------
#
vCS=$( echo " -O qvn -v $PROTOCOL" )
if [ "$PROTOCOL" = "1" ] || [ "$PROTOCOL" = "2c" ]
then
   vCS=$vCS$( echo " -c $COMMUNITY" );
elif [ "$PROTOCOL" = "3" ]
then
   vCS=$vCS$( echo " -l $v3SECLEVEL" );
   vCS=$vCS$( echo " -a $v3AUTHPROTO" );
   vCS=$vCS$( echo " -x $v3PRIVPROTO" );
   vCS=$vCS$( echo " -A $v3AUTHPWD" );
   vCS=$vCS$( echo " -X $v3PRIVPWD" );
   vCS=$vCS$( echo " -u $v3SECNAME" );
fi
if [ -z "$HOST" ]
then
   HOST=$HOSTNAME
fi
vCS=$vCS$( echo " $HOST" );


# ---------- Pull variables for all SNMP Devices ----------
#
v1=$( snmpget $vCS 1.3.6.1.2.1.1.1.0 | sed "s/\"//g" );  icingacli director host set $HOSTNAME --vars.snmp_SNMPv2_MIB_sysDescr "$v1" > /dev/null;
v2=$( snmpget $vCS 1.3.6.1.2.1.1.2.0 | cut -c2- );       icingacli director host set $HOSTNAME --vars.snmp_SNMPv2_MIB_sysObjectID "$v2" > /dev/null;
v4=$( snmpget $vCS 1.3.6.1.2.1.1.4.0 | sed "s/\"//g" );  icingacli director host set $HOSTNAME --vars.snmp_SNMPv2_MIB_sysContact "$v4" > /dev/null;
v5=$( snmpget $vCS 1.3.6.1.2.1.1.5.0 | sed "s/\"//g" );  icingacli director host set $HOSTNAME --vars.snmp_SNMPv2_MIB_sysName "$v5" > /dev/null;
v6=$( snmpget $vCS 1.3.6.1.2.1.1.6.0 | sed "s/\"//g" );  icingacli director host set $HOSTNAME --vars.snmp_SNMPv2_MIB_sysLocation "$v6" > /dev/null;

# ---------- Pull variables for Digi AnywhereUSB ----------
#
if echo "$v2" | grep -q -E "1.3.6.1.4.1.332.11.6"
then
   var1=$( snmpget $vCS 1.3.6.1.4.1.332.11.6.1.4.0 | sed "s/\"//g" );  icingacli director host set $HOSTNAME --vars.snmp_DIGI_DEVICE_INFO_MIB_diBootVersion "$var1" > /dev/null;
   var2=$( snmpget $vCS 1.3.6.1.4.1.332.11.6.1.2.0 | sed "s/\"//g" );  icingacli director host set $HOSTNAME --vars.snmp_DIGI_DEVICE_INFO_MIB_diPhysicalAddress "$var2" > /dev/null;
   var3=$( snmpget $vCS 1.3.6.1.4.1.332.11.6.1.3.0 | sed "s/\"//g" );  icingacli director host set $HOSTNAME --vars.snmp_DIGI_DEVICE_INFO_MIB_diFirmwareVersion "$var3" > /dev/null;
   var4=$( snmpget $vCS 1.3.6.1.4.1.332.11.6.1.1.0 | sed "s/\"//g" );  icingacli director host set $HOSTNAME --vars.snmp_DIGI_DEVICE_INFO_MIB_diProduct "$var4" > /dev/null;
   var5=$( snmpget $vCS 1.3.6.1.4.1.332.11.6.1.5.0 | sed "s/\"//g" );  icingacli director host set $HOSTNAME --vars.snmp_DIGI_DEVICE_INFO_MIB_diPostVersion "$var5" > /dev/null;
fi


# ---------- Pull variables for Eaton UPS ----------
#
if echo "$v2" | grep -q -E "1.3.6.1.4.1.(534|705).1"
then
   var1=$( snmpget $vCS 1.3.6.1.2.1.2.2.1.6.2 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//;s/ /:/g" );      icingacli director host set $HOSTNAME --vars.snmp_IF_MIB_ifPhysAddress "$var1" > /dev/null;
   var2=$( snmpget $vCS 1.3.6.1.2.1.33.1.1.1.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );             icingacli director host set $HOSTNAME --vars.snmp_UPS_MIB_upsIdentManufacturer "$var2" > /dev/null;
   var3=$( snmpget $vCS 1.3.6.1.2.1.33.1.1.2.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );             icingacli director host set $HOSTNAME --vars.snmp_UPS_MIB_upsIdentModel "$var3" > /dev/null;
   var4=$( snmpget $vCS 1.3.6.1.2.1.33.1.1.3.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );             icingacli director host set $HOSTNAME --vars.snmp_UPS_MIB_upsIdentUPSSoftwareVersion "$var4" > /dev/null;
   var5=$( snmpget $vCS 1.3.6.1.2.1.33.1.1.4.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );             icingacli director host set $HOSTNAME --vars.snmp_UPS_MIB_upsIdentAgentSoftwareVersion "$var5" > /dev/null;
   var6=$( snmpget $vCS 1.3.6.1.2.1.33.1.1.5.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//;s/  \+/ /g" );  icingacli director host set $HOSTNAME --vars.snmp_UPS_MIB_upsIdentName "$var6" > /dev/null;
   var7=$( snmpget $vCS 1.3.6.1.4.1.534.1.10.8.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );           icingacli director host set $HOSTNAME --vars.snmp_XUPS_MIB_xupsConfigInstallDate "$var7" > /dev/null;
   var8=$( snmpget $vCS 1.3.6.1.4.1.534.1.2.6.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );            icingacli director host set $HOSTNAME --vars.snmp_XUPS_MIB_xupsBatteryLastRep "$var8" > /dev/null;
fi


# ---------- Pull variables for HP UPS ----------
#
if echo "$v2" | grep -q -E "1.3.6.1.4.1.232.165.3"
then
   var1=$( snmpget $vCS 1.3.6.1.4.1.232.165.1.2.1.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );  icingacli director host set $HOSTNAME --vars.snmp_CPQPOWER_MIB_deviceManufacturer "$var1" > /dev/null;
   var2=$( snmpget $vCS 1.3.6.1.4.1.232.165.1.2.2.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );  icingacli director host set $HOSTNAME --vars.snmp_CPQPOWER_MIB_deviceModel "$var2" > /dev/null;
   var3=$( snmpget $vCS 1.3.6.1.4.1.232.165.1.2.6.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );  icingacli director host set $HOSTNAME --vars.snmp_CPQPOWER_MIB_devicePartNumber "$var3" > /dev/null;
   var4=$( snmpget $vCS 1.3.6.1.4.1.232.165.1.2.8.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" | tr [a-z] [A-Z] | sed "s/ /:/g" ); icingacli director host set $HOSTNAME --vars.snmp_CPQPOWER_MIB_deviceMACAddress "$var4" > /dev/null;
   var5=$( snmpget $vCS 1.3.6.1.4.1.232.165.1.2.7.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );  icingacli director host set $HOSTNAME --vars.snmp_CPQPOWER_MIB_deviceSerialNumber "$var5" > /dev/null;
   var6=$( snmpget $vCS 1.3.6.1.4.1.232.165.1.2.3.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );  icingacli director host set $HOSTNAME --vars.snmp_CPQPOWER_MIB_deviceFirmwareVersion "$var6" > /dev/null;
   var7=$( snmpget $vCS 1.3.6.1.4.1.232.165.1.2.4.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );  icingacli director host set $HOSTNAME --vars.snmp_CPQPOWER_MIB_deviceHardwareVersion "$var7" > /dev/null;
   var8=$( snmpget $vCS 1.3.6.1.4.1.232.165.3.1.1.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );  icingacli director host set $HOSTNAME --vars.snmp_CPQPOWER_MIB_upsIdentManufacturer "$var8" > /dev/null;
   var9=$( snmpget $vCS 1.3.6.1.4.1.232.165.3.1.2.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );  icingacli director host set $HOSTNAME --vars.snmp_CPQPOWER_MIB_upsIdentModel "$var9" > /dev/null;
   var10=$( snmpget $vCS 1.3.6.1.4.1.232.165.3.1.3.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );  icingacli director host set $HOSTNAME --vars.snmp_CPQPOWER_MIB_upsIdentSoftwareVersions "$var10" > /dev/null;
   var11=$( snmpget $vCS 1.3.6.1.4.1.232.165.1.1.4.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//;s/  \+/ \; /g" );  icingacli director host set $HOSTNAME --vars.snmp_CPQPOWER_MIB_trapDeviceDetails "$var11" > /dev/null;
fi

# ---------- Pull variables for APC UPS ----------
#
if echo "$v2" | grep -q -E "1.3.6.1.4.1.318.1.3.(2|2.7|2.13|5.1)"
then
   var1=$( snmpget $vCS 1.3.6.1.2.1.2.2.1.6.2 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//;s/ /:/g" );    icingacli director host set $HOSTNAME --vars.snmp_IF_MIB_ifPhysAddress "$var1" > /dev/null;
   var2=$( snmpget $vCS 1.3.6.1.4.1.318.1.1.1.1.1.1.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );    icingacli director host set $HOSTNAME --vars.snmp_PowerNet_MIB_upsBasicIdentModel "$var2" > /dev/null;
   var3=$( snmpget $vCS 1.3.6.1.4.1.318.1.1.1.1.1.2.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );    icingacli director host set $HOSTNAME --vars.snmp_PowerNet_MIB_upsBasicIdentName "$var3" > /dev/null;
   var4=$( snmpget $vCS 1.3.6.1.4.1.318.1.1.1.1.2.1.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );    icingacli director host set $HOSTNAME --vars.snmp_PowerNet_MIB_upsAdvIdentFirmwareRevision "$var4" > /dev/null;
   var5=$( snmpget $vCS 1.3.6.1.4.1.318.1.1.1.1.2.2.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );    icingacli director host set $HOSTNAME --vars.snmp_PowerNet_MIB_upsAdvIdentDateOfManufacture "$var5" > /dev/null;
   var6=$( snmpget $vCS 1.3.6.1.4.1.318.1.1.1.1.2.3.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );    icingacli director host set $HOSTNAME --vars.snmp_PowerNet_MIB_upsAdvIdentSerialNumber "$var6" > /dev/null;
   var7=$( snmpget $vCS 1.3.6.1.4.1.318.1.1.1.7.2.7.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );    icingacli director host set $HOSTNAME --vars.snmp_PowerNet_MIB_upsAdvTestCalibrationDate "$var7" > /dev/null;
   var8=$( snmpget $vCS 1.3.6.1.4.1.318.1.1.1.2.1.3.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );    icingacli director host set $HOSTNAME --vars.snmp_PowerNet_MIB_upsBasicBatteryLastReplaceDate "$var8" > /dev/null;
   var9=$( snmpget $vCS 1.3.6.1.4.1.318.1.1.1.2.2.5.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );    icingacli director host set $HOSTNAME --vars.snmp_PowerNet_MIB_upsAdvBatteryNumOfBattPacks "$var9" > /dev/null;
   var10=$( snmpget $vCS 1.3.6.1.4.1.318.1.1.1.3.1.1.0 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );   icingacli director host set $HOSTNAME --vars.snmp_PowerNet_MIB_upsBasicInputPhase "$var10" > /dev/null; 
   var11=$( snmpget $vCS 1.3.6.1.4.1.318.1.4.2.4.1.2.1 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );   icingacli director host set $HOSTNAME --vars.snmp_PowerNet_MIB_expNmcSerialNumber "$var11" > /dev/null;
   var12=$( snmpget $vCS 1.3.6.1.4.1.318.1.4.2.4.1.4.1 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );   icingacli director host set $HOSTNAME --vars.snmp_PowerNet_MIB_expNmcAOSVersion "$var12" > /dev/null;
   var13=$( snmpget $vCS 1.3.6.1.4.1.318.1.4.2.4.1.4.2 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );   icingacli director host set $HOSTNAME --vars.snmp_PowerNet_MIB_expNmcAppVersion "$var13" > /dev/null;
   var14=$( snmpget $vCS 1.3.6.1.4.1.318.1.4.2.4.1.3.1 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );   icingacli director host set $HOSTNAME --vars.snmp_PowerNet_MIB_expNmcAOSFile "$var14" > /dev/null;
   var15=$( snmpget $vCS 1.3.6.1.4.1.318.1.4.2.4.1.3.2 | sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//" );   icingacli director host set $HOSTNAME --vars.snmp_PowerNet_MIB_expNmcAppFile "$var15" > /dev/null;
fi

# ---------- Deploy Icinga Director Configuration ----------
#
vDeploy=$( icingacli director config deploy )


# ---------- Icinga Check Plugin output ----------
#
if echo "$vDeploy" | grep -q "nothing to do"
then
    echo "SNMP OK - Last check no changes found"
    exit $codeOK
elif echo "$vDeploy" | grep -q "has been deployed"
then
    echo "SNMP OK - $vDeploy"
    exit $codeOK
fi
#
echo "$vDeploy"
exit $codeUNKNOWN


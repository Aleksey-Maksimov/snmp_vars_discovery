#!/bin/sh
#
# Icinga Plugin Script (Check Command) for pull Icinga Host variables from SNMP data
# Aleksey Maksimov <aleksey.maksimov@it-kb.ru>
# Tested on Debian GNU/Linux 9.11 (stretch) with Icinga r2.11.1-1 / Director 1.7.1 / NET-SNMP 5.7.3
# Put here /usr/lib/nagios/plugins/snmp_vars_discovery.sh
#
PLUGIN_NAME="Icinga Plugin Check Command for pull Icinga Host variables (from SNMP data)"
PLUGIN_VERSION="2019.12.01"
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

Option   GNU long option     Meaning
------   ---------------     -------
 -H      --hostname          Host name (Icinga object Host.name)
 -h      --hostaddr          Host address (Icinga object Host.address)
 -P      --protocol          SNMP protocol version. Possible values: 1|2c|3
 -C      --community         SNMPv1/2c community string for SNMP communication (for example,"public")
 -L      --seclevel          SNMPv3 securityLevel. Possible values: noAuthNoPriv|authNoPriv|authPriv
 -a      --authproto         SNMPv3 auth proto. Possible values: MD5|SHA
 -x      --privproto         SNMPv3 priv proto. Possible values: DES|AES
 -U      --secname           SNMPv3 username
 -A      --authpassword      SNMPv3 authentication password
 -X      --privpasswd        SNMPv3 privacy password
 -q      --help              Show this message
 -v      --version           Print version information and exit

Usage examples.
For SNMPv1:
$0 -H netdev10.holding.com -h 10.10.10.10 -P 1 -C public
For SNMPv2:
$0 -H netdev10.holding.com -h 10.10.10.10 -P 2c -C public
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


# ---------- Get SNMP-data function ----------

GetData()
{
  fRes=$(snmpget $vCS $1 2>&1)
  rcode=$?
  if [ "$rcode" -ne "0" ]; then
    echo "Plugin error: $(echo $fRes |  cut -c1-100)"
    return 1
  fi

  if echo "$fRes" | grep -q "No Such Object available on this agent at this OID"
  then
    echo "Plugin error: $fRes - $1"
    return 1
  fi

  # Data Normalization for Icinga
  # seсtion "s/\"//g" -  double quotes are removed
  # section "s/^[ \t]*//"
  # section "s/[ \t]*$//"
  # section "s/  \+/ \; /g"
  # section 'tr -d "\n"' - simbols "\n" (LF, new line) are removed
  # section 'tr "\r" " "' - simbols "\r" (CR, carage return) replace by space
  #
  echo "$fRes" |  sed "s/\"//g;s/^[ \t]*//;s/[ \t]*$//;s/  \+/ \; /g" | tr -d "\n" | tr "\r" " " 
}


# ---------- Update Host in Icinga Director ---------
SetData()
{
   if [ "$1" != "" ]; then
      #echo "DEBUG: To var '$2' write value '$1'"
      icingacli director host set $HOSTNAME --vars.$2 "$1" > /dev/null;
      #icingacli director host set $HOSTNAME --vars.$2 "$1"
   fi
}


# ---------- First SNMP check -----------------
#
# If the OID 1.3.6.1.2.1.1.2.0 is not available, exit the script
#
vOID=$( GetData '1.3.6.1.2.1.1.2.0' ); if [ $? -ne "0" ]; then echo "$vOID"; exit $codeUNKNOWN; fi; SetData "$vOID" "snmp_SNMPv2_MIB_sysObjectID";


#  ---------- Pull variables for all SNMP Devices ----------
#
vData=$( GetData '1.3.6.1.2.1.1.1.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_SNMPv2_MIB_sysDescr";
vData=$( GetData '1.3.6.1.2.1.1.4.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_SNMPv2_MIB_sysContact";
vData=$( GetData '1.3.6.1.2.1.1.5.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_SNMPv2_MIB_sysName";
vData=$( GetData '1.3.6.1.2.1.1.6.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_SNMPv2_MIB_sysLocation";


# ---------- Pull variables for Cisco Switches/Routers ----------
#
vSibID=""
#
# 1.3.6.1.4.1.9.1.324     Switch Cisco Catalyst WS-C2950T-24
# 1.3.6.1.4.1.9.1.559     Switch Cisco Catalyst_WS-C2950T-48-SI
# 1.3.6.1.4.1.9.1.1042    Router Cisco 3925
# 1.3.6.1.4.1.9.1.1644    Switch Cisco Catalyst WS-C3850-24T
# 1.3.6.1.4.1.9.1.1745    Switch Cisco Catalyst WS-C3850-24T
#
if echo "$vOID" | grep -q -E "1.3.6.1.4.1.9.1.(324|559|1042|1644|1745)"
then vSubID="1"
#
# 1.3.6.1.4.1.9.1.516     Switch Cisco Catalyst WS-C3750G-24TS-S1U ; Switch Cisco Catalyst WS-C3750V2-24TS-S
# 1.3.6.1.4.1.9.1.563     Switch Cisco Catalyst WS-C3560-24PS-S
# 1.3.6.1.4.1.9.1.615     Switch Cisco Catalyst WS-C3560G-24TS-E
# 1.3.6.1.4.1.9.1.696     Switch Cisco Catalyst WS-C2960G-24TC-L
# 1.3.6.1.4.1.9.1.702     Switch Cisco EtherSwitch NME-16ES-1G
# 1.3.6.1.4.1.9.1.928     Switch Cisco Catalyst WS-C2960+24TC-S
# 1.3.6.1.4.1.9.1.1208    Switch Cisco Catalyst WS-C2960X-48TD-L ; Switch Cisco Catalyst WS-C2960X-24PS-L
# 1.3.6.1.4.1.9.1.1227    Switch Cisco Catalyst WS-C3560X-48T-L
# 1.3.6.1.4.1.9.1.1229    Switch Cisco Catalyst WS-C3560X-48T-L
# 1.3.6.1.4.1.9.1.1367    Switch Cisco Catalyst WS-C2960C-12PC-L
# 1.3.6.1.4.1.9.1.1757    Switch Cisco Catalyst WS-C2960+24TC-S
#
elif echo "$vOID" | grep -q -E "1.3.6.1.4.1.9.1.(516|563|615|696|702|928|1208|1227|1229|1367|1757)"
then vSubID="1001"
#
# 1.3.6.1.4.1.9.6.1.87.24.1     Switch Cisco SF200-24P
# 1.3.6.1.4.1.9.6.1.88.50.2     Switch Cisco SG200-50P
#
elif echo "$vOID" | grep -q -E "1.3.6.1.4.1.9.6.1.(87.24.1|88.50.2)"
then vSubID="67108992"
#
# 1.3.6.1.4.1.9.6.1.92.24.5   Switch Cisco SF550X-24P
# 1.3.6.1.4.1.9.6.1.94.48.6   Switch Cisco SG350X-48MP
# 1.3.6.1.4.1.9.6.1.95.10.5   Switch Cisco SG350-10P-K9
#
elif echo "$vOID" | grep -q -E "1.3.6.1.4.1.9.6.1.(92.24.5|94.48.6|95.10.5)"
then vSubID="67109120"
#
#
fi
if [ "$vSubID" != "" ]; then
  vData=$( GetData '1.3.6.1.2.1.47.1.1.1.1.2.'$vSubID );  if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_ENTITY_MIB_entPhysicalDescr";
  vData=$( GetData '1.3.6.1.2.1.47.1.1.1.1.8.'$vSubID );  if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_ENTITY_MIB_entPhysicalHardwareRev";
  vData=$( GetData '1.3.6.1.2.1.47.1.1.1.1.9.'$vSubID );  if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_ENTITY_MIB_entPhysicalFirmwareRev";
  vData=$( GetData '1.3.6.1.2.1.47.1.1.1.1.10.'$vSubID ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_ENTITY_MIB_entPhysicalSoftwareRev";
  vData=$( GetData '1.3.6.1.2.1.47.1.1.1.1.11.'$vSubID ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_ENTITY_MIB_entPhysicalSerialNum";
  vData=$( GetData '1.3.6.1.2.1.47.1.1.1.1.13.'$vSubID ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_ENTITY_MIB_entPhysicalModelName";
fi


# ---------- Pull variables for D-Link Switches ----------
#
# 1.3.6.1.4.1.171.10.75.18.1	Switch D-Link DES-1210-28
#
if echo "$vOID" | grep -q -E "1.3.6.1.4.1.171.10.75.18.1"
then
  vData=$( GetData '1.3.6.1.4.1.171.10.75.18.1.1.2.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_DES_1210_28_MIB_sysHardwareVersion";
  vData=$( GetData '1.3.6.1.4.1.171.10.75.18.1.1.3.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_DES_1210_28_MIB_sysFirmwareVersion";
fi


# ---------- Pull variables for Digi AnywhereUSB ----------
#
# 1.3.6.1.4.1.332.11.6	Digi AnywhereUSB/14
#
if echo "$vOID" | grep -q -E "1.3.6.1.4.1.332.11.6"
then
  vData=$( GetData '1.3.6.1.4.1.332.11.6.1.4.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_DIGI_DEVICE_INFO_MIB_diBootVersion";
  vData=$( GetData '1.3.6.1.4.1.332.11.6.1.2.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_DIGI_DEVICE_INFO_MIB_diPhysicalAddress";
  vData=$( GetData '1.3.6.1.4.1.332.11.6.1.3.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_DIGI_DEVICE_INFO_MIB_diFirmwareVersion";
  vData=$( GetData '1.3.6.1.4.1.332.11.6.1.1.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_DIGI_DEVICE_INFO_MIB_diProduct";
  vData=$( GetData '1.3.6.1.4.1.332.11.6.1.5.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_DIGI_DEVICE_INFO_MIB_diPostVersion";
fi


# ---------- Pull variables for Eaton Powerware UPS ----------
#
if echo "$vOID" | grep -q -E "1.3.6.1.4.1.(534|705).1"
then
  vData=$( GetData '1.3.6.1.2.1.2.2.1.6.2' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_IF_MIB_ifPhysAddress";
  vData=$( GetData '1.3.6.1.2.1.33.1.1.1.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_UPS_MIB_upsIdentManufacturer";
  vData=$( GetData '1.3.6.1.2.1.33.1.1.2.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_UPS_MIB_upsIdentModel";
  vData=$( GetData '1.3.6.1.2.1.33.1.1.3.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_UPS_MIB_upsIdentUPSSoftwareVersion";
  vData=$( GetData '1.3.6.1.2.1.33.1.1.4.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_UPS_MIB_upsIdentAgentSoftwareVersion";
  vData=$( GetData '1.3.6.1.2.1.33.1.1.5.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_UPS_MIB_upsIdentName";
  vData=$( GetData '1.3.6.1.4.1.534.1.10.8.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_XUPS_MIB_xupsConfigInstallDate";
  vData=$( GetData '1.3.6.1.4.1.534.1.2.6.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_XUPS_MIB_xupsBatteryLastRep";
fi


# ---------- Pull variables for HP UPS ----------
#
if echo "$vOID" | grep -q -E "1.3.6.1.4.1.232.165.3"
then
  vData=$( GetData '1.3.6.1.4.1.232.165.1.2.1.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_CPQPOWER_MIB_deviceManufacturer";
  vData=$( GetData '1.3.6.1.4.1.232.165.1.2.2.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_CPQPOWER_MIB_deviceModel";
  vData=$( GetData '1.3.6.1.4.1.232.165.1.2.6.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_CPQPOWER_MIB_devicePartNumber";
  vData=$( GetData '1.3.6.1.4.1.232.165.1.2.8.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_CPQPOWER_MIB_deviceMACAddress";
  vData=$( GetData '1.3.6.1.4.1.232.165.1.2.7.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_CPQPOWER_MIB_deviceSerialNumber";
  vData=$( GetData '1.3.6.1.4.1.232.165.1.2.3.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_CPQPOWER_MIB_deviceFirmwareVersion";
  vData=$( GetData '1.3.6.1.4.1.232.165.1.2.4.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_CPQPOWER_MIB_deviceHardwareVersion";
  vData=$( GetData '1.3.6.1.4.1.232.165.3.1.1.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_CPQPOWER_MIB_upsIdentManufacturer";
  vData=$( GetData '1.3.6.1.4.1.232.165.3.1.2.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_CPQPOWER_MIB_upsIdentModel";
  vData=$( GetData '1.3.6.1.4.1.232.165.3.1.3.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_CPQPOWER_MIB_upsIdentSoftwareVersions";
  vData=$( GetData '1.3.6.1.4.1.232.165.1.1.4.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_CPQPOWER_MIB_trapDeviceDetails";
fi


# ---------- Pull variables for APC UPS ----------
#
if echo "$vOID" | grep -q -E "1.3.6.1.4.1.318.1.3.(2|2.7|2.13|5.1)"
then
  vData=$( GetData '1.3.6.1.2.1.2.2.1.6.2' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_IF_MIB_ifPhysAddress";
  vData=$( GetData '1.3.6.1.4.1.318.1.1.1.1.1.1.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_PowerNet_MIB_upsBasicIdentModel";
  vData=$( GetData '1.3.6.1.4.1.318.1.1.1.1.1.2.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_PowerNet_MIB_upsBasicIdentName";
  vData=$( GetData '1.3.6.1.4.1.318.1.1.1.1.2.1.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_PowerNet_MIB_upsAdvIdentFirmwareRevision";
  vData=$( GetData '1.3.6.1.4.1.318.1.1.1.1.2.2.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_PowerNet_MIB_upsAdvIdentDateOfManufacture";
  vData=$( GetData '1.3.6.1.4.1.318.1.1.1.1.2.3.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_PowerNet_MIB_upsAdvIdentSerialNumber";
  vData=$( GetData '1.3.6.1.4.1.318.1.1.1.7.2.7.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_PowerNet_MIB_upsAdvTestCalibrationDate";
  vData=$( GetData '1.3.6.1.4.1.318.1.1.1.2.1.3.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_PowerNet_MIB_upsBasicBatteryLastReplaceDate";
  vData=$( GetData '1.3.6.1.4.1.318.1.1.1.2.2.5.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_PowerNet_MIB_upsAdvBatteryNumOfBattPacks";
  vData=$( GetData '1.3.6.1.4.1.318.1.1.1.3.1.1.0' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_PowerNet_MIB_upsBasicInputPhase";
  vData=$( GetData '1.3.6.1.4.1.318.1.4.2.4.1.2.1' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_PowerNet_MIB_expNmcSerialNumber";
  vData=$( GetData '1.3.6.1.4.1.318.1.4.2.4.1.4.1' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_PowerNet_MIB_expNmcAOSVersion";
  vData=$( GetData '1.3.6.1.4.1.318.1.4.2.4.1.4.2' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_PowerNet_MIB_expNmcAppVersion";
  vData=$( GetData '1.3.6.1.4.1.318.1.4.2.4.1.3.1' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_PowerNet_MIB_expNmcAOSFile";
  vData=$( GetData '1.3.6.1.4.1.318.1.4.2.4.1.3.2' ); if [ $? -ne "0" ]; then exit $codeUNKNOWN; fi; SetData "$vData" "snmp_PowerNet_MIB_expNmcAppFile";
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

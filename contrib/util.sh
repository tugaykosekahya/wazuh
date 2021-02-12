#!/bin/sh
# Simple utilities
# Add a new file
# Add a new remote host to be monitored via lynx
# Add a new remote host to be monitored (DNS)
# Add a new command to be monitored
# by Daniel B. Cid - dcid ( at ) ossec.net
# Copyright (C) 2015-2020, Wazuh Inc.

WAZUH_HOME=$1
ACTION=$2
FILE=$3
FORMAT=$4

if [ "X$FILE" = "X" ]; then
    echo "$0: WAZUH_HOME addfile <filename> [<format>]"
    echo "$0: WAZUH_HOME addsite <domain>"
    echo "$0: WAZUH_HOME adddns  <domain>"
    #echo "$0: addcommand <command>"
    echo ""
    #echo "Example: $0 addcommand 'netstat -tan |grep LISTEN| grep -v 127.0.0.1'"
    echo "Example: $0 WAZUH_HOME adddns ossec.net"
    echo "Example: $0 WAZUH_HOME addsite dcid.me"
    exit 1;
fi

eval $(${WAZUH_HOME}/bin/wazuh-control info 2>/dev/null)
if [ "X$WAZUH_TYPE" = "X" ]; then
    echo Wazuh not found. Exiting...
    exit 1
fi

if [ "X$FORMAT" = "X" ]; then
    FORMAT="syslog"
fi

# Adding a new file
if [ $ACTION = "addfile" ]; then
    # Checking if file is already configured
    grep "$FILE" ${WAZUH_HOME}/etc/ossec.conf > /dev/null 2>&1
    if [ $? = 0 ]; then
        echo "$0: File $FILE already configured at ossec."
        exit 1;
    fi

    # Checking if file exist
    ls -la $FILE > /dev/null 2>&1
    if [ ! $? = 0 ]; then
        echo "$0: File $FILE does not exist."
        exit 1;
    fi     
    
    echo "
    <ossec_config>
      <localfile>
      <log_format>$FORMAT</log_format>
      <location>$FILE</location>
     </localfile>
   </ossec_config>  
   " >> ${WAZUH_HOME}/etc/ossec.conf

   echo "$0: File $FILE added.";
   exit 0;            
fi


# Adding a new DNS check
if [ $ACTION = "adddns" ]; then
   COMMAND="host -W 5 -t NS $FILE; host -W 5 -t A $FILE | sort"
   echo $FILE | grep -E '^[a-z0-9A-Z.-]+$' >/dev/null 2>&1
   if [ $? = 1 ]; then
      echo "$0: Invalid domain: $FILE"
      exit 1;
   fi

   grep "host -W 5 -t NS $FILE" ${WAZUH_HOME}/etc/ossec.conf >/dev/null 2>&1
   if [ $? = 0 ]; then
       echo "$0: Already configured for $FILE"
       exit 1;
   fi

   MYERR=0
   echo "
   <ossec_config>
   <localfile>
     <log_format>full_command</log_format>
     <command>$COMMAND</command>
   </localfile>
   </ossec_config>
   " >> ${WAZUH_HOME}/etc/ossec.conf || MYERR=1;

   if [ $MYERR = 1 ]; then
       echo "$0: Unable to modify the configuration file."; 
       exit 1;
   fi

   FIRSTRULE="150010"
   while [ 1 ]; do
       grep "\"$FIRSTRULE\"" ${WAZUH_HOME}/etc/rules/local_rules.xml > /dev/null 2>&1
       if [ $? = 0 ]; then
           FIRSTRULE=`expr $FIRSTRULE + 1`
       else
           break;
       fi
   done


   echo "
   <group name=\"local,dnschanges,\">
   <rule id=\"$FIRSTRULE\" level=\"0\">
     <if_sid>530</if_sid>
     <check_diff />
     <match>^ossec: output: 'host -W 5 -t NS $FILE</match>
     <description>DNS Changed for $FILE</description>
   </rule>
   </group>
   " >> ${WAZUH_HOME}/etc/rules/local_rules.xml || MYERR=1;

   if [ $MYERR = 1 ]; then
       echo "$0: Unable to modify the local rules file.";
       exit 1;
   fi

   echo "Domain $FILE added to be monitored."
   exit 0;
fi


# Adding a new lynx check
if [ $ACTION = "addsite" ]; then
   COMMAND="lynx --connect_timeout 10 --dump $FILE | head -n 10"
   echo $FILE | grep -E '^[a-z0-9A-Z.-]+$' >/dev/null 2>&1
   if [ $? = 1 ]; then
      echo "$0: Invalid domain: $FILE"
      exit 1;
   fi

   grep "lynx --connect_timeout 10 --dump $FILE" ${WAZUH_HOME}/etc/ossec.conf >/dev/null 2>&1
   if [ $? = 0 ]; then
       echo "$0: Already configured for $FILE"
       exit 1;
   fi

   MYERR=0
   echo "
   <ossec_config>
   <localfile>
     <log_format>full_command</log_format>
     <command>$COMMAND</command>
   </localfile>
   </ossec_config>
   " >> ${WAZUH_HOME}/etc/ossec.conf || MYERR=1;

   if [ $MYERR = 1 ]; then
       echo "$0: Unable to modify the configuration file."; 
       exit 1;
   fi

   FIRSTRULE="150010"
   while [ 1 ]; do
       grep "\"$FIRSTRULE\"" ${WAZUH_HOME}/etc/rules/local_rules.xml > /dev/null 2>&1
       if [ $? = 0 ]; then
           FIRSTRULE=`expr $FIRSTRULE + 1`
       else
           break;
       fi
   done


   echo "
   <group name=\"local,sitechange,\">
   <rule id=\"$FIRSTRULE\" level=\"0\">
     <if_sid>530</if_sid>
     <check_diff />
     <match>^ossec: output: 'lynx --connect_timeout 10 --dump $FILE</match>
     <description>DNS Changed for $FILE</description>
   </rule>
   </group>
   " >> ${WAZUH_HOME}/etc/rules/local_rules.xml || MYERR=1;

   if [ $MYERR = 1 ]; then
       echo "$0: Unable to modify the local rules file.";
       exit 1;
   fi

   echo "Domain $FILE added to be monitored."
   exit 0;
fi


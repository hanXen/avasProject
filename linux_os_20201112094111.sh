#!/bin/sh
lang_check=`locale -a 2>/dev/null | grep "en_US" | egrep -i "(utf8|utf-8)"`
if [ "$lang_check" = "" ]; then
	lang_check="C"
fi

LANG="$lang_check"
LC_ALL="$lang_check"
LANGUAGE="$lang_check"
export LANG
export LC_ALL
export LANGUAGE

if [ "`command -v netstat 2>/dev/null`" != "" ] || [ "`which netstat 2>/dev/null`" != "" ]; then
	port_cmd="netstat"
else
	port_cmd="ss"
fi

if [ "`command -v systemctl 2>/dev/null`" != "" ] || [ "`which systemctl 2>/dev/null`" != "" ]; then
	systemctl_cmd="systemctl"
fi

if [ "`command -v readlink 2>/dev/null`" != "" ] || [ "`which readlink 2>/dev/null`" != "" ]; then
	readlink_cmd="readlink"
fi

date_tmp=`date +"%Y%m%d%H%M"`
hostname_tmp=`hostname`
SCRIPT_EXECUTE_PATH=`pwd`
eval RESULT_COLLECT_FILE="$SCRIPT_EXECUTE_PATH/result_collect_$hostname_tmp\_$date_tmp.xml"
eval RESULT_FILE_DATA_FILE="$SCRIPT_EXECUTE_PATH/result_file_data_$hostname_tmp\_$date_tmp.xml"

if [ "`id | grep \"uid=0\"`" = "" ]; then
	echo ""; 
	echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=";
	echo "";
	echo "This script must be run as root.";
	echo "";
	echo "진단 스크립트는 root 권한으로 실행해야 합니다.";
	echo ""; 
	echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=";
	echo ""; 
	exit 1;
fi

ASSETTYPE=LINUX
ASSETSUBTYPE=OS
xml_file_header_tag() {
	result_file=$1
	echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > $result_file 2>&1;
}

xml_tag_write() {
	result_file=$1
	write_tag=$2
	depth_space=$3
	write_space=""
	cnt=0
	depth_space=`expr $depth_space '*' 4`
	
	while [ "$cnt" -lt "$depth_space" ]; do
		write_space=`echo "$write_space "`
		cnt=`expr $cnt + 1`
	done

	echo "$write_space$write_tag" >> $result_file 2>&1
}

xml_infoElement_tag_start() {
	code=$1
	echo "    <infoElement code=\"$code\">" >> $RESULT_COLLECT_FILE 2>&1
}

xml_infoElement_tag_end() {
    code=$1
	echo "    </infoElement>" >> $RESULT_COLLECT_FILE 2>&1
	echo "$code Collect"
}

xml_command_write() {
	name=$1
	data=$2
	echo "        <command name=\"$name\"><![CDATA[" >> $RESULT_COLLECT_FILE 2>&1
	enc_data="`(data_cmd_encoding \"$data\")`"
	echo "$enc_data" >> $RESULT_COLLECT_FILE 2>&1
	echo "        ]]></command>" >> $RESULT_COLLECT_FILE 2>&1
}

xml_fileInfo_write() {
	name=$1

	if [ -d "$name" -o -f "$name" ]; then
		chksum=`echo $name | cksum | sed 's/	/ /g' | cut -d ' ' -f1`
		echo "        <fileName><![CDATA[$name]]></fileName>" >> $RESULT_COLLECT_FILE 2>&1

		if [ -z "`cat $RESULT_FILE_DATA_FILE | grep 'checksum=' | awk -F\"=\" '{ print $2 }' | grep \"$chksum\"`" ]; then
			file_stat=`stat -c '%A|%a|%F|%s|%n|%U|%u|%G|%g' $name`
			file_data=`cat "$name" | sed -e 's/^ *//g' -e 's/^	*//g' | egrep -v '^#|^$'`

			echo "        <fileInfo>" >> $RESULT_FILE_DATA_FILE 2>&1
			echo "            <filePath checksum=\"$chksum\"><![CDATA[$name]]></filePath>" >> $RESULT_FILE_DATA_FILE 2>&1
			if [ "$file_stat" != "" ]; then
				echo "            <fileStat><![CDATA[$file_stat]]></fileStat>" >> $RESULT_FILE_DATA_FILE 2>&1
			fi
            real_name=""
			if [ -h "$name" ]; then
				if [ "$readlink_cmd" != "" ]; then
					real_name=`$readlink_cmd -f "$name"`
					if [ "$real_name" != "" ]; then
						echo "            <fileRealPath><![CDATA[$real_name]]></fileRealPath>" >> $RESULT_FILE_DATA_FILE 2>&1
						file_realstat=`stat -c '%A|%a|%F|%s|%n|%U|%u|%G|%g' $real_name`
						if [ "$file_realstat" != "" ]; then
							echo "            <fileRealStat><![CDATA[$file_realstat]]></fileRealStat>" >> $RESULT_FILE_DATA_FILE 2>&1
						fi
					fi
				fi
			fi
			echo "            <fileData><![CDATA[" >> $RESULT_FILE_DATA_FILE 2>&1
			if [ "$real_name" != "" ]; then
				enc_data="`(data_file_encoding \"$real_name\")`"
			else
				enc_data="`(data_file_encoding \"$name\")`"
			fi
			echo "$enc_data" >> $RESULT_FILE_DATA_FILE 2>&1
			echo "            ]]></fileData>" >> $RESULT_FILE_DATA_FILE 2>&1
			echo "        </fileInfo>" >> $RESULT_FILE_DATA_FILE 2>&1
		fi
	fi
}

xml_sysInfo_contents() {
	result_file=$1
	OS_TYPE=`uname`
	xml_tag_write "$result_file" "<assetInfo>" "1"
	echo "        <assetType>$ASSETTYPE</assetType>" >> $result_file 2>&1
	echo "        <assetSubType>$ASSETSUBTYPE</assetSubType>" >> $result_file 2>&1
	xml_tag_write "$result_file" "</assetInfo>" "1"
	xml_tag_write "$result_file" "<sysInfo>" "1"
	echo "        <osType>$OS_TYPE</osType>" >> $result_file 2>&1
	case $OS_TYPE in
		Linux)
			OS_KERNEL_VERSION=`uname -r | sed 's/-.*//'`
			if [ -f "/etc/debian_version" -a -f "/etc/lsb-release" ]; then
				OS_VERSION=`cat /etc/debian_version`
				os_chk=`cat /etc/lsb-release | grep "^DISTRIB_ID=" | cut -d '=' -f2 | sed 's/"//g'`
				if [ "$os_chk" = "Ubuntu" ]; then
					OS_VERSION=`cat /etc/lsb-release | grep "^DISTRIB_RELEASE=" | cut -d '=' -f2`
					OS_NAME="Ubuntu"
				fi
			fi

			if [ -f "/etc/redhat-release" ]; then
				OS_NAME_CHK=`cat /etc/redhat-release | grep "CentOS"`
				if [ "$OS_NAME_CHK" != "" ]; then
					OS_NAME="CentOS"
					OS_VERSION=`echo "$OS_NAME_CHK" | sed 's/CentOS //g'`
				fi
			fi
			;;
	esac
	if [ "`command -v base64 2>/dev/null`" != "" ] || [ "`which base64 2>/dev/null`" != "" ]; then
		ENCTYPE="base64"
	fi

    hostname=`hostname`

	echo "        <osName>$OS_NAME</osName>" >> $result_file 2>&1
	echo "        <osVersion>$OS_VERSION</osVersion>" >> $result_file 2>&1
	echo "        <osKernelVersion>$OS_KERNEL_VERSION</osKernelVersion>" >> $result_file 2>&1
	echo "        <hostname>$hostname</hostname>" >> $result_file 2>&1
	echo "        <encType>$ENCTYPE</encType>" >> $result_file 2>&1

    inter_name=`ls /sys/class/net | grep -v 'lo'`
    ip_list=""
    for name in $inter_name; do
        if [ "`command -v ifconfig 2>/dev/null`" != "" ] || [ "`which ifconfig 2>/dev/null`" != "" ]; then
            tmp=`ifconfig $name`
        elif [ "`command -v ip 2>/dev/null`" != "" ] || [ "`which ip 2>/dev/null`" != "" ]; then
            tmp=`ip a show $name`
        fi
        if [ "$ip_list" = "" ]; then
            ip_list=`echo "$tmp"`
        else
            ip_list=`echo -e "$ip_list\n"; echo "$tmp"`
        fi
    done

	process_info=`ps -ef | sed -e 's/^ *//g' -e 's/^	*//g'`
	port_info=`$port_cmd -na | egrep -i 'tcp|udp' | grep -iv 'TIME_WAIT' | sed -e 's/^ *//g' -e 's/^	*//g'`
	if [ "$OS_TYPE" = "Linux" ]; then
	    service_info=`$systemctl_cmd list-units --type service | sed -e 's/^ *//g' -e 's/^	*//g'`
	fi
    if [ "$ip_list" != "" ]; then
        echo "        <ipList><![CDATA[" >> $result_file 2>&1
        enc_ip_list="`(data_cmd_encoding \"$ip_list\")`" >> $result_file 2>&1
        echo "$enc_ip_list" >> $result_file 2>&1
        echo "        ]]></ipList>" >> $result_file 2>&1
    fi
	if [ "$process_info" != "" ]; then
		echo "        <processInfo><![CDATA[" >> $result_file 2>&1
		enc_process_info="`(data_cmd_encoding \"$process_info\")`"
		echo "$enc_process_info" >> $result_file 2>&1
		echo "        ]]></processInfo>" >> $result_file 2>&1
	fi
	if [ "$port_info" != "" ]; then
		echo "        <portInfo><![CDATA[" >> $result_file 2>&1
		enc_port_info="`(data_cmd_encoding \"$port_info\")`"
		echo "$enc_port_info" >> $result_file 2>&1
		echo "        ]]></portInfo>" >> $result_file 2>&1
	fi
	if [ "$service_info" != "" ]; then
		echo "        <serviceInfo><![CDATA[" >> $result_file 2>&1
		enc_service_info="`(data_cmd_encoding \"$service_info\")`"
		echo "$enc_service_info" >> $result_file 2>&1
		echo "        ]]></serviceInfo>" >> $result_file 2>&1
	fi
	xml_tag_write "$result_file" "</sysInfo>" "1"
}

data_cmd_encoding() {
	data="$1"
	if [ "`command -v base64 2>/dev/null`" != "" ] || [ "`which base64 2>/dev/null`" != "" ]; then
		echo "$data" | sed -e 's/^ *//g' -e 's/^	*//g' | base64 -w 76
	fi
}

data_file_encoding() {
	file_name=$1
	if [ "`command -v base64 2>/dev/null`" != "" ] || [ "`which base64 2>/dev/null`" != "" ]; then
		if [ "`echo $file_name | egrep 'issue\.net|motd'`"  != "" ]; then
			cat $file_name | sed -e 's/^ *//g' -e 's/^	*//g' | base64 -w 76
		else
			cat $file_name | sed -e 's/^ *//g' -e 's/^   *//g' | egrep -v '^$|^#' | base64 -w 76
		fi
	fi
}


linux001() {
    code=$1
    xml_infoElement_tag_start "$code"
    
    xml_fileInfo_write "/etc/ssh.sshd_config"
    xml_fileInfo_write "/etc/pam.d/remote"
    xml_fileInfo_write "/etc/pam.d/login"
    xml_fileInfo_write "/etc/securetty"
    
    xml_infoElement_tag_end "$code"
}        


linux003() {
    code=$1
    xml_infoElement_tag_start "$code"
    
    xml_fileInfo_write "/etc/pam.d/system-auth"
    xml_fileInfo_write "/etc/pam.d/password-auth"
    xml_fileInfo_write "/etc/pam.d/common-auth"
    xml_fileInfo_write "/etc/pam.d/common-account"
    
    xml_infoElement_tag_end "$code"
}        


linux007() {
    code=$1
    xml_infoElement_tag_start "$code"
    
    xml_fileInfo_write "/etc/passwd"
    
    xml_infoElement_tag_end "$code"
}        


linux008() {
    code=$1
    xml_infoElement_tag_start "$code"
    
    xml_fileInfo_write "/etc/shadow"
    
    xml_infoElement_tag_end "$code"
}        


linux031() {
    code=$1
    xml_infoElement_tag_start "$code"
    
    xml_fileInfo_write "/etc/sendmail.cf"
    xml_fileInfo_write "/etc/mail/sendmail.cf"
    
    xml_infoElement_tag_end "$code"
}        


linux032() {
    code=$1
    xml_infoElement_tag_start "$code"
    
    xml_fileInfo_write "/etc/sendmail.cf"
    xml_fileInfo_write "/etc/mail/sendmail.cf"
    
    xml_infoElement_tag_end "$code"
}        


linux042() {
    code=$1
    xml_infoElement_tag_start "$code"
    
    if [ "$OS_VERSION" != "" ] && [ "OS_KERNEL_VERSION" != "" ]; then
        xml_command_write "$OS_VERSION" "$OS_NAME $OS_VERSION"
        xml_command_write "$OS_KERNEL_VERSION" "$OS_KERNEL_VERSION"
    fi
    
    xml_infoElement_tag_end "$code"
}        


linux043() {
    code=$1
    xml_infoElement_tag_start "$code"
    
    xml_infoElement_tag_end "$code"
}        

xml_file_header_tag "$RESULT_COLLECT_FILE"

xml_tag_write "$RESULT_COLLECT_FILE" "<root>" "0"

xml_sysInfo_contents "$RESULT_COLLECT_FILE"

xml_tag_write "$RESULT_FILE_DATA_FILE" "<fileList>" "1"


linux001 U-01
linux003 U-03
linux007 U-07
linux008 U-08
linux031 U-31
linux032 U-32
linux042 U-42
linux043 U-43
xml_tag_write "$RESULT_FILE_DATA_FILE" "</fileList>" "1"

if [ -f "$RESULT_COLLECT_FILE" ]; then
	if [ -f "$RESULT_FILE_DATA_FILE" ]; then
		cat "$RESULT_FILE_DATA_FILE" >> $RESULT_COLLECT_FILE
		rm -f "$RESULT_FILE_DATA_FILE"
	fi
	xml_tag_write "$RESULT_COLLECT_FILE" "</root>" "0"
else
	echo "[Error] Not Found Result Files"
fi


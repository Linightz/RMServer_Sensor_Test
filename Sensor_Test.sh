#!/bin/bash
# Written by Kevin SJ Huang 2019/1/16

# This script intends to run all kinds of BMC sensor assertion/deassertion tests with given sensor name and the event reading mask.
# This script is NOT designed for sensor test that will need to reboot the system or with other triggering machanism.
# This script is designed to run on RHEL7.

BMC_IP=$3
BMC_USER=$4
BMC_PWD=$5
OS_IP=$6
OS_USER=$7
OS_PWD=$8

Initialization()
{
	sensorname="$1"
	mask="$2"
	case "$mask" in
		00h)
			MSB="0x0"
			LSB="0x1"
			;;
		01h)
			MSB="0x0"
			LSB="0x2"
			;;
		02h)
			MSB="0x0"
			LSB="0x4"
			;;
		03h)
			MSB="0x0"
			LSB="0x8"
			;;
		04h)
			MSB="0x0"
			LSB="0x10"
			;;
		05h)
			MSB="0x0"
			LSB="0x20"
			;;
		06h)
			MSB="0x0"
			LSB="0x40"
			;;
		07h)
			MSB="0x0"
			LSB="0x80"
			;;
		08h)
			MSB="0x1"
			LSB="0x0"
			;;
		09h)
			MSB="0x2"
			LSB="0x0"
			;;
		0ah)
			MSB="0x4"
			LSB="0x0"
			;;
		*)
			echo 'Please enter a valid reading mask. Ex. 0ah' |tee -a "${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt
			exit 1
			;;
	esac
	echo "The sensor name and the event reading mask you entered are"
	echo "$sensorname $2"
	echo "And the corresponding event offset value MSB and LSB are"
	echo "$MSB $LSB"
	echo 'Please check carefully for any incorrectness. *sensor name has to be exact match'
	echo "Press Ctrl + C to stop"
	sleep 10s
			
}

create_log()
{
	datenow="$(date +%Y%m%d%H%M%S)"
	touch "${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt
}

verify()
{
	if [ $1 -ne 0 ]; then
		echo "Something went wrong!" |tee -a "${0%.*}"_"${sensorname}"_"${mask}"_log_"$datenow".txt
		exit 1
	fi
}

iboob()
{
	# Need to declare something like the following prior to use
	# BMC_IP=$1
	# BMC_USER=$2
	# BMC_PWD=$3
	if [ -z "$BMC_IP" ] ; then
		echo "This is In-Band mode" |tee -a "${0%.*}"_"${sensorname}"_"${mask}"_log_"$datenow".txt
		echo "To use OOB mode, run $0 <Sensor_Name> <Event_Reading_Mask> <BMC_IP> <BMC_Username> <BMC_Password>"
		echo "To stop, press Ctrl + C"
		sleep 3s
		string=""
	else 
		if [[ -z "$BMC_USER" || -z "$BMC_PWD" ]]; then
			echo "Missing IMM login info" |tee -a "${0%.*}"_"${sensorname}"_"${mask}"_log_"$datenow".txt
			exit 1
		fi
		string=" -I lanplus -H $BMC_IP -U $BMC_USER -P $BMC_PWD"
		echo "OOB mode  BMC IP: $BMC_IP" |tee -a "${0%.*}"_"${sensorname}"_"${mask}"_log_"$datenow".txt
		echo "Checking if $BMC_IP is accessible..."
		ping $BMC_IP -c 3 > /dev/null
		if [ $? -ne 0 ]; then
			echo "$BMC_IP is inaccessible, please check the connection" |tee -a "${0%.*}"_"${sensorname}"_"${mask}"_log_"$datenow".txt
			exit 1
		else
			echo "OK" |tee -a "${0%.*}"_"${sensorname}"_"${mask}"_log_"$datenow".txt
		fi
	fi
}

ipmitool_check()
{
	rpm -q ipmitool > /dev/null
	if [ $? -ne 0 ]; then
		echo "Seems that ipmitool is not installed on the system, exiting" |tee -a "${0%.*}"_"${sensorname}"_"${mask}"_log_"$datenow".txt
		exit 1
	fi
}

start_sensor_test()
{
	echo "Starting OEM sensor test command..." |tee -a "${0%.*}"_"${sensorname}"_"${mask}"_log_"$datenow".txt

	ipmitool${string} raw 0x3a 0x17 0x0
	sensorstate=`ipmitool${string} raw 0x3a 0x17 0x4`
	if [[ $sensorstate -eq 01 ]]; then
		echo "OEM sensor test command started" |tee -a "${0%.*}"_"${sensorname}"_"${mask}"_log_"$datenow".txt
	else
		echo "Failed starting OEM sensor test command, exiting" |tee -a "${0%.*}"_"${sensorname}"_"${mask}"_log_"$datenow".txt
		exit 1
	fi
}

echo "###Script usage: $0 <Sensor_Name> <Event_Reading_Mask>"
echo '###If sensor name contains spaces, use double quotes or it will be errors.'
echo '###This script is NOT designed for sensor test that will reboot the system.'
sleep 3s

create_log "$1" "$2"
Initialization "$1" "$2"

iboob
ipmitool_check

echo "Getting Sensor ID..." |tee -a $"${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt
ipmitool${string} sdr get "$sensorname" >> "${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt 2>&1
sensorid=`ipmitool${string} sdr get "$sensorname" |grep "Sensor ID" |cut -d "(" -f2 |cut -d ")" -f1`
if [ -z $sensorid ]; then
	echo "Please check the BMC SPEC"
	exit 1
fi
[[ ${#sensorid} -eq 3 ]] && sensorid="${sensorid:0:2}0${sensorid:2}"
echo "The \"$sensorname\" sensor ID on this platform is $sensorid" |tee -a "${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt
sleep 3s

start_sensor_test

echo "Clearing BMC SEL..." |tee -a "${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt
ipmitool${string} sel clear 2>&1 |tee -a "${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt
sleep 5s

echo "Begin sensor test..." |tee -a "${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt
ipmitool${string} raw 0x3a 0x17 0x5 "$sensorid"
verify $?
ipmitool${string} raw 0x3a 0x17 0x1 "$sensorid" "$MSB" "$LSB" 0x0 0x0 >> "${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt 2>&1

echo "Error flag set successfully, wait for 45s" |tee -a "${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt
sleep 45s

echo "Checking SEL now..." |tee -a "${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt
ipmitool${string} sel list >> "${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt 2>&1
sel_log=`ipmitool${string} sel list |grep -E "${sensorid}.*Asserted"`
if [ $? -eq 0 ]; then
	echo "The SEL log for this test is" |tee -a "${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt
	echo "$sel_log" |tee -a "${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt
	echo "Assertion Test Passed!" |tee -a "${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt
else
	echo "No assertion log found" |tee -a "${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt
	echo "Assertion Test Failed!" |tee -a "${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt
	exit 1
fi

echo "Ending OEM sensor test command..." |tee -a "${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt
ipmitool${string} raw 0x3a 0x17 0x2 2>&1 |tee -a "${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt
sleep 10s
sel_log=`ipmitool${string} sel list |grep -E "${sensorid}.*Deasserted"`
if [ $? -eq 0 ]; then
	echo "The SEL log for this test is" |tee -a "${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt
	echo "$sel_log" |tee -a "${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt
	echo "Deassertion Test Passed!" |tee -a "${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt
else
	echo "No deassertion log found" |tee -a "${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt
	echo "Deassertion Test Failed!" |tee -a "${0%.*}"_"${1}"_"${2}"_log_"$datenow".txt
	exit 1
fi

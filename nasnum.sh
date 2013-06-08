#!/bin/bash
#nasnum.sh
#Author: Russell Butturini
#tcstool@gmail.com
#Enumerate cool network attached storage good time fun!
#Copyright 2013 Russell Butturini
#This program is distributed under the terms of the GNU General Public License.
#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

#Usage: nasnum.sh <ip of storage> <output file path> <options>
#Options:
#-s Try SMB Stuff
#-n Try NFS Stuff
#-b Try to guess SNMP and enumerate
#-f Try anonymous FTP
#-q Don't mount the shares
#-c Clean up when done
#Requires showmount, snmpwalk, ncftp, and smbclient

OLD_IFS=$IFS
IFS=$'\n'

clear
#Clean up from previous runs
rm *.txt > /dev/null 2>&1

if [ $# -lt 3 ]; then
	echo -e  "\n\n-----------------Nasnum-The Network Attached Storage Enumerator------------------------\n\n"
    echo "Usage: nasnum.sh <ip or DNS name of storage> <HTML output file path> <options>"
    echo "Options:"
    echo "-s Grab SMB info"
    echo "-n Grab NFS info"
    echo "-b Check SNMP for connection data (Tested on EMC and Buffalo storage; Your mileage will vary)"
    echo "-f Check for anonymous FTP and enumerate dirs/files"
    echo "-q Be quiet and don't mount shares"
    echo -e "-c Clean up when finished\n\n\n"
    exit
fi

storage=$1
output=$2
option_ary=($3 $4 $5 $6 $7 $8)
snmp_ary=("public" "private" "readme" "snmp")
quiet_mode=0
nfs_data_done=0
smb_data_done=0
ftp_data_done=0
snmp_data_done=0
clean_up=0
date=$(date)

#Initialize the output
printf "<!doctype html>\n" > ${output}
printf "<html>\n" >> ${output}
printf "	<head>\n" >> ${output}
printf "	<meta charset=\"utf-8\">\n" >> ${output}
printf " 	<title>NASNum report-${storage}</title>\n" >> ${output}
printf "	</head>\n" >> ${output}
printf " <body style=\"font-family:verdana;\">\n" >> ${output}
printf " 	<h1> Nasnum Storage Audit Report for ${storage}</h1>\n" >> ${output}
printf "		<h4> Audit started ${date}</h4>\n" >> ${output}
printf "		<ul>\n" >> ${output}
#printf "</html>" >> ${output}

#Figure out what work we need to do and grab the data

for i in "${option_ary[@]}"
do
	if [ "$i" == "-s" ]; then
		echo "Trying to grab the SMB Data..."
		echo "Enter your local system password when prompted."
		smbclient -L ${storage} | sed '/Sharename/d' | sed '/-/d' | sed -e '/Server /,+10d' > smb_exports.txt
		printf "		<li><a href=${output}#smbexp>Share List-SMB</a></li>\n" >>${output}
		smb_data_done=1
	fi
	
	if [ "$i" == "-n" ]; then
		echo "Trying to grab the NFS Data.."
		showmount -a ${storage} | sed "1 d" > nfs_session.txt
		showmount -e ${storage} | sed "1 d" > nfs_exports.txt
		printf "		<li><a href=${output}#nfsexp>Share List-NFS</a></li>\n" >>${output}
		printf "		<li><a href=${output}#nfshosts>Enumerated hosts-NFS</a></li>\n" >>${output}
		nfs_data_done=1
	fi
	
	if [ "$i" == "-b" ]; then
		echo "Trying to grab the SNMP data..."
		printf "		<li><a href=${output}#snmphostsmb>Enumerated hosts with SMB connections-SNMP</a></li>\n" >>${output}
		printf "		<li><a href=${output}#snmphostnfs>Enumerated hosts with NFS connections-SNMP</a></li>\n" >>${output}
		
		for snmp_string in "${snmp_ary[@]}"
		do
			snmpwalk -v 1 -c $snmp_string ${storage} >> snmp_data.txt
		done	
		snmp_data_done=1
	fi
	
	if [ "$i" == "-f" ]; then
		echo "Trying to grab the FTP data..."
		ncftpls -r1 -t5 -R ftp://${storage} > ftp_exports.txt	
		ftp_data_done=1
	fi
	
	
	if [ $i == "-q" ]; then
		quiet_mode=1
		
	fi

	if [ $i == "-c" ]; then
		clean_up=1
	fi
	
done

#If quiet mode is not enabled, then create some dirs to mount up our shares and add the links to the table of contents.

if [ ${quiet_mode} != 1 ]; then
	
	if [ $nfs_data_done == 1 ]; then
		if [ ! -d ./nfstemp ]; then
			mkdir ./nfstemp
		fi
	fi
	
	if [ ${smb_data_done} == 1 ]; then
		if [ ! -d ./smbtemp ]; then
			mkdir ./smbtemp
		fi
	fi
fi

#Finish building the table of contents
if [ ${nfs_data_done} == 1 ] && [ ${quiet_mode} != 1 ]; then
	printf "		<li><a href=${output}#nfsdirs>Anonymous Directory Listings-NFS</a></li>\n" >> ${output}	
fi

if [ ${smb_data_done} == 1 ] && [ ${quiet_mode} != 1 ]; then
	printf "		<li><a href=${output}#smbdirs>Anonymous Directory Listings-SMB</a></li>\n" >> ${output}
fi

if [ ${ftp_data_done} == 1 ]; then
	printf "		<li><a href=${output}#ftpdirs>Anonymous Directory Listings-FTP</a></li>\n" >> ${output}
fi

printf "		</ul><br>\n" >> ${output}

#Dump the SMB share list into the report
if [ ${smb_data_done} == 1 ]; then	
	printf "		<a name=\"smbexp\"></a><strong>Share List-SMB:</strong>\n" >> ${output}
	printf "		<p>" >> ${output}
	
	for line in $( (cat "./smb_exports.txt") )
	do
		printf "	${line}<br>\n" >> ${output}
	done
	printf "		</p><br>\n" >> ${output}
	
	
	cat smb_exports.txt | cut -d " " -f 1 | cut -f2 -s > smbnames.txt
	
	
	if [ ${quiet_mode} != 1 ]; then
		printf "		<p><a name=\"smbdirs\"></a><strong>SMB export directory listings:</strong><br>\n" >> ${output}
		echo "Mounting SMB shares.  You will need to enter the local system password for every attempted mount (Yes it's annoying)."
	
	
		for line in $( (cat "./smbnames.txt") )
		do
			mount -t cifs  //${storage}/${line} ./smbtemp
			
			it_worked=$?
			
			if [ ${it_worked} == 0 ]; then
				printf "		${line}<br>\n" >> ${output}
				ls -al ./smbtemp >> smbdirlist.txt
		
				for line in $( (cat "./smbdirlist.txt") )
				do
					printf "		${line}<br>\n" >> ${output}	
				done
				rm ./smbdirlist.txt
				umount ./smbtemp
			fi
		printf "		</p><br>\n" >> ${output}	
		sleep 2
		done
	fi
	
fi
	
#Dump the NFS export list into the report	
if [ ${nfs_data_done} == 1 ]; then	
	printf "		<a name=\"nfsexp\"></a><strong>Share List-NFS:</strong>\n" >> ${output}
	printf "		<p>" >> ${output}
	
	for line in $( (cat "./nfs_exports.txt") )
	do
		printf "	${line}<br>\n" >> ${output}
	done
	printf "		</p><br>\n" >> ${output}
	
	cat nfs_exports.txt |grep 'everyone\|[*]'| cut -d " " -f 1 > nfsnames.txt
	
	if [ ${quiet_mode} != 1 ]; then
		printf "		<p><a name=\"nfsdirs\"></a><strong>NFS export directory listings:</strong><br>\n" >> ${output}
	
	
		for line in $( (cat "./nfsnames.txt") )
		do
			printf "		${line}<br>\n" >> ${output}
			mount -t nfs -o nolock ${storage}:${line} ./nfstemp
			ls -al ./nfstemp >> nfsdirlist.txt
		
			for line in $( (cat "./nfsdirlist.txt") )
			do
				printf "		${line}<br>\n" >> ${output}	
			done
		
		printf "		</p><br>\n" >> ${output}
		sleep 5
		umount ./nfstemp
		rm ./nfsdirlist.txt
		done
	fi
	
	printf "		<br>\n" >> ${output}
	printf "		<p><a name=\"nfshosts\"></a><strong>Enumerated Hosts-NFS:</strong><br>\n" >> ${output}
	
	cat nfs_session.txt | cut -d ":" -f 1 | uniq > nfshosts.txt
	
	for line in $( (cat "./nfshosts.txt") )
	do
		printf "		${line}<br>\n" >> ${output}
	done
	printf "		<br>\n" >> ${output}
fi

#Dump the FTP data into the report

if [ ${ftp_data_done} == 1 ]; then
	printf "		<p><a name=\"ftpdirs\"></a><strong>Anonymous FTP Directory Listings:</strong><br>\n" >> ${output}
	
	for line in $( (cat "./ftp_exports.txt") ) 
	do
		printf "		${line}<br>\n">> ${output}
	done
	printf "		</p><br>\n"  >> ${output}
fi

#Dump the SNMP data into the report
if [ ${snmp_data_done} == 1 ]; then
	printf "		<p><a name=\"snmphostsmb\"></a><strong>Enumerated Hosts with SMB Connection-SNMP:</strong><br><br>\n" >> ${output}
	cat snmp_data.txt | grep tcpConnState | cut -d "=" -f 1 | grep 445 | cut -d "." -f 7-10 | uniq > snmp_smb.txt
	
	for line in $( (cat "./snmp_smb.txt") )
	do
		printf "		${line}<br>">> ${output}
	done
	
	printf "		</p><br><br>\n" >> ${output}
	
	cat snmp_data.txt | grep tcpConnState | cut -d "=" -f 1 | grep 2049 | cut -d "." -f 7-10 | uniq > snmp_nfs.txt
	printf "		<p><a name=\"snmphostnfs\"></a><strong>Enumerated Hosts with NFS Connection-SNMP:</strong><br><br>\n" >> ${output}
	
	for line in $( (cat "./snmp_nfs.txt") )
	do
		printf "		${line}<br>">> ${output}
	done
	
	printf "		</p><br><br>\n" >> ${output}	
fi

if [ ${clean_up} == 1 ]; then
	rm *.txt > /dev/null 2>&1
fi

printf "	</body>\n" >> ${output}
printf "</html>" >> ${output}
IFS=OLD_IFS
echo "Done"
#The end
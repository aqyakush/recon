#!/bin/bash

#Tools need to run this script: nmap, ffuf, ping, xmlstarlet

print_start_of_command() {
	echo "----------------------------------"
	echo "$1 started"
}

finished() {
	echo "finished"
}

#ping the host to check if it is active
is_host_active() {
	if ping -c 1 $1 &> /dev/null
	then
	 echo "Host Found - `date`"
	else
	 echo "Ping Fail - `date`"
	 exit 1
	fi
}

combine_htmls() {
	mv $1/result.html $1/result1.html
  	cat $1/result1.html $1/$2 > $1/result.html
  	rm $1/$2
  	rm $1/result1.html
}

projectName=$1

if [ -z "$2" ] 
then
      echo "Target name is no provided"
      echo "IP will be used as name"
else
      projectName=$2
fi

mkdir $projectName

is_host_active $1

# start fast nmap scan to see what ports are open
print_start_of_command "Fast nmap"
nmap -T4 -p- $1 -oX $projectName/nmapFast.xml > /dev/null
xmlstarlet sel -t -v "/nmaprun/host/ports/port/@portid" $projectName/nmapFast.xml > $projectName/ports.txt
portString=$(cat $projectName/ports.txt | paste -d, -s )
echo "Open ports: $portString"
finished

# base on the outcome of previouse command, run detailed scan with nmap
print_start_of_command "Detailed nmap"
nmap -T4 -sV -A -p $portString $1 -oX $projectName/nmapResult.xml > /dev/null
xsltproc $projectName/nmapResult.xml -o $projectName/nmap.html
mv $projectName/nmap.html $projectName/result.html
finished

#if the port 80 is active, scan url to find hiden directories
if  grep -q "80" $projectName/ports.txt; then
       	print_start_of_command "FFuF"
  	ffuf -w /usr/share/wordlists/dirb/common.txt -u http://$1/FUZZ -e ".php,.html,.txt,.bak" -s -recursion -recursion-depth 2 -fc 403 -o $projectName/ffufResults.html -of html
  	combine_htmls $projectName ffufResults.html
  	finished
fi


echo "----------------------------------"
pwd=$(pwd)
echo "Script is finished! The result can be found in $pwd/$projectName/result.html"

#removing not needed files
rm $projectName/nmapFast.xml
rm $projectName/nmapResult.xml
rm $projectName/ports.txt


#firefox $pwd/$projectName/result.html


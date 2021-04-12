#!/bin/bash

#Tools need to run this script: nmap, ffuf, ping, xmlstarlet, xsltproc

print_start_of_command() {
	echo "----------------------------------"
	echo "$1 started"
}

finished() {
	echo "finished"
}

#ping the host to check if it is up
is_host_up() {
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

is_host_up $1

# start fast nmap scan to find open ports
print_start_of_command "Fast nmap"
nmap -T4 -p- $1 -oX $projectName/nmapFast.xml > /dev/null
xmlstarlet sel -t -v "/nmaprun/host/ports/port/@portid" $projectName/nmapFast.xml > $projectName/ports.txt
portString=$(cat $projectName/ports.txt | paste -d, -s )
finished

# base on the outcome of previouse scan, run detailed scan with nmap
print_start_of_command "Detailed nmap"
nmap -T4 -sV -A -p $portString $1 -oX $projectName/nmapResult.xml > /dev/null
xsltproc $projectName/nmapResult.xml -o $projectName/nmap.html
mv $projectName/nmap.html $projectName/result.html
finished

xmlstarlet sel -t -v "/nmaprun/host/ports/port/service/@name" $projectName/nmapResult.xml > $projectName/services.txt
paste $projectName/ports.txt $projectName/services.txt | column -s $'\t' -t > $projectName/fullPorts.txt

# fetch all http ports and perform ffuf on each of them
awk '$2=="http" {print $1}' $projectName/fullPorts.txt > $projectName/httpPorts.txt

while IFS= read -r line; do
	print_start_of_command "FFuF port:$line"
	if [ $line = "80" ]; then
		ffuf -w /usr/share/wordlists/dirb/common.txt -u http://$1/FUZZ -e ".php,.html,.txt,.bak" -s -recursion -recursion-depth 2 -fc 403 -o $projectName/ffufResults$line.html -of html
	else
		ffuf -w /usr/share/wordlists/dirb/common.txt -u http://$1:$line/FUZZ -e ".php,.html,.txt,.bak" -s -recursion -recursion-depth 2 -fc 403 -o $projectName/ffufResults$line.html -of html
	fi
	combine_htmls $projectName ffufResults$line.html
  	finished
done < $projectName/httpPorts.txt

echo "----------------------------------"
pwd=$(pwd)
echo "Script is finished! The result can be found in $pwd/$projectName/result.html"

#removing not needed files
rm $projectName/nmapFast.xml
rm $projectName/nmapResult.xml
rm $projectName/ports.txt
rm $projectName/services.txt
rm $projectName/fullPorts.txt
rm $projectName/httpPorts.txt

firefox $pwd/$projectName/result.html


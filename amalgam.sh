#!/bin/bash

# culmination of my current bug bounty automation capacity.

if [ $# -eq 0 ]
	then
		echo "enter domain to scan:"
		read domain
	else domain="$1"
fi

echo "charging the lazer..."

#sets up directories for output/preference
resDir="amalgam_${domain}"
mkdir $resDir $resDir/enum $resDir/targets $resDir/scans $resDir/scans/gowitness
echo "output dirs created..."

expressvpn disconnect
sleep 10

#gather subdomains
/home/pentup/go/bin/amass enum -active -d $domain -oA $resDir/enum/amass_enum
echo $domain >> $resDir/enum/amass_enum.txt
echo "amass done!"

/home/pentup/go/bin/subfinder -dL $resDir/enum/amass_enum.txt -o $resDir/enum/subfinder_enum

expressvpn connect usla
sleep 10

#concatenate and clean subdomains
cat $resDir/enum/subfinder_enum | sort -u >> $resDir/enum/sorted_subs.txt

#nmap for common web/admin ports
nmap -iL $resDir/enum/sorted_subs.txt --open -sV -p 80,443,8443,8005,8009,8080,8181,4848,9000,8008,9990,7001,9043,9060,9080,9443,7777,4443,2082,2083,8880,9001,4643 -oX $resDir/enum/gowitness_nmap.xml

#screenshot pages & output report (modify --prefix flag for http)
echo "gowitness starting..."
/home/pentup/go/bin/gowitness nmap --nmap-file $resDir/enum/gowitness_nmap.xml -D $resDir/scans/gowitness/gowitness.db -d $resDir/scans/gowitness/ --scan-hostnames -t 10
/home/pentup/go/bin/gowitness report generate -D $resDir/scans/gowitness/gowitness.db -d $resDir/scans/gowitness/ -n $resDir/scans/gowitness/Report.html -c 500 -S
#dirty format to render pics in report
sed -i "s|$resDir/scans/gowitness|.|g" $resDir/scans/gowitness/*.html

sudo chmod -R a+rw $resDir/

#trick from @xchopath (needs tuning)
echo "getting endpoints from: ${domain}"
wget "http://web.archive.org/cdx/search/cdx?url=.${domain}&output=text&fl=original&collapse=urlkey" -q -O $resDir/scans/${domain}_raw
cat $resDir/scans/${line}_raw | grep "?" >> $resDir/scans/${domain}_wayback_endpoints
echo "endpoints gathered!"

#gau endpoint finding (praise be to tomnomnom) ssrf needs major overhaul
echo "continuing using gau tricks..."
cat $resDir/enum/sorted_subs.txt | while read line; do
	
	/home/pentup/go/bin/gau ${line} >> $resDir/scans/${line}_Gau
	cat $resDir/scans/${line}_Gau | ~/go/bin/unfurl keys | sort -u >> $resDir/scans/${line}_params


done

#dirty aws open bucket check
echo "running esthree..."
cat $resDir/enum/sorted_subs.txt | while read line; do
	echo "testing $line"
	echo "testing $line" >> $resDir/scans/esthree_results.txt
	aws s3 ls s3://${line} >> $resDir/scans/esthree_results.txt
done

#clean empty files because holy shit this can make a bunch of stuff to look at
echo "cleaning..."
find $resDir/scans/ -size 0 -print -delete
echo "cleaned!"

#iloveyou!
echo "Good luck!"

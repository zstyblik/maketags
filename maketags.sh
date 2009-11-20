#!/bin/sh
# 09/Oct/17 @ Zdenek Styblik
# 
# "Yo Adrian, I did it!"
#
# Licence:
# Everything is about licence these days. Well, since there are some 
# parts and ideas from other scripts, and these scripts have GPLv2 
# or better, GPLv2+ it is.
# As usual, I don't care, but original authors resp. authors of 
# chunks of the code might- You get the point.
#
# Ideas: 
# - there could be menu A-Y like during an installation
#
# Where can we find mounted Slackware CD/DVD/etc.
SLACKDIR='/mnt/cdrom/'
# Read package description from TXT files
# WARNING: it doesn't work, it's unsupported, don't use !!!
PKGDESC=1

### Before menu was brought in ###
#echo "Slackware tag file generator"
#echo "Don't forget to set SLACKDIR path"
#echo "This script requires root priviledges though, \
#as it writes to /var/log"
#echo ""
#echo "Provide path to Slackware directory eg. mounted CD/DVD-ROM"
#echo "[Enter] - use default (${SLACKDIR})"
#echo "[CTRL+C] - exit"
#echo -n "Provide path to Slackware directory: "
#read UINPUT
#if [ ! -z ./SLACKDIR ]; then
#	SLACKDIR=$UINPUT
#fi;
#################################

rm -f ./SLACKDIR 2>/dev/null
rm -f ./pkgListTmp 2>/dev/null

# new version with dialog
dialog --title "Slackware directory" --inputbox "Please, enter path \
to Slackware directory \
eg. mounted CD/DVD-ROM, or use default (${SLACKDIR})" 8 70 2>SLACKDIR
if [ -s './SLACKDIR' ]; then
	SLACKDIR=`cat ./SLACKDIR`
	rm -f ./SLACKDIR
fi;

LSOUT=`ls /${SLACKDIR}/ 2>/dev/null | egrep '^slackware(64)?$'`
if [ $? -ne 0 ]; then 
	echo "There seems to be no slackware directory in ${SLACKDIR}"
	echo "Make sure Slackware is there, or check the permissions"
	exit 1
fi;

# there might be more than one dir, but it's unlikely.
PKGDIR=`echo ${LSOUT} | cut -d ' ' -f 1`

REUSETAGS=0
if [ -e ./${PKGDIR} ]; then
	dialog --title "Old tag files" --yesno "It looks I've found the \
last set of tag files you've generated. Should I re-use them, if \
possible, or start over (= delete)?" 10 72
	if [ $? == 0 ]; then
		REUSETAGS=1
		rm -Rf ./${PKGDIR}.old
		mv ./${PKGDIR} ./${PKGDIR}.old
	else
		REUSETAGS=0
		rm -Rf ./${PKGDIR}
	fi;
fi;

mkdir ./${PKGDIR}

if [ $? -ne 0 ]; then
	echo "Unable to create directory ${PKGDIR}/"
	exit 1
fi;

SLACKVER=`head /${SLACKDIR}/README.TXT | grep Welcome | \
sed 's/Welcome to //' | sed 's/!//'`
DATE=`date`
cat /dev/null > ./${PKGDIR}/tagfiles.nfo
echo "# Slackware PKG TAG file" >> ./${PKGDIR}/tagfiles.nfo
echo "# Generated on `date` " >> ./${PKGDIR}/tagfiles.nfo
echo "# for " >> ./${PKGDIR}/tagfiles.nfo
echo "# ${SLACKVER}" >> ./${PKGDIR}/tagfiles.nfo

for CAT in `ls -gG1 /${SLACKDIR}/${PKGDIR}/ | grep ^d |\
 	awk '{ print $6 }'`; do 

### "Old way" using Slackware's menus; not bad and fast ###
#	sh /${SLACKDIR}/${PKGDIR}/${CAT}/maketag 2>/dev/null
#	mkdir ${PKGDIR}/${CAT}
#	cat /var/log/setup/tmp/SeTnewtag >> ${PKGDIR}/${CAT}/tagfile
###########################################################

# dialog parameters
	DLGPRM=''
	TAGLIST=''
	for LINE in `cat /${SLACKDIR}/${PKGDIR}/${CAT}/tagfile`\
	; do
		TAG=`echo $LINE | cut -d \: -f 1`
		TAGLIST+="${TAG} "
		if [ $REUSETAGS -eq 1 ]; then
			TLINE=`cat ./${PKGDIR}.old/${CAT}/tagfile 2>/dev/null | grep ^${TAG}:`
			if [ $? -eq 0 ]; then
				STATE=`echo $TLINE | cut -d \: -f 2 | sed 's/ //g'`
			else
				STATE=`echo $LINE | cut -d \: -f 2 | sed 's/ //g'`
			fi;
		else
			STATE=`echo $LINE | cut -d \: -f 2 | sed 's/ //g'`
		fi;
		STATETXT=''
		case $STATE in
			ADD)
			OPTION='on';;
			REC)
			OPTION='on'
			STATETXT='REQUIRED';;
			SKP)
			OPTION='off';;
			*)
			OPTION='off';;
		esac
		if [ $PKGDESC -eq 1 ]; then
#			This is broken, but I don't care. Please, send me the patch, 
#			if you want.
#			DESC=`head -n 1 /${SLACKDIR}/${PKGDIR}/${CAT}/${TAG}-[0-9]*.txt \
#			2>/dev/null | cut -d \: -f 2 | sed s/[\)\(\n]//g | \
#			sed "s/${TAG} ${TAG}//g"`
#			TDESC=`cat /${SLACKDIR}/${PKGDIR}/${CAT}/maketag | \
#			fgrep "\"${TAG}\"" | cut -d \" -f 4`
#			DESC="${TDESC} ${STATE}"
#			DLGPRM+="${TAG} \"${DESC}\" ${OPTION} "
			DLGPRM+="${TAG} \"$STATE\" ${OPTION} "
		else
			DLGPRM+="${TAG} \"${STATE}\" ${OPTION} "
		fi;
	done;
	LINES=`cat /${SLACKDIR}/${PKGDIR}/${CAT}/tagfile | wc -l`
	cat /dev/null > ./pkgListTmp

	dialog --title "SELECTING PACKAGES FROM SERIES ${CAT}" \
       --checklist "Please confirm the packages you wish to install \
from series ${CAT}.  Use the UP/DOWN keys to scroll through the list, and \
the SPACE key to deselect any items you don't want to install.  \
Press ENTER when you are done." \
22 70 10 \
$DLGPRM \
2>pkgListTmp
	
	mkdir ./${PKGDIR}/${CAT}
	cat /dev/null > ./${PKGDIR}/${CAT}/tagfile
	if [ $? = 1 -o $? = 255 ]; then
		cat /dev/null > ./pkgListTmp
		> $TMP/SeTnewtag
		for TAG in $TAGLIST; do
			echo "$TAG: SKP" >> ./${PKGDIR}/${CAT}/tagfile
		done;
		echo "# ${CAT} / $LINES / 0 / $LINES" >> ./${PKGDIR}/tagfiles.nfo
		continue
	fi;

	ADDED=0
	SKIPPED=0
	for TAG in $TAGLIST; do
		if fgrep \"$TAG\" ./pkgListTmp 1> /dev/null 2> /dev/null ; then
			echo "$TAG: ADD" >> ./${PKGDIR}/${CAT}/tagfile
			ADDED+=1
		else
			echo "$TAG: SKP" >> ./${PKGDIR}/${CAT}/tagfile
			SKIPPED+=1
		fi;
	done;
	echo "# ${CAT} / $LINES / $ADDED / $SKIPPED" >> ./${PKGDIR}/tagfiles.nfo
	cat /dev/null > ./pkgListTmp
done;
rm -f ./pkgListTmp

echo "Success"

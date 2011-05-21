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
set -u
# Where can we find mounted Slackware CD/DVD/etc.
SLACKDIR='/mnt/cdrom/'
#TMP='/tmp/'
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
#fi
#################################

rm -f ./SLACKDIR 2>/dev/null
rm -f ./pkgListTmp 2>/dev/null

# new version with dialog
dialog --title "Slackware directory" --inputbox "Please, enter path \
to Slackware directory \
eg. mounted CD/DVD-ROM, or use default (${SLACKDIR})" 8 70 2>SLACKDIR
if [ -s './SLACKDIR' ]; then
	SLACKDIR=$(cat ./SLACKDIR)
	rm -f ./SLACKDIR
fi

if [ ! -d "${SLACKDIR}/slackware" ] && [ ! -d "${SLACKDIR}/slackware64" ]; then 
	echo "There seems to be no slackware directory in ${SLACKDIR}"
	echo "Make sure Slackware is there, or check the permissions"
	exit 1
fi

LSOUT=$(ls "${SLACKDIR}" 2>/dev/null | grep -E -e '^slackware(64)?$')
# there might be more than one dir, but it's unlikely.
PKGDIR=$(echo ${LSOUT} | cut -d ' ' -f 1)

REUSETAGS=0
if [ -d "./${PKGDIR}" ]; then
	dialog --title "Old tag files" --yesno "It looks I've found the \
last set of tag files you've generated. Should I re-use them, if \
possible, or start over (= delete)?" 10 72
	if [ $? == 0 ]; then
		REUSETAGS=1
		rm -Rf "./${PKGDIR}.old"
		mv "./${PKGDIR}" "./${PKGDIR}.old"
	else
		REUSETAGS=0
		rm -Rf "./${PKGDIR}"
	fi
fi

if ! $(mkdir "./${PKGDIR}" 2>/dev/null) ; then
	echo "Unable to create directory './${PKGDIR}'"
	exit 1
fi

SLACKVER=$(head "/${SLACKDIR}/README.TXT" | grep -e 'Welcome' | \
	sed -e 's/Welcome to //' | sed -e 's/!//')
DATE=$(date)
cat /dev/null > "./${PKGDIR}/tagfiles.nfo"
echo "# Slackware PKG TAG file" >> "./${PKGDIR}/tagfiles.nfo"
echo "# Generated on ${DATE}" >> "./${PKGDIR}/tagfiles.nfo"
echo "# for " >> "./${PKGDIR}/tagfiles.nfo"
echo "# ${SLACKVER}" >> "./${PKGDIR}/tagfiles.nfo"

if [ ! -e "/${SLACKDIR}/CHECKSUMS.md5" ]; then
	echo "File '${SLACKDIR}/CHECKSUMS.md5' doesn't seem to exist."
	exit 1
fi

for CAT in $(cat "/${SLACKDIR}/CHECKSUMS.md5" | grep -e "\.\/${PKGDIR}" | \
	awk '{ print $2 }' | cut -d '/' -f 3 | sort | uniq); do
	if [ ! -d "/${SLACKDIR}/${PKGDIR}/${CAT}" ]; then
		continue
	fi
### "Old way" using Slackware's menus; not bad and fast ###
#	sh /${SLACKDIR}/${PKGDIR}/${CAT}/maketag 2>/dev/null
#	mkdir ${PKGDIR}/${CAT}
#	cat /var/log/setup/tmp/SeTnewtag >> ${PKGDIR}/${CAT}/tagfile
###########################################################

# dialog parameters
	DLGPRM=''
	TAGLIST=''
	for LINE in $(cat "/${SLACKDIR}/${PKGDIR}/${CAT}/tagfile"); do
		TAG=$(echo "${LINE}" | cut -d ':' -f 1)
		TAGLIST="${TAGLIST} ${TAG}"
		if [ ${REUSETAGS} -eq 1 ]; then
			TLINE=$(cat "./${PKGDIR}.old/${CAT}/tagfile" 2>/dev/null | \
				grep -e "^${TAG}:")
			if [ "${TLINE}" ]; then
				STATE=$(echo "${TLINE}" | cut -d ':' -f 2 | sed -e 's/ //g')
			else
				STATE=$(echo "${LINE}" | cut -d ':' -f 2 | sed -e 's/ //g')
			fi
		else
			STATE=$(echo "${LINE}" | cut -d ':' -f 2 | sed -e 's/ //g')
		fi
		STATETXT=''
		case "${STATE}" in
			'ADD')
				OPTION='on'
				;;
			'REC')
				OPTION='on'
				STATETXT='REQUIRED'
				;;
			'SKP')
				OPTION='off'
				;;
			*)
				OPTION='off'
				;;
		esac
		if [ ${PKGDESC} -eq 1 ]; then
			TDESC=$(grep -e "^\"${TAG}\"" "/${SLACKDIR}/${PKGDIR}/${CAT}/maketag" | \
				cut -d '"' -f 4 | tr ' ' '_')
			if [ -z "${TDESC}" ]; then
				TDESC=$(head -n 1 /${SLACKDIR}/${PKGDIR}/${CAT}/${TAG}-[0-9]*.txt \
					2>/dev/null | cut -d '(' -f 2 | sed -e 's/[()]+//g' | tr ' ' '_')
			fi
			if [ -z "${TDESC}" ]; then
				TDESC="${STATE}"
			fi
			DLGPRM+="${TAG} ${TDESC} ${OPTION} "
		else
			DLGPRM+="${TAG} \"${STATE}\" ${OPTION} "
		fi
	done
	LINES=$(cat /${SLACKDIR}/${PKGDIR}/${CAT}/tagfile | wc -l)
	cat /dev/null > ./pkgListTmp

	mkdir "./${PKGDIR}/${CAT}"
	cat /dev/null > "./${PKGDIR}/${CAT}/tagfile"
	dialog --title "SELECTING PACKAGES FROM SERIES ${CAT}" \
       --checklist "Please confirm the packages you wish to install \
from series ${CAT}.  Use the UP/DOWN keys to scroll through the list, and \
the SPACE key to deselect any items you don't want to install.  \
Press ENTER when you are done." \
21 76 10 \
${DLGPRM} \
2> ./pkgListTmp
	if [ $? = 1 -o $? = 255 ]; then
		cat /dev/null > ./pkgListTmp
#		cat /dev/null > "${TMP}/SeTnewtag"
		for TAG in $(echo "${TAGLIST}"); do
			echo "${TAG}: SKP" >> "./${PKGDIR}/${CAT}/tagfile"
		done
		echo "# ${CAT} / ${LINES} / 0 / ${LINES}" >> "./${PKGDIR}/tagfiles.nfo"
		continue
	fi

	ADDED=0
	SKIPPED=0
	for TAG in $(echo "${TAGLIST}"); do
		if $(grep -q -e "${TAG}" ./pkgListTmp 1> /dev/null 2> /dev/null) ; then
			echo "${TAG}: ADD" >> "./${PKGDIR}/${CAT}/tagfile"
			ADDED=$(($ADDED+1))
		else
			echo "$TAG: SKP" >> "./${PKGDIR}/${CAT}/tagfile"
			SKIPPED=$(($SKIPPED+1))
		fi
	done
	echo "# ${CAT} / ${LINES} / ${ADDED} / ${SKIPPED}" \
		>> "./${PKGDIR}/tagfiles.nfo"
	cat /dev/null > ./pkgListTmp
done
rm -f ./pkgListTmp

echo "Success"

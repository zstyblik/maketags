#!/bin/sh
# Desc: Slackware/Slack-Kickstart Tag-file generator
# 2013/May/09 @ Zdenek Styblik
# "Yo Adrian, I did it!"
set -e
set -u

# PATH to CHECKSUMS.md5
SLACKDIR=${SLACKDIR:-''}
# Output dir where tag-lists will be written
OUTDIR=${OUTDIR:-''}
IFS='
'
REUSE=0

function print_keys_help()
{
	printf "Controls:\n"
	printf "* 'a' - add package(default)\n"
	printf "* 'd' - show description\n"
	printf "* 'h' - print this help\n"
	printf "* 's' - skip package\n"
	printf "* 'v' - lock package version\n"
	printf "* 'jj' - add all packages from current serie\n"
	printf "* 'kk' - skip all packages from current serie\n"
	printf "* 'zz' - skip/end selection of current serie\n"
}

if which less >/dev/null 2>&1 ; then
	PAGER=$(which less)
elif which more >/dev/null 2>&1 ; then
	PAGER=$(which more)
else
	printf "No suitable PAGER found.\n" 1>&2
	exit 1
fi


if [ -z "${SLACKDIR}" ]; then
	SLACK_CD_FILE="/mnt/cdrom/"
	printf "Please enter path to mounted Slackware CD/DVD-ROM, or directory \n"
	printf "with 'CHECKSUMS.md5'. Empty value means to use default \n"
	printf "directory: '%s'.\n" "${SLACKDIR}"
	printf "Path to Slackware CD: "
	MYTMP=""
	read MYTMP
	if [ ! -z "${MYTMP}" ]; then
		SLACKDIR="${MYTMP}"
	fi
fi

CHECKSUMS="${SLACKDIR}/CHECKSUMS.md5"
if [ ! -e "${CHECKSUMS}" ]; then
	printf "Error: '%s' doesn't exist or not readable.\n" \
		"${CHECKSUMS}" 1>&2
	exit 1
fi

SLACKVER=$(grep -e 'ANNOUNCE' "${CHECKSUMS}" | \
	awk '{ print $2 }' | sed 's@./@@' | awk -F'.' '{ print $2 }')
if [ -z "${SLACKVER}" ]; then
	SLACKVER="unknown"
fi

SUFFIX=""
if grep -q -e './slackware64/' "${CHECKSUMS}" ; then
	SUFFIX="64"
fi

if [ -z "${OUTDIR}" ] && [ $# -gt 0 ]; then
	OUTDIR=${1:-''}
fi
if [ -z "${OUTDIR}" ]; then
	OUTDIR="slackware${SUFFIX}-${SLACKVER}"
	printf "Provide a name of directory where to save tag-file structure\n"
	printf "or empty value to use default('%s'): " "${OUTDIR}"
	MYTMP=""
	read MYTMP
	if [ ! -z "${MYTMP}" ]; then
		OUTDIR="${MYTMP}"
	fi
fi

OUTDIR_TMP=$(basename "${OUTDIR}")
if [ "${OUTDIR_TMP}" = "." ] || [ "${OUTDIR_TMP}" = "" ]; then
	printf "Invalid output directory given.\n" 1>&2
	exit 1
fi

if [ -d "${OUTDIR}" ]; then
	CDATE=$(date "+%F_%H%M%S")
	printf "Directory '%s' already exists. Possible actions:\n" "${OUTDIR}"
	printf "* [D]elete it\n"
	printf "* [R]ename it to '%s-%s'\n" "${OUTDIR}" "${CDATE}"
	printf "* re[U]se old tags\n"
	while [ 1 -gt 0 ]; do
		printf "What should I do?: "
		MYTMP=""
		read MYTMP
		case "${MYTMP}" in
			"d"|"D")
				printf "Removing '%s'.\n" "${OUTDIR}"
				rm -rf "${OUTDIR}"
				mkdir "${OUTDIR}"
				break
				;;
			"r"|"R")
				printf "Renaming '%s' to '%s'.\n" "${OUTDIR}" \
					"${OUTDIR}-${CDATE}"
				mv "${OUTDIR}" "${OUTDIR}-${CDATE}"
				mkdir "${OUTDIR}"
				break
				;;
			"u"|"U")
				printf "Will re-use tag info, if possible.\n"
				REUSE=1
				break
				;;
		esac
	done
else
	mkdir "${OUTDIR}"
fi

UPFILTER=""
if [ $REUSE -ne 0 ]; then
	printf "If you want to modify(update) only specific serie(s), then provide\n"
	printf "space delimited list. Empty value means to modify all series: "
	read UPFILTER
	if [ ! -z "${UPFILTER}" ] && ! printf -- "%s" "${UPFILTER}" | \
		grep -q -E -e '^[a-z\s]+$'; then
		printf "Error: Invalid list of Series given.\n" 1>&2
		exit 1
	fi
fi

print_keys_help
for SERIE in $(grep -E -e "./slackware${SUFFIX}/[a-z]+/" "${CHECKSUMS}" |\
	awk '{ print $2 }' | sed 's@^./@@' | awk -F'/' '{ print $2 }' | \
	sort | uniq); do
	SKIP_SERIE=0
	if [ $REUSE -ne 0 ] && [ ! -z "${UPFILTER}" ]; then
		IFS=' '
		FOUND=0
		for SERTOUP in $UPFILTER; do
			if [ -z "${SERTOUP}" ] || [ "${SERTOUP}" != ${SERIE} ]; then
				continue
			fi
			FOUND=1
			break
		done
		IFS='
		'
		if [ $FOUND -eq 0 ]; then
			continue
		fi
		FOUND=0
	fi
	if [ ! -d "${OUTDIR}/${SERIE}/" ]; then
		mkdir "${OUTDIR}/${SERIE}/"
	fi
	TAGFILE="${OUTDIR}/${SERIE}/tagfile"
	if [ $REUSE -ne 0 ] && [ -e "${TAGFILE}" ]; then
		mv "${TAGFILE}" "${TAGFILE}.old"
	fi
	printf "Getting packages for serie '%s'...\n" "${SERIE}"
	CHOICE_OVERR=""
	for PKG in $(grep -E -e "./slackware${SUFFIX}/${SERIE}/.*\.t(g|x)z$" \
		"${CHECKSUMS}" | awk '{ print $2 }' | sed 's@^./@@'); do
		PKG_NOSUFF=$(printf -- "%s" "${PKG}" |\
			awk '{ arrlen=split($0, arr, "/"); printf "%s",arr[arrlen]; }' |\
			sed 's@.t[g|x]z$@@')
		PKG_NAME=$(printf -- "%s" "${PKG_NOSUFF}" | \
			awk '{ arrlen=split($0, arr, "-");
			for (i = 1; i < (arrlen-2); i++) {
				printf "%s", arr[i];
				if ((i + 1) < (arrlen-2)) { printf "-" };
			} }')
		PKG_VER=$(printf -- "%s" "${PKG_NOSUFF}" | \
			awk '{ arrlen=split($0, arr, "-"); printf "%s",arr[arrlen-2]; }')
		CHOICE_DEF='a'
		EXTRA=""
		if [ $REUSE -ne 0 ] && [ -e "${TAGFILE}.old" ]; then
			CHOICE_OLD=$(grep -e "${PKG_NAME}" "${TAGFILE}.old" | \
				awk -F':' '{ print $2 }' | perl -p -e 's/\s+//')
			if [ "${CHOICE_OLD}" = "ADD" ]; then
				CHOICE_DEF='a'
			elif [ "${CHOICE_OLD}" = "SKP" ]; then
				CHOICE_DEF='s'
			fi
		fi
		while [ 1 -gt 0 ]; do
			printf "Package '%s' [%s]: %s" "${PKG_NOSUFF}" "${CHOICE_DEF}" \
				"${CHOICE_OVERR}"
			if [ -z "${CHOICE_OVERR}" ]; then
				read MYCHOICE
			else
				MYCHOICE="${CHOICE_OVERR}"
				printf "\n"
			fi
			if [ -z "${MYCHOICE}" ]; then
				MYCHOICE="${CHOICE_DEF}"
			fi
			case "${MYCHOICE}" in
				'a'|'A')
					ACT="ADD"
					break ;;
				'd'|'D')
					PKGDESC="${SLACKDIR}/slackware${SUFFIX}/${SERIE}/${PKG_NOSUFF}.txt"
					if [ -e "${PKGDESC}" ]; then
						$PAGER "${PKGDESC}"
					else
						printf "File '%s' doesn't seem to exist.\n" \
							"${PKGDESC}" 1>&2
					fi
					;;
				'h'|'H')
					print_keys_help
					;;
				's'|'S')
					ACT="SKP"
					break
					;;
				'v'|'V')
					ACT="ADD"
					EXTRA="-${PKG_VER}"
					break
					;;
				'jj'|'JJ')
					CHOICE_OVERR='a'
					;;
				'kk'|'KK')
					CHOICE_OVERR='s'
					;;
				'zz'|'ZZ')
					SKIP_SERIE=1
					break
					;;
			esac
		done
		if [ $SKIP_SERIE -ne 0 ]; then
			break
		fi
		printf "%s%s: %s\n" "${PKG_NAME}"  "${EXTRA}" "${ACT}" >> "${TAGFILE}"
	done
	rm -f "${OUTDIR}/${SERIE}/taglist.old"
done

KSFILE=$(basename -- "${OUTDIR}")
if [ "${KSFILE}" = "." ]; then
	KSFILE="${OUTDIR}"
fi
KSFILE="${OUTDIR}/${KSFILE}.ks.tagfile"
printf "Will create Slack-Kickstart file '%s'\n" "${KSFILE}"
cat /dev/null > "${KSFILE}"
printf "# Slack-Kickstart tag file\n" > "${KSFILE}"
for SERIE in $(ls -1 "${OUTDIR}/"); do
	if [ ! -d "${OUTDIR}/${SERIE}" ]; then
		continue
	fi
	if ! grep -q -e "./slackware${SUFFIX}/${SERIE}/" "${CHECKSUMS}" ; then
		printf "Note: Serie '%s' probably became obsolete.\n" "${SERIE}" 1>&2
	fi
	if [ -e "${OUTDIR}/${SERIE}/tagfile" ]; then
		printf "# Packages of serie '%s'\n" "${SERIE}" >> "${KSFILE}"
		for LINE in $(cat "${OUTDIR}/${SERIE}/tagfile"); do
			printf "#@%s/%s\n" "${SERIE}" "${LINE}" >> "${KSFILE}"
		done
	fi
done

printf "All done.\n"
# EOF

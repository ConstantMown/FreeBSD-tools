#!/bin/sh
#
# FreeBSD automagical update
#

set -u

#
# Download updates, if available
#
#out1="$(/usr/sbin/freebsd-update --not-running-from-cron fetch)"
#rv=$?
#if [ -n "$out1" ] ; then
#	printf 'Command "freebsd-update --not-running-from-cron fetch", downloaded updates\n'
#	echo "$out1"
#	printf 'Command "freebsd-update --not-running-from-cron fetch" return value was "%d"\n' "$rv"
#else
#	exit 0
#fi

out2="$(freebsd-update updatesready)"
rv=$?

case $rv in 
	0)
		install=yes
		printf 'Command "freebsd-update updatesready" found updates to install, command return value was "%d"\n' "$rv"
		;;
	2)
		install=no
		;;
	*)
		install=idk
		printf 'Unexpected return value from command "freebsd-update updatesready"\n'
		exit 1
		;;
esac

reboot=no
if [ "$install" = "yes" ] ; then
	pre_kernel_version=$(freebsd-version -k)
	pre_userland_version=$(freebsd-version -u)
	printf 'FreeBSD kernel, running and userland versions, before installing updates are:\n'
	freebsd-version -kru
	printf '\nRunning "freebsd-update install", in order to install updates\n'
	out3="$(/usr/sbin/freebsd-update install)"
	rv=$?
	echo "$out3"
	printf 'Command "freebsd-update install" return value was "%d"\n' "$rv"
	post_kernel_version=$(freebsd-version -k)
	post_userland_version=$(freebsd-version -u)
	printf '\nFreeBSD kernel, running and userland versions, after installing updates are:\n'
	freebsd-version -kru
	if [ "$pre_kernel_version" != "$post_kernel_version" ] ; then
		reboot=yes
	else
		if ls -l /lib /usr/lib 2>/dev/null | grep -q "$(date '+%b %d' | sed -e 's/ 0/  /')" ; then
			reboot=yes
		fi
	fi
fi
if [ "$reboot" = "yes" ] ; then
	printf 'Rebooting "%s" at "%s"\n' "$(uname -n)" "$(date)"
	shutdown -r now
fi
exit 0

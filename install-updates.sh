#!/bin/sh
#
# FreeBSD automagical update
#

set -u

LOCKFILE="/var/run/$(basename "$0").lock"

cleanup() {
	rm -f "$LOCKFILE"
}
trap 'cleanup; exit 1' INT TERM HUP EXIT

#
# If exit value is zero, then there is something that one must wait before proceeeding.
#
my_wait() {
	ps ax | grep -v grep | grep -q poudriere
	return $?
}

if [ -f "$LOCKFILE" ]; then
	read oldpid < "$LOCKFILE"
	if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
		# Another instance is running
		exit 0
	else
		# Stale lock
		rm -f "$LOCKFILE"
	fi
fi

# Obtain lock (atomic)
( set -o noclobber; echo "$$" > "$LOCKFILE" ) 2>/dev/null || exit 0

if my_wait ; then
	printf 'Waiting until cleared to continue\n'
	while my_wait
	do
		printf '.'
		sleep 60
	done
fi

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
#	cleanup
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
		cleanup
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
	cleanup
	printf 'Rebooting "%s" at "%s"\n' "$(uname -n)" "$(date)"
	shutdown -r now
fi

cleanup
exit 0

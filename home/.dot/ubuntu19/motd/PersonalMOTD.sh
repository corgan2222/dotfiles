#/bin/bash

function install_dependencies {
	echo "Installing dependencies..."
	if [ ! -x /usr/bin/lsb_release ] && [ /etc/lsb-release ]; then 
	dependencies=$dependencies" lsb-release"
	fi

	if [ ! -x /usr/bin/figlet ]; then 
	dependencies=$dependencies" figlet"
	fi

	if [[ -z `dpkg -s python-apt 2> /dev/null | grep installed` ]]; then 
			dependencies=$dependencies" python-apt"
	fi

	if [ ! -z `echo $dependencies` ]; then
		apt-get update
		apt-get -y install$dependencies
	fi
}



echo -n "Setting up directories..."
if [ ! -d /etc/update-motd.d ]; then
		mkdir /etc/update-motd.d
else 
	echo "Previous configuration detected. ¿Remove it? (Note that some files might get overwritten if not)"
	select yn in "Yes" "No" "Exit"; do
		case $yn in
			Yes ) rm -r /etc/update-motd.d; mkdir /etc/update-motd.d; break;;
			No ) break;;
			Exit ) exit;;
		esac
	done
fi


echo "Done."

install_dependencies

echo "\\n"
echo "---------------------------------"
echo "Setting up update-motd.d files..."
echo "---------------------------------"

echo -n "Setting up 00-header..."
echo "#!/bin/sh
#
#    00-header - create the header of the MOTD
#    Copyright (c) 2013 Nick Charlton
#    Copyright (c) 2009-2010 Canonical Ltd.
#
#    Authors: Nick Charlton <hello@nickcharlton.net>
#             Dustin Kirkland <kirkland@canonical.com>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License along
#    with this program; if not, write to the Free Software Foundation, Inc.,
#    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

[ -r /etc/lsb-release ] && . /etc/lsb-release

if [ -z \"\$DISTRIB_DESCRIPTION\" ] && [ -x /usr/bin/lsb_release ]; then
		# Fall back to using the very slow lsb_release utility
		DISTRIB_DESCRIPTION=\$(lsb_release -s -d)
fi

figlet \$(hostname)
printf \"\n\"

printf \"Welcome to %s (%s).\n\" \"\$DISTRIB_DESCRIPTION\" \"\$(uname -r)\"
printf \"\n\"" > /etc/update-motd.d/00-header
echo "Done."

echo -n "Setting up 10-sysinfo..."
echo "#!/bin/bash
#
#    10-sysinfo - generate the system information
#    Copyright (c) 2013 Nick Charlton
#
#    Authors: Nick Charlton <hello@nickcharlton.net>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License along
#    with this program; if not, write to the Free Software Foundation, Inc.,
#    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

date=\`date\`
load=\`cat /proc/loadavg | awk '{print \$1}'\`
root_usage=\`df -h / | awk '/\// {print \$(NF-1)}'\`
memory_usage=\`free -m | awk '/Mem/ { printf(\"%3.1f%%\", \$3/\$2*100) }'\`
swap_usage=\`free -m | awk '/Swap/ { printf(\"%3.1f%%\", \$3/\$2*100) }'\`
users=\`users | wc -w\`

echo \"System information as of: \$date\"
echo
printf \"System load:\t%s\tMemory usage:\t%s\n\" \$load \$memory_usage
printf \"Usage on /:\t%s\tSwap usage:\t%s\n\" \$root_usage \$swap_usage
printf \"Local users:\t%s\n\" \$users
echo" > /etc/update-motd.d/10-sysinfo
echo "Done."


echo -n "Setting up (cached) 20-updates..."

echo "#!/usr/bin/python
#
#   20-updates - create the system updates section of the MOTD
#   Copyright (c) 2013 Nick Charlton
#
#   Authors: Nick Charlton <hello@nickcharlton.net>
#   Based upon prior work by Dustin Kirkland and Michael Vogt.
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License along
#   with this program; if not, write to the Free Software Foundation, Inc.,
#   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

import sys
import subprocess
import apt_pkg

DISTRO = subprocess.Popen([\"lsb_release\", \"-c\", \"-s\"],
						  stdout=subprocess.PIPE).communicate()[0].strip()

class OpNullProgress(object):
	'''apt progress handler which supresses any output.'''
	def update(self):
		pass
	def done(self):
		pass

def is_security_upgrade(pkg):
	'''
	Checks to see if a package comes from a DISTRO-security source.
	'''
	security_package_sources = [(\"Ubuntu\", \"%s-security\" % DISTRO),
							   (\"Debian\", \"%s-security\" % DISTRO)]

	for (file, index) in pkg.file_list:
		for origin, archive in security_package_sources:
			if (file.archive == archive and file.origin == origin):
				return True
	return False

# init apt and config
apt_pkg.init()

# open the apt cache
try:
	cache = apt_pkg.Cache(OpNullProgress())
except SystemError, e:
	sys.stderr.write(\"Error: Opening the cache (%s)\" % e)
	sys.exit(-1)

# setup a DepCache instance to interact with the repo
depcache = apt_pkg.DepCache(cache)

# take into account apt policies
depcache.read_pinfile()

# initialise it
depcache.init()

# give up if packages are broken
if depcache.broken_count > 0:
	sys.stderr.write(\"Error: Broken packages exist.\")
	sys.exit(-1)

# mark possible packages
try:
	# run distro-upgrade
	depcache.upgrade(True)
	# reset if packages get marked as deleted -> we don't want to break anything
	if depcache.del_count > 0:
		depcache.init()

	# then a standard upgrade
	depcache.upgrade()
except SystemError, e:
	sys.stderr.write(\"Error: Couldn't mark the upgrade (%s)\" % e)
	sys.exit(-1)

# run around the packages
upgrades = 0
security_upgrades = 0
for pkg in cache.packages:
	candidate = depcache.get_candidate_ver(pkg)
	current = pkg.current_ver

	# skip packages not marked as upgraded/installed
	if not (depcache.marked_install(pkg) or depcache.marked_upgrade(pkg)):
		continue

	# increment the upgrade counter
	upgrades += 1

	# keep another count for security upgrades
	if is_security_upgrade(candidate):
		security_upgrades += 1

	# double check for security upgrades masked by another package
	for version in pkg.version_list:
		if (current and apt_pkg.version_compare(version.ver_str, current.ver_str) <= 0):
			continue
		if is_security_upgrade(version):
			security_upgrades += 1
			break

print \"%d updates to install.\" % upgrades
print \"%d are security updates.\" % security_upgrades
print \"\" # leave a trailing blank line"> /etc/update-motd.d/updates.py

echo "#!/bin/sh
#
#    20-updates - manages the system updates section of the MOTD
#    Copyright (c) 2014 Diego Muñoz Callejo
#    Copyright (c) 2009-2010 Canonical Ltd.
#
#    Authors: Diego Muñoz Callejo <dmcelectrico@gmail.com>
#             Dustin Kirkland <kirkland@canonical.com>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License along
#    with this program; if not, write to the Free Software Foundation, Inc.,
#    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
out=/etc/update-motd.d/updates.cache
script=\"/etc/update-motd.d/updates.py\"
if [ -f \"\$out\" ]; then
	# Output exists, print it
	echo
	cat \"\$out\"
	# See if it's expired, and background update
	lastrun=\$(stat -c \%Y \"\$out\") || lastrun=0
	expiration=\$(expr \$lastrun + 43200)
	if [ \$(date +\%s) -ge \$expiration ]; then
		\$script > \"\$out\" &
	fi
else
	# No cache at all, so update in the background
	\$script > \"\$out\" &
fi
"> /etc/update-motd.d/20-updates
echo "Done."

echo -n "Setting up 99-footer..."
echo "#!/bin/sh
#
#    99-footer - write the admin's footer to the MOTD
#    Copyright (c) 2013 Nick Charlton
#    Copyright (c) 2009-2010 Canonical Ltd.
#
#    Authors: Nick Charlton <hello@nickcharlton.net>
#             Dustin Kirkland <kirkland@canonical.com>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License along
#    with this program; if not, write to the Free Software Foundation, Inc.,
#    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

[ -f /etc/motd.tail ] && cat /etc/motd.tail || true" > /etc/update-motd.d/99-footer
echo "Done."

echo -n "Setting file permissions..."
chmod u+x /etc/update-motd.d/*
echo "Done."

echo -n "Setting new motd..."

rm /etc/motd
ln -s /var/run/motd /etc/motd
echo "Done."

echo "--------------------------"
echo "EVERYTHING DONE, new MOTD:"
echo "--------------------------"

/etc/update-motd.d/00-header
/etc/update-motd.d/10-sysinfo
/etc/update-motd.d/20-updates	#This creates the updates.cache file
/etc/update-motd.d/updates.py	#And this shows the section (with the obvious delay)
/etc/update-motd.d/99-footer
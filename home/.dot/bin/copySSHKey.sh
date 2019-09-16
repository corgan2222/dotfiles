#!/bin/bash
#function which contains the ssh public key for user admin to add in the servers and another function to check if key already exists
#If you want to add your user key, replace the admin with your username and add your ssh key to the section shown below.
##################################################################
admin_keyexist_check()
{
if grep -q "******ssh key goes here******admin@<serverhostname>" /home/admin/.ssh/authorized_keys; then
    echo " The ssh key already exists and is shown below...!!"
       grep -i "admin" /home/admin/.ssh/authorized_keys
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "Removing this shell script now...!!"
    rm -fv $0
    exit
else
    echo " The ssh key doesn't exists...!! We will add it...!!"
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
fi
}
###################################################################
admin_pub_key()
{
chmod 700 /home/admin/.ssh;
chown admin:admin/home/admin/.ssh;
echo "******ssh key goes here******admin@<serverhostname>" >> /home/admin/.ssh/authorized_keys;
chmod 600 /home/admin/.ssh/authorized_keys;
chown admin:admin/home/admin/.ssh/authorized_keys
grep -i "admin" /home/admin/.ssh/authorized_keys ;
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
ls -l -h /home/admin/.ssh/authorized_keys
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
}
##################################################################
if [ "$EUID" -ne 0 ]
  then echo "Please run this script as root"
  exit
fi
##################################################################
if getent passwd "admin" > /dev/null 2>&1; then
        echo "Yes, the user admin exists...!!"
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
else
    echo "No, the user admin does not exist...!!"
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    useradd admin;
fi
###################################################################
if grep -q "admin" /etc/sudoers
then
echo "The entry already exists in the sudo list. Please see the entry provided below...!!"
grep -i "admin" /etc/sudoers
else
echo "The entry doesn't exists..!! Going to add the entry for admin to sudo list now...!!"
echo "admin ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers
grep -i "admin" /etc/sudoers
fi
##################################################################
    if [ ! -d /home/admin/.ssh ]; then
        echo "Folder to add the ssh key not found ...!!"
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "We are going to create the folder and adding the SSH authenticated key now..!!"
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    mkdir /home/admin/.ssh ;
    admin_pub_key;   
  else
    echo "The user directory already exists...!! Going to add the SSH key to the authenticated list...!!"
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
     admin_keyexist_check;
     admin_pub_key;
fi
###################################################################
echo "This shell script has completed running now...!! Thanks ...!! We will remove script now...!!"
rm -fv $0
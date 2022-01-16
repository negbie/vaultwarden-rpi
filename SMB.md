sudo apt-get update
sudo apt-get upgrade
sudo apt-get install samba samba-common-bin ntfs-3g
sudo mkdir /media/usb
sudo chown -R pi:pi /media/usb
sudo mount /dev/sda1 /media/usb -o uid=pi,gid=pi
+++
/dev/sda1 /media/usb vfat auto,nofail,noatime,users,rw,uid=pi,gid=pi 0 0
+++
mkdir /media/usb/share

+++
[share]
Comment = Raspberry Pi Shared Folder
Path = /media/usb/share
Browseable = yes
Writeable = Yes
only guest = no
create mask = 0777
directory mask = 0777
Public = no
Guest ok = no
+++

sudo smbpasswd -a pi
sudo service smbd restart

sudo apt-get update  
sudo apt-get upgrade  
sudo apt-get install samba samba-common-bin ntfs-3g rsync vim  
sudo mkdir /media/USBHDD1  
sudo mkdir /media/USBHDD2  
sudo mount -t auto /dev/sda1 /media/USBHDD1  
sudo mount -t auto /dev/sdb1 /media/USBHDD2  
sudo mkdir /media/USBHDD1/shares  
sudo mkdir /media/USBHDD2/shares  
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.old  
sudo vim /etc/samba/smb.conf  
  
+++  
[Backup]  
comment = Backup Folder  
path = /media/USBHDD2/shares  
valid users = @users  
force group = users  
create mask = 0660  
directory mask = 0771  
read only = no  
Public = no  
Guest ok = no  
Browseable = yes  
Writeable = yes  
+++  
  
sudo smbpasswd -a pi  
sudo service smbd restart  
sudo vim /etc/fstab  
  
+++  
/dev/sda1 /media/USBHDD1 auto noatime 0 0  
/dev/sda2 /media/USBHDD2 auto noatime 0 0  
+++  
  
crontab -e  
+++  
0 5 * * * rsync -av --delete /media/USBHDD1/shares /media/USBHDD2/shares/  
+++  
  
rsync -av --delete /media/USBHDD1/shares /media/USBHDD2/shares/  
  

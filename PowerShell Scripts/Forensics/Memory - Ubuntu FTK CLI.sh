forensics=$(blkid -L FORENSICS)
os=$(blkid -L cloudimg-rootfs)
if pgrep -l -x ftkimager > /dev/null && find /mnt/forensics -name "$(hostname -s)".E01.txt > /dev/null
then
while pgrep -l -x ftkimager > /dev/null && find /mnt/forensics -name "$(hostname -s)".E01.txt > /dev/null;do
echo "FTK is running and text file has not been created."
sleep 30s
done
cd /
umount $forensics /mnt/forensics
rm -r /mnt/forensics
else
mkdir /mnt/forensics
mount -L FORENSICS /mnt/forensics
cd /mnt/forensics
mkdir "$(hostname -s)"
sleep 5100
/mnt/forensics/ftkimager $os /mnt/forensics/"$(hostname -s)"/"$(hostname -s)" --e01 --frag 2G --compress 9 --verify
cd /
umount $forensics /mnt/forensics
rm -r /mnt/forensics

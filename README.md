# btrfs-snapshot_mgr
snapshot manager for btrfs 

./snapshot_mgr -s "/mnt/btrfshdd/works" -d "/mnt/usb/btrfshdd/snapshot_repo" -n "MyWorks" -k 7 -K 30 -c "ssh remote.host -p 2222"

-s source subvolume 
-d destination subvolume
-n file name of snapshots (If not provided will generate one using source subvolume name)
-k local keep copies of subvolume (default 7)
-K remote keep copies of subvolume (default 30)
-c ssh tunnel for sending snapshots to remote host

My usage:

vi take_snapshot.sh

```
#!/bin/bash

/root/scripts/tools/btrfs/snapshot_mgr -s "/" -d "/mnt/hdd/.snapshots_repo" -n "$HOSTNAME" -c "ssh nas.host -p 1122"
```



crontab -l

`
30 22 * * * /root/scripts/tools/btrfs/take_snapshot.sh >> /tmp/snapshot.log
`

Every day at 22:30 my Ubuntu22.04 Server (using btrfs as root file system) will automatically take a snapshot and send to my nas.



Enjoy ^-^

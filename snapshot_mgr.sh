#!/bin/bash
# Author: jasonluo
# Date: 2022-06-30

task_name=""
subvolume=""
repo=""
ssh_cmd=""
local_keep=7
remote_keep=30
prefix=snapshot

while getopts ":s::d::n::k::K::c::h" opt
do
        case $opt in
                s)
			subvolume=$OPTARG;;
                d)
			repo=$OPTARG;;
                n)
			task_name=$OPTARG;;
                k)
			local_keep=$OPTARG;;
                K)
			remote_keep=$OPTARG;;
                c)
			ssh_cmd=$OPTARG;;
                h)
			echo "Usage:"
			echo "Required:" 
			echo -e "\t -s [source]"
			echo -e "\t -d [destination]"
			echo "Optional:"
			echo -e "\t -n [task name]"
			echo -e "\t -k [local_keep_count]"
			echo -e "\t -K [remote_keep_count]"
			echo -e "\t -c [ssh_cmd]"
			echo "Example:"
			echo -e "\t" $0' -s "/mnt/hdd/works" -d "/mnt/usb/snapshot_repo" -n "MyWorks" -k 7 -K 30 -c "ssh remote_host -p ports"'
			echo ''
			exit -1;;
                ?)
			echo "error"
                        exit 1;;
        esac
done

if [ "$subvolume" = "" ] || [ "$repo" = "" ];
then
	$0 -h
	exit 1
fi



local_snapshots_path="$subvolume/.snapshots"

function do_exec() {
	cmd=$1
	ssh=$2
	if [ "$ssh" = "" ];
	then
		echo $(eval $cmd)
	else
		echo $(eval $ssh "$cmd")
	fi
}

function prepare_vol() {
	path=$1
	ssh=$2
	cmd="ls -a \"$path\" 2>/dev/null | wc -l"
	check=`do_exec "$cmd" "$ssh"`
	if [ $check -lt 1 ];
	then
		cmd="btrfs subvolume create \"$path\""
		do_exec "$cmd" "$ssh"
	fi
}

function do_expired_clean(){
        path=$1
        name=$2
        max=$3
        ssh=$4

        all=(`do_exec "ls $path | grep $name" "$ssh"`)
        all_num=${#all[@]}
        num=$[$all_num - $max]
        if [ $num -gt 0 ];
        then
                echo "clean expired snapshots"
                index=0
                while [ $num -gt $index ]
                do
                        f=$path/${all[$index]}
                        do_exec "btrfs subvolume delete $f" "$ssh"
                        index=$[$index + 1]
                done
        fi
}

echo "=========== TASK BEGIN : "`date -R`" ==========="

echo "prepare repo subvolume"
prepare_vol "$repo" "$ssh_cmd"

echo "prepare local snapshots subvolume"
prepare_vol "$local_snapshots_path"

if [ "$task_name" = "" ];
then
	# /mnt/hdd/hello -> _mnt_hdd_hello
	task_name=${subvolume//\//_}
fi
snapshot_name=$prefix"-"$task_name"-"$(date +"%Y%m%d_%H%M%S")
echo "create snapshot"
btrfs subvolume snapshot -r $subvolume $local_snapshots_path/$snapshot_name

opt=""
local_all=(`ls $local_snapshots_path | grep $task_name`)
all_num=${#local_all[@]}
if [ $all_num -gt 1 ];
then
	index=$[$all_num - 2]
	while [ $index -gt -1 ]
	do
		prev=${local_all[$index]}
		cmd="ls -a $repo/$prev 2>/dev/null | wc -l"
		repo_check=`do_exec "$cmd" "$ssh_cmd"`
		if [ $repo_check -gt 0 ];
		then
			echo "found previous snapshot:$prev at destination"
			opt="-p $local_snapshots_path/$prev"
			break
		fi
		index=$[$index -1]
	done
fi
if [ "$opt" = "" ];
then
	echo "will send whole snapshots"
else
	echo "will send increment part"
fi
echo "send latest snapshot to destination"

btrfs send $opt $local_snapshots_path/$snapshot_name | do_exec "btrfs receive $repo" "$ssh_cmd"


echo "check local keeps"
do_expired_clean "$local_snapshots_path" "$task_name" "$local_keep" 

echo "check remote keeps"
do_expired_clean "$repo" "$task_name" "$remote_keep" "$ssh_cmd"

echo "=========== TASK END : "`date -R`" ==========="



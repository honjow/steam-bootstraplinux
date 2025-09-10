#!/bin/bash

# 参数解析
while getopts "h:u:d" opt; do
    case $opt in
    h) host_name=$OPTARG ;;
    u) user_name=$OPTARG ;;
    d) dry_run=true ;;
    ?) echo "Usage: $0 -h host_name -u user_name -d" ;;
    esac
done

src_dir=~/.local/share/Steam/
dst_dir=./bootstraplinux_ubuntu12_32/

host_name=${host_name:-mini.local}
user_name=${user_name:-gamer}
rsync -avz --progress --delete -e "ssh -p 22" $user_name@$host_name:$src_dir $dst_dir \
    --exclude "steamapps" \
    --exclude "logs" \
    --exclude "appcache" \
    --exclude ".cef-enable-remote-debugging" \
    ${dry_run:+--dry-run}

rm -rf $dst_dir/{steamapps,logs,appcache}

#!/bin/sh

BASEDIR=$(dirname "$0")
echo ${BASEDIR}

TEMP=`getopt -o pt:a:d:h --long production,data_center:,apply:,delete:,help -- "$@"`
eval set -- "$TEMP"

function show_usage() {
cat <<EOF
Usage: $(basename $0) [options] ...
OPTIONS:
    -p --production                                 Production mode.
    -t --data_center [shenzhen, beijing, ...]       Data center.
    -a --apply [all, signaling, relay, discovery]   Apply server.
    -d --delete [all, signaling, relay, discovery]  Delete server.
    -h --help                                       Show usage.
EOF
exit 0
}

g_mode="dev"
g_production=false
g_data_center="shenzhen"
g_server="all"
g_apply=true

function parse_args() {
    while true
    do
        case "$1" in
            -p|--production) g_mode="production"; g_production=true; echo ${g_mode}; shift 1;;
            -t|--data_center) g_data_center=$2; shift 2 ;;
            -a|--apply) g_apply=true; g_server=$2; shift 2 ;;
            -d|--delete) g_apply=delete; g_server=$2; shift 2 ;;
            -h|--help) show_usage; shift 2 ;;
            --) shift; break ;;
            *) show_usage; exit 1 ;;
        esac
    done
}

parse_args $@

g_yaml_dir=${BASEDIR}/${g_mode}/yaml/${g_data_center}

function operate_one_server() {
    operate=$1
    server_dir=$2
    echo "-----------$operate $server_dir-----------------"

    file_list=`ls $server_dir`
    for file in $file_list
    do
        echo "file: "$file
        kubectl $operate -f ${server_dir}/${file}
    done

    echo "-----------$operate $server_dir done-----------"
}

function operate_all_servers() {
    operate=$1
    yaml_dir=$2

    operate_one_server $operate ${yaml_dir}/discovery
    operate_one_server $operate ${yaml_dir}/signaling
    operate_one_server $operate ${yaml_dir}/relay
}

function operate_server() {
    yaml_dir=$1
    operate=$2
    server=$3

    case $server in
        discovery)
            operate_one_server $operate ${yaml_dir}/discovery
            ;;
        signaling)
            operate_one_server $operate ${yaml_dir}/signaling
            ;;
        relay)
            operate_one_server $operate ${yaml_dir}/relay
            ;;
        all)
            operate_all_servers $operate ${yaml_dir}
            ;;
        *)
            echo $server
            operate_one_server $operate $server
            ;;
    esac
}

function main() {
    if ${g_apply}; then
        operate_server ${g_yaml_dir} apply ${g_server}
    else
        operate_server ${g_yaml_dir} delete ${g_server}
    fi
}

main

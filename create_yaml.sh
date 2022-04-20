#!/bin/sh

BASEDIR=$(dirname "$0")
echo ${BASEDIR}

TEMP=`getopt -o pc:d:h --long production,create:,delete:help -- "$@"`
eval set -- "$TEMP"

function show_usage() {
cat <<EOF
Usage: $(basename $0) [options] ...
OPTIONS:
    -p --production                                 Production mode.
    -c --create [all, discovery, signaling, relay]  Create the YAML of the specified server.
    -d --delete [all, discovery, signaling, relay]  Delete the YAML of the specified server.
    -h --help                                       Show usage.
EOF
exit 0
}

g_mode="dev"
g_server="all"
g_create=true
g_production=false

function parse_args() {
    while true
    do
        case "$1" in
            -p|--production) g_mode="production"; g_production=true; echo ${g_mode}; shift 1;;
            -c|--create) g_server=$2; g_create=true; shift 2 ;;
            -d|--delete) g_server=$2; g_create=false; shift 2 ;;
            -h|--help) show_usage; break ;;
            --) shift; break ;;
            *) show_usage; exit 1 ;;
        esac
    done
}

parse_args $@

g_yaml_dir=${BASEDIR}/${g_mode}/yaml

function parse() {
    row=$1
    field=$2
    echo ${row} | base64 --decode | jq -r ${field}
}

function modify_nats_config() {
    server_dir=$1
    row=$(jq ".nats" ${BASEDIR}/${g_mode}/config.json)
    nats_addr=$(echo $row | jq -r ".nats_addr")
    nats_port=$(echo $row | jq -r ".nats_port")
    nats_user=$(echo $row | jq -r ".nats_user")
    nats_password=$(echo $row | jq -r ".nats_password")

    sed -i "s/@nats_addr/${nats_addr}/g" ${server_dir}/config_map.yml
    sed -i "s/@nats_port/${nats_port}/g" ${server_dir}/config_map.yml
    sed -i "s/@nats_user/${nats_user}/g" ${server_dir}/config_map.yml
    sed -i "s/@nats_password/${nats_password}/g" ${server_dir}/config_map.yml
}

function modify_redis_config() {
    server_dir=$1
    row=$(jq ".redis" ${BASEDIR}/${g_mode}/config.json)
    cluster=$(echo $row | jq -r ".cluster")
    redis_port=$(echo $row | jq -r ".redis_port")
    redis_password=$(echo $row | jq -r ".redis_password")

    redis_addr=$(echo $row | jq ".redis_addr")
    addr_arr=($(echo ${redis_addr} | jq ".[]"))
    addr_str=""
    for(( i=1;i<${#addr_arr[@]};i++ )) do
        addr_str=${addr_str}${addr_arr[i]}," "
    done;
    addr_str=${addr_str}${addr_arr[0]}

    sed -i "s/@cluster/${cluster}/g" ${server_dir}/config_map.yml
    sed -i "s/@redis_addr/${addr_str}/g" ${server_dir}/config_map.yml
    sed -i "s/@redis_port/${redis_port}/g" ${server_dir}/config_map.yml
    sed -i "s/@redis_password/${redis_password}/g" ${server_dir}/config_map.yml
}

function modify_name() {
    server_dir=$1
    server_name=$2

    sed -i "s/@name/${server_name}/g" ${server_dir}/config_map.yml
    sed -i "s/@name/${server_name}/g" ${server_dir}/deployment.yml
    sed -i "s/@name/${server_name}/g" ${server_dir}/service.yml

    if ${g_production}; then
        sed -i "s/@name/${server_name}/g" ${server_dir}/ingress.yml
    fi
}

function gen_discovery() {
    yaml_dir=$1
    data_center=$2
    row=$3
    server_dir=${yaml_dir}/${data_center}/discovery

    discovery=$(parse ${row} ".discovery")
    discovery_count=$(echo ${discovery} | jq ".discovery_count")
    discovery_port=$(echo ${discovery} | jq ".discovery_port")
    node_affinity=$(echo ${discovery} | jq -r ".node_affinity")
    name=discovery-${data_center}
    image_label=$(echo ${discovery} | jq -r ".image_label")

    rm -rf ${server_dir}
    mkdir -p ${server_dir}
    cp -r ${BASEDIR}/${g_mode}/template/discovery ${g_yaml_dir}/${data_center}/

    modify_nats_config ${server_dir}

    modify_name ${server_dir} $name
    sed -i "s/@label/${image_label}/g" ${server_dir}/deployment.yml
    sed -i "s/@node_affinity/${node_affinity}/g" ${server_dir}/deployment.yml
    sed -i "s/@count/${discovery_count}/g" ${server_dir}/deployment.yml
    sed -i "s/@port/${discovery_port}/g" ${server_dir}/config_map.yml
    sed -i "s/@port/${discovery_port}/g" ${server_dir}/deployment.yml
    sed -i "s/@port/${discovery_port}/g" ${server_dir}/service.yml

    if ${g_production}; then
        sed -i "s/@port/${discovery_port}/g" ${server_dir}/ingress.yml
    fi
}

function gen_signaling() {
    yaml_dir=$1
    data_center=$2
    row=$3
    server_dir=${yaml_dir}/${data_center}/signaling

    signaling=$(parse ${row} ".signaling")
    signaling_count=$(echo ${signaling} | jq ".signaling_count")
    signaling_port=$(echo ${signaling} | jq ".signaling_port")
    signaling_pub_addr=$(echo ${signaling} | jq -r ".signaling_pub_addr")
    node_affinity=$(echo ${signaling} | jq -r ".node_affinity")
    name=signaling-${data_center}
    image_label=$(echo ${signaling} | jq -r ".image_label")

    rm -rf ${server_dir}
    mkdir -p ${server_dir}
    cp -r ${BASEDIR}/${g_mode}/template/signaling ${g_yaml_dir}/${data_center}/

    modify_nats_config ${server_dir}
    modify_redis_config ${server_dir}

    modify_name ${server_dir} $name
    sed -i "s/@label/${image_label}/g" ${server_dir}/deployment.yml
    sed -i "s/@node_affinity/${node_affinity}/g" ${server_dir}/deployment.yml
    sed -i "s/@count/${signaling_count}/g" ${server_dir}/deployment.yml
    sed -i "s/@data_center/${data_center}/g" ${server_dir}/config_map.yml
    sed -i "s/@pub_addr/${signaling_pub_addr}/g" ${server_dir}/config_map.yml
    sed -i "s/@port/${signaling_port}/g" ${server_dir}/config_map.yml
    sed -i "s/@port/${signaling_port}/g" ${server_dir}/deployment.yml
    sed -i "s/@port/${signaling_port}/g" ${server_dir}/service.yml

    if ${g_production}; then
        sed -i "s/@port/${signaling_port}/g" ${server_dir}/ingress.yml
    fi
}

function gen_relay() {
    yaml_dir=$1
    data_center=$2
    row=$3
    relay_dir=${yaml_dir}/${data_center}/relay

    name=relay-${data_center}
    network=$(parse ${row} ".relay.network")
    image_label=$(parse ${row} ".relay.image_label")

    rm -rf ${relay_dir}
    mkdir ${relay_dir}

    i=0
    for conf in $(echo ${network} | jq -r ".[] | @base64")
    do
        server_dir=${relay_dir}/${i}
        mkdir ${server_dir}
        cp ${BASEDIR}/${g_mode}/template/relay/* ${g_yaml_dir}/${data_center}/relay/${i}/

        modify_nats_config ${server_dir}

        node_label=$(parse ${conf} ".node_label")
        relay_intranet_addr=$(parse ${conf} ".relay_intranet_addr")
        relay_public_addr=$(parse ${conf} ".relay_public_addr")
        relay_intranet_port=$(parse ${conf} ".relay_intranet_port")
        relay_public_port=$(parse ${conf} ".relay_public_port")

        modify_name ${server_dir} $name-${i}

        sed -i "s/@data_center/${data_center}/g" ${server_dir}/config_map.yml
        sed -i "s/@node_label/${node_label}/g" ${server_dir}/deployment.yml
        sed -i "s/@label/${image_label}/g" ${server_dir}/deployment.yml
        sed -i "s/@relay_server_port/${relay_intranet_port}/g" ${server_dir}/config_map.yml
        sed -i "s/@relay_public_addr/${relay_public_addr}/g" ${server_dir}/config_map.yml
        sed -i "s/@relay_public_port/${relay_public_port}/g" ${server_dir}/config_map.yml
        sed -i "s/@relay_intranet_addr/${relay_intranet_addr}/g" ${server_dir}/config_map.yml
        sed -i "s/@relay_intranet_port/${relay_intranet_port}/g" ${server_dir}/config_map.yml
        sed -i "s/@relay_intranet_port/${relay_intranet_port}/g" ${server_dir}/deployment.yml
        sed -i "s/@relay_intranet_port/${relay_intranet_port}/g" ${server_dir}/service.yml

        if ${g_production}; then
            sed -i "s/@relay_intranet_port/${relay_intranet_port}/g" ${server_dir}/ingress.yml
        fi

        i=$((${i}+1))
    done
}

function gen_all() {
    yaml_dir=$1
    data_center=$2

    gen_discovery ${yaml_dir} ${data_center} $3
    gen_signaling ${yaml_dir} ${data_center} $3
    gen_relay ${yaml_dir} ${data_center} $3
}

function create_yaml() {
    yaml_dir=$1
    data_center=$2
    server=$3
    row=$4

    case ${server} in
        discovery)
            gen_discovery ${yaml_dir} ${data_center} ${row}
            ;;
        signaling)
            gen_signaling ${yaml_dir} ${data_center} ${row}
            ;;
        relay)
            gen_relay ${yaml_dir} ${data_center} ${row}
            ;;
        *)
            gen_all ${yaml_dir} ${data_center} ${row}
            ;;
    esac
}

function delete_yaml() {
    yaml_dir=$1
    data_center=$2
    server=$3

    case ${server} in
        discovery)
            rm -rf ${yaml_dir}/${data_center}/discovery
            ;;
        signaling)
            rm -rf ${yaml_dir}/${data_center}/signaling
            ;;
        relay)
            rm -rf ${yaml_dir}/${data_center}/relay
            ;;
        *)
            rm -rf ${yaml_dir}/${data_center}/
            ;;
    esac
}

function main() {
    xremote=$(jq ".xremote" ${BASEDIR}/${g_mode}/config.json)

    for row in $(echo "${xremote}" | jq -r ".[] | @base64")
    do
        data_center=$(parse ${row} ".data_center")
        echo "data_center: ${data_center}"

        if ${g_create}; then
            rm -rf ${g_yaml_dir}/${data_center}
            mkdir -p ${g_yaml_dir}/${data_center}

            create_yaml ${g_yaml_dir} ${data_center} ${g_server} ${row}
        else
            delete_yaml ${g_yaml_dir} ${data_center} ${g_server}
        fi
    done
}

main

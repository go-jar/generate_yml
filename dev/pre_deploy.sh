#!/bin/sh

BASEDIR=$(dirname "$0")
echo ${BASEDIR}

TEMP=`getopt -o aisnb:l:rh --long all,install,server,nginx,build:,label:run,help -- "$@"`
eval set -- "$TEMP"

function show_usage() {
cat <<EOF
Usage: $(basename $0) [options] ...
OPTIONS:
    -a --all
    -i --install                                   Install minikube and GUI.
    -s --server                                    Deploy nats and redis on the k8s cluster in minikube.
    -n --nginx                                     Download and configure nginx.
    -b --build [all, signaling, discovery, relay]  Build all server (signaling, relay, discovery) images.
    -l --label                                     Image Label.
    -r --run                                       Start minikube.
    -h --help                                      Show usage.
EOF
exit 0
}

g_operate="all"
g_server="all"
g_image_label="latest"

function parse_args() {
  while true
    do
        case "$1" in
            -a|--all) g_operate="all"; shift 1 ;;
            -i|--install) g_operate="install_minikube"; shift 1 ;;
            -s|--server) g_operate="deploy_nats_redis"; shift 1 ;;
            -n|--nginx) g_operate="install_nginx"; shift 1 ;;
            -b|--build) g_operate="build_image"; g_server=$2; echo ${g_server}; shift 2 ;;
            -l|--label) g_image_label=$2; shift 2 ;;
            -r|--run) g_operate="run_minikube"; shift 1 ;;
            -h|--help) show_usage; break ;;
            --) shift; break ;;
            *) show_usage; exit 1 ;;
        esac
    done
}

parse_args $@

function run_minikube() {
    minikube start \
        --listen-address=0.0.0.0 \
        --insecure-registry "10.10.0.0/16" \
        --extra-config=apiserver.service-node-port-range=1-65535
    alias kubectl="minikube kubectl --"
    source <(kubectl completion bash)
}

function install_minikube() {
    # Install minikube and start a k8s cluster in minikube.
    # Minikube is a virtual machine.
    # https://minikube.sigs.k8s.io/docs/start/
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64  /usr/local/bin/minikube
    rm minikube-linux-amd64
    run_minikube

    # Install GUI for minikube.
    # https://k8slens.dev/
    wget https://api.k8slens.dev/binaries/Lens-5.4.4-latest.20220325.1.amd64.deb
    sudo dpkg -i Lens-5.4.4-latest.20220325.1.amd64.deb
    rm Lens-5.4.4-latest.20220325.1.amd64.deb
}

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

    echo "-----------$operate $server_dir done------------"
}

function deploy_nats_redis() {
    operate_one_server apply ${BASEDIR}/install/nats
    operate_one_server apply ${BASEDIR}/install/redis
}

function install_nginx() {
    # Because the minikube VM is exposed to the host system via a host-only IP address,
    # we need nginx to proxy minikube to access minikube cluster from a remote network.
    cp -r ${BASEDIR}/install/nginx ${HOME}/
    docker run -d --name xremote_nginx --network host \
               -v ${HOME}/nginx/nginx.conf:/etc/nginx/nginx.conf nginx
}

function build_image() {
    minikube -p minikube docker-env
    eval $(minikube -p minikube docker-env)

    cur_dir="$(pwd)"
    cd ${BASEDIR}/../../
    bash release_build.sh -n -b ${g_server} -l ${g_image_label}
    cd ${cur_dir}
}

function execute_all() {
    install_minikube
    deploy_nats_redis
    install_nginx
    build_image
    lens # Open GUI
}

function main() {
    case ${g_operate} in
    all)
        execute_all
    ;;
    install_minikube)
        install_minikube
    ;;
    deploy_nats_redis)
        deploy_nats_redis
    ;;
    install_nginx)
        install_nginx
    ;;
    build_image)
        build_image
    ;;
    run_minikube)
        run_minikube
    ;;
    *)
        show_usage
    ;;
esac
}

main $@

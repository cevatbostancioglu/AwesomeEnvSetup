#!/bin/bash

set -e # stop on first error
set -x # log every step

usage () {
    echo "                               i am not sure yet                                                  "
}

do_prepare_env() {
    echo "do_prepare_env start"
    
    apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
    
    curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | \
    apt-key add -
    
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
    tee /etc/apt/sources.list.d/nvidia-docker.list
    
    apt-get update
    
    
    if ! [ -x "$(command -v docker)" ]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

        apt-key fingerprint 0EBFCD88
        
        add-apt-repository \
        "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) \
        stable"
        
        apt-get update
        
        apt-get install -y docker-ce
    fi
    
    apt-get update
    
    apt-get install -y nvidia-docker2
    pkill -SIGHUP dockerd
    
    echo "do_prepare_env done"
}

do_setup_tools()
{
    echo "do_setup_tools start"
    
    pushd ${UPSTREAM_DIR}
    
    add-apt-repository ppa:graphics-drivers/ppa -y
    apt-get update
    apt-get install ${HOST_NVIDIA_DRIVER_VER}
    
    popd
    
    echo "do_setup_tools done"
}

do_setup_nvidia_docker() {
    echo "do_setup_nvidia_docker start"
    
    docker build -t floydhub/dl-docker:gpu -f Dockerfile.gpu .

    docker run  --name ${BUILD_DOCKER_CONTAINER_NAME} -d -t -p ${BUILD_DOCKER_SSH_PORT}:22 -v $PWD:/opt:z ${BUILD_DOCKER_REF_NAME}:${BUILD_DOCKER_VERSION}

    nvidia-docker run --name ${BUILD_DOCKER_CONTAINER_NAME}-it -p ${BUILD_DOCKER_IPYTHON_PORT}:${BUILD_DOCKER_IPYTHON_PORT} \ 
            -p ${BUILD_DOCKER_TENSORBOARD_PORT}:${BUILD_DOCKER_TENSORBOARD_PORT} -p ${BUILD_DOCKER_SSH_PORT}:22 -v ${PWD}:/opt:z floydhub/dl-docker:gpu
    
    echo "do_setup_nvidia_docker done"
}

do_prepare() {
    
    do_prepare_env
    do_setup_tools
    do_setup_nvidia_docker
}

do_setup_jenkins() {
    echo "do_setup_jenkins start"
    
    wget -q -O - https://pkg.jenkins.io/debian/jenkins-ci.org.key | apt-key add -
    
    echo deb https://pkg.jenkins.io/debian-stable binary/ | tee /etc/apt/sources.list.d/jenkins.list
    
    apt-get update
    
    apt-get install jenkins
    
    systemctl start jenkins

    ufw allow 8080
    
    echo "do_setup_jenkins done"
}

do_run() {
    echo "do_run start"

    
    
    echo "do_run done"
}

########
# MAIN #
########

# Present usage.
if [ $# -eq 0 ]; then
    usage
    exit 0
fi

source build.config

[ -d $UPSTREAM_DIR ] || mkdir -p $UPSTREAM_DIR

# Process all commands.
while true ; do
    case "$1" in
        prepare)
            do_prepare
            shift
            ;;
        prepare_devops)
            do_setup_jenkins
            shift
            ;;
        run)
            do_run
            shift
            break
            ;;
        *)
            if [[ -n "$1" ]]; then
                echo "Unknown command"
                usage
            fi
            break
            ;;
    esac
done
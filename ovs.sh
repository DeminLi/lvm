#!/usr/bin/env bash

#Copyright (c) 2013 LI Demin

set -e
 
# Fail on unset var usage
set -o nounset

# Attempt to identify Linux release

DIST=Unknown
RELEASE=Unknown
CODENAME=Unknown
ARCH=`uname -m`
if [ "$ARCH" = "x86_64" ]; 
    then ARCH="amd64";
elif [ "$ARCH" = "i686" ];
    then ARCH="i386";
fi

grep Ubuntu /etc/lsb-release &> /dev/null && DIST="Ubuntu"
if [ "$DIST" = "Ubuntu" ] ; then
    install='sudo apt-get -y install'
    remove='sudo apt-get -y purge'
    pkginst='sudo dpkg -i'
    # Prereqs for this script
    if ! which lsb_release &> /dev/null; then
        $install lsb-release
    fi
    if ! which bc &> /dev/null; then
        $install bc
    fi 
fi
if which lsb_release &> /dev/null; then
    DIST=`lsb_release -is`
    RELEASE=`lsb_release -rs`
    CODENAME=`lsb_release -cs`
fi
echo "Detected Linux distribution: $DIST $RELEASE $CODENAME $ARCH"

# Kernel params

if [ "$DIST" = "Ubuntu" ]; then
    if [ "$RELEASE" = "10.04" ]; then
        KERNEL_NAME='3.0.0-15-generic'
    else
        KERNEL_NAME=`uname -r`
    fi
    KERNEL_HEADERS=linux-headers-${KERNEL_NAME}
else
    echo "Install.sh currently only supports Ubuntu and Debian Lenny i386."
    exit 1
fi

# More distribution info
DIST_LC=`echo $DIST | tr [A-Z] [a-z]` # as lower case

# Kernel Deb pkg to be removed:
KERNEL_IMAGE_OLD=linux-image-2.6.26-33-generic

DRIVERS_DIR=/lib/modules/${KERNEL_NAME}/kernel/drivers/net

OVS_RELEASE=1.9.0
OVS_BUILDSUFFIX=-ignore # was -2
OVS_SRC=~/openvswitch
OVS_TAG=v$OVS_RELEASE
OVS_BUILD=$OVS_SRC/build-$KERNEL_NAME
OVS_KMODS=($OVS_BUILD/datapath/linux/{openvswitch_mod.ko,brcompat_mod.ko})

function kernel {
    echo "Install Mininet-compatible kernel if necessary"
    sudo apt-get update
    if [ "$DIST" = "Ubuntu" ] &&  [ "$RELEASE" = "10.04" ]; then
        $install linux-image-$KERNEL_NAME
    fi
}

function kernel_clean {
    echo "Cleaning kernel..."

    # To save disk space, remove previous kernel
    if ! $remove $KERNEL_IMAGE_OLD; then
        echo $KERNEL_IMAGE_OLD not installed.
    fi

    # Also remove downloaded packages:
    rm -f ~/linux-headers-* ~/linux-image-*
}
# Install Open vSwitch
# Instructions derived from OVS INSTALL, INSTALL.OpenFlow and README files.

function ovs {
    echo "Installing Open vSwitch..."

    # Required for module build/dkms install
    $install $KERNEL_HEADERS

    ovspresent=0

    # Otherwise try distribution's OVS packages
    if [ "$DIST" = "Ubuntu" ] && [ `expr $RELEASE '>=' 11.10` = 1 ]; then
        if ! dpkg --get-selections | grep openvswitch-datapath; then
            # If you've already installed a datapath, assume you
            # know what you're doing and don't need dkms datapath.
            # Otherwise, install it.
            $install openvswitch-datapath-dkms
        fi
	if $install openvswitch-switch openvswitch-controller; then
            echo "Ignoring error installing openvswitch-controller"
        fi
        ovspresent=1
    fi

    if [ $ovspresent = 1 ]; then
        echo "Done (hopefully) installing packages"
        cd ~
        return
    fi

    # Otherwise attempt to install from source

    $install pkg-config gcc make python-dev libssl-dev libtool git

    # Install OVS from release
    cd ~/
    sudo git clone git://openvswitch.org/openvswitch $OVS_SRC
    cd $OVS_SRC
    sudo git checkout $OVS_TAG
    ./boot.sh
    BUILDDIR=/lib/modules/${KERNEL_NAME}/build
    if [ ! -e $BUILDDIR ]; then
        echo "Creating build sdirectory $BUILDDIR"
        sudo mkdir -p $BUILDDIR
    fi
    opts="--with-linux=$BUILDDIR"
    mkdir -p $OVS_BUILD
    cd $OVS_BUILD
    ../configure $opts
    make
    sudo make install

    modprobe
}

function ovs_start {
	if [ "$DIST" = "Ubuntu" ]; then
		sudo ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock --remote=db:Open_vSwitch,manager_options --private-key=db:SSL,private_key  --certificate=db:SSL,certificate --bootstrap-ca-cert=db:SSL,ca_cert  --pidfile --detach
              sudo service openvswitch-switch restart
       fi
}

function ovs_stop {
	if [ "$DIST" = "Ubuntu" ]; then
		sudo service openvswitch-switch stop
	fi	
}

function remove_ovs {
    pkgs=`dpkg --get-selections | grep openvswitch | awk '{ print $1;}'`
    echo "Removing existing Open vSwitch packages:"
    echo $pkgs
    if ! $remove $pkgs; then
        echo "Not all packages removed correctly"
    fi
    # For some reason this doesn't happen
    if scripts=`ls /etc/init.d/*openvswitch* 2>/dev/null`; then
        echo $scripts
        for s in $scripts; do
            s=$(basename $s)
            echo SCRIPT $s
            sudo service $s stop
            sudo rm -f /etc/init.d/$s
            sudo update-rc.d -f $s remove
        done
    fi
    echo "Done removing OVS"
}

function modprobe {
    echo "Setting up modprobe for OVS kmod..."

    sudo cp $OVS_KMODS $DRIVERS_DIR
    sudo depmod -a ${KERNEL_NAME}
}

# Restore disk space and remove sensitive files before shipping a VM.
function vm_clean {
    echo "Cleaning VM..."
    sudo apt-get clean
    sudo rm -rf /tmp/*
    sudo rm -rf openvswitch*.tar.gz

    # Remove sensistive files
    history -c  # note this won't work if you have multiple bash sessions
    rm -f ~/.bash_history  # need to clear in memory and remove on disk
    rm -f ~/.ssh/id_rsa* ~/.ssh/known_hosts
    sudo rm -f ~/.ssh/authorized_keys*

    # Clear optional dev script for SSH keychain load on boot
    rm -f ~/.bash_profile
}

function all {
    echo "Running all commands..."
    kernel
    ovs
    ovs_start
    echo "Please reboot, then run "install.sh -c" to remove unneeded packages."
    echo "Enjoy Open vSwitch!"
}

function usage {
    printf 'Usage: %s [-acdfhkmntvxy]\n\n' $(basename $0) >&2
    
    printf 'This install script attempts to install useful packages\n' >&2
    printf 'It should (hopefully) work on Ubuntu 10.04, 11.10\n' >&2
    printf 'installing one thing at a time, and looking at the \n' >&2
    printf 'specific installation function in this script.\n\n' >&2

    printf 'options:\n' >&2
    printf -- ' -a: (default) install (A)ll packages - good luck!\n' >&2
    printf -- ' -c: (C)lean up after kernel install\n' >&2
    printf -- ' -d: (D)elete some sensitive files from a VM image\n' >&2    
    printf -- ' -h: print this (H)elp message\n' >&2
    printf -- ' -k: install new (K)ernel\n' >&2
    printf -- ' -l: (L)auch Open vSwitch process and ovs server' >&2
    printf -- ' -m: install Open vSwitch kernel (M)odule from source dir\n' >&2
    printf -- ' -r: remove existing Open vSwitch packages\n' >&2
    printf -- ' -v: install open (V)switch\n' >&2
    printf -- ' -s: (S)hutdown Open vSwitch' >&2
    
    exit 2
}

if [ $# -eq 0 ]
then
    all
else
    while getopts 'acdhklmrsv' OPTION
    do
      case $OPTION in
      a)    all;;
      c)    kernel_clean;;
      d)    vm_clean;;
      h)    usage;;
      k)    kernel;;
      l)    ovs_start;;
      m)    modprobe;;
      r)    remove_ovs;;
      s)    ovs_stop;;
      v)    ovs;;
      ?)    usage;;
      esac
    done
    shift $(($OPTIND - 1))
fi

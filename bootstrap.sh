#!/bin/bash
#
#
# Bootstrap Ansible on a host. After this script is run, you can run
# Ansible playbooks to finalize the host setup
#
# This script will work and has been tested on Linux
#    TODO: Test on OS X and FreeBSD.
#
# run with sudo -H
#    $ sudo -H bootstrap.sh
#
#  Author: Brian A. Onn (brian.a.onn@gmail.com) 
#    Date: Sat Apr 29 16:30:15 UTC 2017
# License: MIT

trap cleanup EXIT SIGHUP SIGINT SIGQUIT SIGTERM 
trapfiles=""
cleanup () {
  rm -rf ${trapfiles}
}

addtrapfile () {
  trapfile="${trapfile} $1"
}

#########################################
# pathname tilde expansion
# supports ~ ~/path and ~user only
# ~+ ~- and digits are not supported and
# don't make sense in a script anyways
#########################################
expandpath () {
  local path="$1"
  local homedir expath user rest 
  case "${path}" in
    '~') expath="${HOME}" ;;
    '~'/*) expath="${HOME}/${path##'~/'}" ;;
    '~'*) user=${path%%/*}; rest=${path##$user}; user=${user##'~'}
          if [ -x /usr/bin/dscacheutil ]; then    ## OS X
            set 1 $(dscacheutil -q user -a name "$user" | grep -e '^dir:')
            homedir="$3"
          else
            IFS=: set 1 $(getent passwd "$user")  ## Linux
            homedir="$7"
          fi
          [ -z "${homedir}" ] && expath="${path}" || expath="${homedir}$rest"
          ;;
    *) expath="${path}" ;;
  esac
  echo "${expath}"
}


#########################################
# tempdir, logging and stderr redirection
#########################################

# prefer TMP, use TEMP if TMP is not set, finally use /tmp as a default
# also do ~ expansion on TMP and TEMP
tmp="$(expandpath "${TMP:=${TEMP:-/tmp}}")"

tmplog=$(mktemp "${tmp}/ansible-bootstrap.XXXXX.log")
addtrapfile "${tmplog}"
echolog() {
  echo "$*" >> $tmplog
  return 0
}

# close stdout 
#exec 1<&-
# close stderr
#exec 2<&-

# re-open stdout to the tty and logfile, 
# and send stderr only to the logfile
#exec 3>&1 &>${tmplog} 1> >(tee >(cat >&3))
exec 2>>${tmplog} 1> >(tee -a ${tmplog} >&1)

#########################################
# local vars and utility functions here
#########################################

bold="$(tput bold)"
norm="$(tput cnorm;tput sgr0)"
red="$(tput setaf 1)"
grn="$(tput setaf 2)"

redmsg () {
    echo "    $bold$red*** $1 ***$norm"
}

grnmsg () {
    echo "    $bold$grn*** $1 ***$norm"
}

is_installed() {
  type $1 2>/dev/null >/dev/null && return 0 || return 1
}

shacmd="echo no"
is_installed shasum && shacmd="shasum -p -a 256"
is_installed sha256 && shacmd=sha256
is_installed sha256sum && shacmd=sha256sum


srcpkgs="ansible sshpass"             # src pkgs are built from source on OS X
binpkgs="git python curl"               # linux will apt-get all these +src
pippkgs="paramiko PyYAML jinja Sphinx pycrypto cryptography"  # python packages installed via pip

system="$(uname -s|tr 'A-Z' 'a-z')"

getpip () {
  url="https://bootstrap.pypa.io/get-pip.py"
  getpip=$(mktemp /tmp/get-pip.XXXXX.py)
  sha256="19dae841a150c86e2a09d475b5eb0602861f2a5b7761ec268049a662dbd2bd0c"
  echo "Downloading get-pip.py from '$url'"
  curl -m 300 --retry 3 -o "${getpip}" "${url}" >> $tmplog 2>&1
  dlsha256=$(${shacmd} ${getpip} | cut -f1 -d' ')
  if [ "${sha256}" = "${dlsha256}" ]; then
    echo "SHA256 sum is correct: $sha256"
    echo "Running get-pip.py to install pip for python"
    python "${getpip}"
    echo "Running pip updater"
    pip install -U pip
    return 0
  else
    redmsg "The get-pip.py command at:"
    redmsg "${url}"
    redmsg "does not match the known sha256 checksum"
    return 1
  fi
}

if [ $(id -u) != 0 ]; then
  redmsg "Sorry, this script must run as root"
  redmsg "Use 'sudo -H' to bootstrap ansible"
  exit 255
fi

echo "Platform: ${system}"

case ${system} in
  linux)
    apt-add-repository -y ppa:ansible/ansible
    apt-get -qq -y update
    for pkg in ${binpkgs} ${srcpkgs}; do
      if is_installed $pkg; then  ## assumes the package name is also the binary name
        echo $pkg is already installed
      else
        echo -n "Installing $bold$pkg$norm ... "
        apt-get -qy install $pkg 2>/dev/null >/dev/null 
        echo "[OK]"
      fi
    done
    ;;

  darwin)
    echo "OS X support is incomplete and untested"

    #install packages which have brew formulas
    brew install ${binpkgs}

    # on OSX we build ansible and sshpass from src
    echo "Building Ansible from source" 
    # requires: xcode, terminal and command-line utilites be already installed
    # get ansible source here and build it

    repo=$(mktemp -d /tmp/repo.XXXXX)
    addtrapfile "${repo}"
    git clone git://github.com/ansible/ansible.git "${repo}"
    ( cd ${repo} && make install )

    echo "Building sshpass"
    # sshpass="https://git.io/sshpass.rb"
    sshpass="file://sshpass.rb"
    brew install ${sshpass}
    ;;

  bsd)
    echo "I don't know bsd yet."
    ;;
esac

# do the pip install
getpip && echo "Running 'pip install ${pippkgs}'" && pip install ${pippkgs}

if test $? != 0; then
  e1="Python package manager pip failed to install"
  e2="Ansible will not work without python packages"
  err=1
  st="Ansible is not installed"
else
  err=0
  e1= e2= 
  st="Ansible is installed"
fi

if [ ${err} = 1 ]; then
  echo
  redmsg "${e1}"
  redmsg "${e2}"
  echo
  redmsg "${st}"
else
  echo
  grnmsg "${st}"
fi

logfile="${tmpdir}/ansible-bootstrap-$(date -u '+%Y%m%d%H%M%S').log"
mv ${tmplog} ${logfile}
echo
echo Logfile: ${logfile}
echo

#########
# Step 2 -- Create the ansible user and home dir
#########

exit 0

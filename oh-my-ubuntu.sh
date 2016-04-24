#!/bin/bash
# author:tracyone,tracyone@live.cn
# ./oh-my-ubuntu.sh <path of ini file>
# Core theory:git can read or write standard ini file easily.
# For example:
# read :git config section.key
# write :git config section.key value 

shopt -s expand_aliases
read -p "Please input $(whoami)'s passwd: " mypasswd
alias sudo="echo "${mypasswd}" | sudo -S"

LOG_FILE="omu.log"
# 设置分隔符为换行符号
OLD_IFS="$IFS" 
IFS=$'\x0A' 
rm -f ${LOG_FILE}
# prompt before every install
PROMPT=1
ROOT_DIR=$(pwd)

SRC_DIR=${HOME}/Work/Source
mkdir -p ${SRC_DIR}


# {{{ function definition

# $1:software list to install..
function AptSingleInstall()
{
    IFS=" "
    for i in $1
    do
        sudo apt-get install $i --allow-unauthenticated -y || echo -e "apt-get install failed : $i\n" >> ${LOG_FILE}
    done
    IFS=${OLD_IFS}
}

function AptInstall()
{
    ans=""
    if [[  $1 =~  ^[\ ]*$ ]]; then
        return 3
    fi
    if [[  PROMPT -eq 1  ]]; then
        read -n1 -p "Install $1 ?(y/n)" ans
    fi
	if [[ $ans =~ [Yy] || PROMPT -eq 0 ]]; then
        sudo apt-get install $1 --allow-unauthenticated -y || AptSingleInstall "$1"
        sleep 1
	else
		echo -e  "\n\nAbort install\n"
	fi
}

# $1:section.key
function AptAddRepo()
{
    ans=""
    if [[  PROMPT -eq 1  ]]; then
        read -n1 -p "Adding ppa $i? (y/n) " ans
    fi
    if [[ $ans =~ [Yy] || PROMPT -eq 0 ]]; then
        sudo add-apt-repository -y $1 || echo -e "apt-add-repository failed : $1\n" >> ${LOG_FILE}
        sleep 1
    else
        echo -e  "\n\nAbort install\n"
    fi
}

function DebInstall()
{
    local filename="tmp$(date +%Y%m%d%H%M%S).deb"
    ans=""
    if [[  PROMPT -eq 1  ]]; then
        read -n1 -p "Wget $i? (y/n) " ans
    fi
    if [[ $ans =~ [Yy] || PROMPT -eq 0 ]]; then
        wget -c $1 -O ${filename}  || echo -e "Wget $1 failed\n" >> ${LOG_FILE}
        sudo dpkg -i ${filename} || ( sudo apt-get -f install -y; sudo dpkg -i ${filename}  \
            || echo -e "dpkg install ${filename}  form $1 failed\n" >> ${LOG_FILE} )
    else
        echo -e  "\n\nAbort install\n"
    fi
}

function BuildSrc()
{
    IFS=","
    local -i count=0
    local proj_str=""
    if [[  PROMPT -eq 1  ]]; then
        read -n1 -p "Build source $i? (y/n) " ans
    fi
    if [[ $ans =~ [Yy] || PROMPT -eq 0 ]]; then
        for i in $1; do
            echo -e "$i\n"
            case ${count} in
                0 )
                    IFS=${OLD_IFS}
                    proj_dir=${SRC_DIR}/$(basename $i .git)
                    if [[ ! -d ${proj_dir}  ]]; then
                        git clone $i ${proj_dir}/ || echo -e "git clone $i failed\n" >> ${LOG_FILE}
                    else
                        echo -e "Update source $(basename $i .git) ...\n"
                        cd  ${proj_dir}
                        git checkout -- .
                        git pull || echo -e "Update source $(basename $i .git) failed\n" >> ${LOG_FILE}
                    fi
                    IFS=","
                    ;;
                1 )
                    AptInstall $i
                    ;;
                2 )
                    bash -c "cd ${proj_dir} && $i"
                    ;;
                *)
                    echo -e "Wrong ini format in build section\n" >> ${LOG_FILE}
                    ;;
            esac
            let "count+=1"
        done
    else
        echo -e  "\n\nAbort install\n"
    fi
    cd ${ROOT_DIR}
    IFS=$'\x0A' 
}

# }}}

if [[ $# -eq 1 ]]; then
	if [[ ! -f $1 ]]; then
		echo -e "\nFile $1 not exist!\n"
		exit 3
	fi
	GIT_CONFIG="$1"
else
	echo -e "\nWrong usage!!\n"
	echo -e "\n./oh-my-ubuntu.sh <path of ini file>\n"
	exit 3
fi
echo -e "\nUse Config file: ${GIT_CONFIG}\n"
export GIT_CONFIG

which git > /dev/null
if [[ $? -ne 0 ]]; then
    echo -e "Install git ..."
	sudo apt-get update
	sudo apt-get install git -y
	if [[ $? -ne 0 ]]; then
		echo -e "\nInstall git failed\n"
		exit 3
	fi
fi

read -n1 -p "Install all software Without prompting?(y/n)" ans
if [[  ${ans} =~ [yY] ]]; then
    PROMPT=0
fi

ppa_list=$(git config --get-all repo.ppa)
echo -e "\n\nadding ppa ...\n"
for i in ${ppa_list}; do
    if [[ $i != "" ]]; then
        AptAddRepo $i
    fi
done

sudo dpkg --add-architecture i386
echo -e "\n\nUpdate source ...\n"
sudo apt-get update
echo -e "\n\nUpgrade ...\n"
sudo apt-get upgrade -y

echo -e "\n\nApt install ...\n"
apt_list=$(git config --get-all apt.packages)
for i in ${apt_list}; do
    if [[ $i != "" ]]; then
        AptInstall $i
    fi
done

echo -e "\n\nDeb install ...\n"
deb_list=$(git config --get-all deb.url)
for i in ${deb_list}; do
    if [[ $i != "" ]]; then
        DebInstall $i
    fi
done

src_list=$(git config --get-all build.gitsrc)
echo -e "\n\nInstall software from source ...\n"
for i in ${src_list}; do
    if [[ $i != "" ]]; then
        BuildSrc $i
    fi
done

echo -e "\nAll done!!Clean ...\n"
sudo apt-get autoremove -y
sudo apt-get autoclean
sudo apt-get clean

# vim: set ft=sh fdm=marker foldlevel=0 foldmarker&: 

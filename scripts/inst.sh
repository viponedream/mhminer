#!/bin/bash

[[ $(id -u) != 0 ]] && echo -e "请使用root权限运行安装脚本， 通过sudo su root切换再来运行" && exit 1



cmd="apt-get"
if [[ $(command -v apt-get) || $(command -v yum) ]] && [[ $(command -v systemctl) ]]; then
    if [[ $(command -v yum) ]]; then
        cmd="yum"
    fi
else
    echo "目前只支持ubuntu 20" && exit 1
fi


start() {
    if netstat -anptl | grep -q "mhminer"; then
        echo -e "mhminer 已启动,请勿重复启动" && exit 1
    fi
    systemctl start mhminer 
    echo "mhminer 启动"
}

restart() {
    systemctl restart mhminer >> /dev/null
    echo "mhminer 重新启动" 
}

stop() {
    systemctl stop mhminer >> /dev/null
    echo "mhminer 停止" 
}


check_done() {
    if netstat -antpl | grep -q "12510"; then
        echo -e "\n\n" 
        echo -e "--------------------------------------------------------------------"
        echo -e "\n" 
        echo -e "安装成功， mh_proxy  已经在运行......" 
        echo -e "\n" 
        echo -e "---------------------------------------------------------------------"
        echo -e "\n" 
    else        
        echo -e "\n\n" 
        echo "安装不成功，请重启后重新安装"   
        echo "出现各种选择，请按 确认/OK"
        echo -e "\n\n" 
    fi      
}


change_limit(){
    num="n"
    if [ $(grep -c "root soft nofile" /etc/security/limits.conf) -eq '0' ]; then
        echo "root soft nofile 65535" >>/etc/security/limits.conf
        num="y"
    fi

    if [[ "$num" = "y" ]]; then
        echo "连接数限制已修改为 65535, 重启服务器后生效"
    else
        echo -n "当前连接数限制："
        ulimit -n
    fi
}

check_limit(){
    echo -n "当前连接数限制："
    ulimit -n
}

uninstall() {
  
        echo "正在卸载mhminer......"
        systemctl stop mhminer  &
        systemctl disable mhminer  >> /dev/null
        rm -rf /root/mhminer
        echo "卸载完成"
}


install_common() {
    ufw disable
    $cmd update -y
    $cmd install wget -y
    $cmd install net-tools -y
}


install() {
    
    install_common
    


    if [[ ! -d /root/mhminer ]]; then
         mkdir /root/mhminer
    fi


    cd /root/mhminer

    rm /lib/systemd/system/mhminer.service
    
    config_path=/root/mhminer/config.yml

    

    clear
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo "请选择要安装的版本"

    echo "  1, 矿池中转(可抽水)  - ubuntu20 - 最新版"
    echo "  0, 本地加密 - hiveos - win的话可直接下载"
    

    read -p "$(echo -e "请输入[1-?]：")" choose
    case $choose in


    1)
        wget  --no-check-certificate https://raw.githubusercontent.com/minerhomevip/mhminer/main/lastest/mhminer  -O  /root/mhminer/mhminer

        if test ! -f "$config_path"; then
            wget  --no-check-certificate https://raw.githubusercontent.com/minerhomevip/mhminer/main/lastest/config.yml  -O  /root/mhminer/config.yml
        fi
        ;;

   0)
        wget  --no-check-certificate  https://ghproxy.com/https://raw.githubusercontent.com/minerhomevip/mhminer/main/mhtunnel/mhtunnel  -O  /root/mhminer/mhminer

        if test ! -f "$config_path"; then
             wget  --no-check-certificate https://ghproxy.com/https://raw.githubusercontent.com/minerhomevip/mhminer/main/mhtunnel/config.yml  -O  /root/mhminer/config.yml
        fi

        ;;


    *)
        echo "请输入正确的数字"
        ;;
    esac

# 通用
    wget  --no-check-certificate https://raw.githubusercontent.com/minerhomevip/mhminer/main/common/sysctl.conf    -O   /etc/sysctl.conf
    wget  --no-check-certificate https://raw.githubusercontent.com/minerhomevip/mhminer/main/common/security/limits.conf    -O   /etc/security/limits.conf

    wget  --no-check-certificate https://raw.githubusercontent.com/minerhomevip/mhminer/main/scripts/mhminer.service    -O  /lib/systemd/system/mhminer.service  
    wget  --no-check-certificate https://raw.githubusercontent.com/minerhomevip/mhminer/main/scripts/mhminer.sh    -O   /root/mhminer/mhminer.sh 


    systemctl unmask  mhminer
    systemctl disable mhminer

    chmod +x /root/mhminer/*
    systemctl daemon-reload
    systemctl enable mhminer  
    systemctl restart mhminer  &    
    clear
    echo -e "\n" 
    echo -e "\n" 
    echo -e "安装完成, 根据实际情况修改 /root/mhminer/config.yml文件" 
    echo -e "然后手工重启\n" 
    echo -e "\n" 
    # check_done
}





inst_devfee() {
    
    install_common
    


    if [[ ! -d /root/mhminer ]]; then
         mkdir /root/mhminer
    fi


    cd /root/mhminer

    config_path=/root/mhminer/config.yml

    

    clear
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo "请选择要安装的版本"

    echo "  1, 矿池中转(可抽水)  - ubuntu20 - 最新版"
    

    read -p "$(echo -e "请输入[1-?]：")" choose
    case $choose in


    1)
        wget  --no-check-certificate https://raw.githubusercontent.com/minerhomevip/mhminer/main/lastest/mhminer  -O  /root/mhminer/mhminer

        if test ! -f "$config_path"; then
            wget  --no-check-certificate https://raw.githubusercontent.com/minerhomevip/mhminer/main/lastest/config.yml  -O  /root/mhminer/config.yml
        fi
        ;;


    *)
        echo "请输入正确的数字"
        ;;
    esac

# 通用
    wget  --no-check-certificate https://raw.githubusercontent.com/minerhomevip/mhminer/main/common/sysctl.conf    -O   /etc/sysctl.conf
    wget  --no-check-certificate https://raw.githubusercontent.com/minerhomevip/mhminer/main/common/security/limits.conf    -O   /etc/security/limits.conf

    wget  --no-check-certificate https://raw.githubusercontent.com/minerhomevip/mhminer/main/scripts/mhminer.service    -O  /lib/systemd/system/mhminer.service  
    wget  --no-check-certificate https://raw.githubusercontent.com/minerhomevip/mhminer/main/scripts/mhminer.sh    -O   /root/mhminer/mhminer.sh 


    systemctl unmask mhminer
    systemctl disable mhminer

    chmod +x /root/mhminer/*
    systemctl daemon-reload
    systemctl enable mhminer  
    systemctl restart mhminer  &    
    clear
    echo -e "\n" 
    echo -e "\n" 
    echo -e "安装完成, 根据实际情况修改 /root/mhminer/config.yml文件" 
    echo -e "然后手工重启\n" 
    echo -e "\n" 
    # check_done
}






inst_tunnel() {
    
    install_common
    


    if [[ ! -d /root/mhminer ]]; then
         mkdir /root/mhminer
    fi


    cd /root/mhminer

    config_path=/root/mhminer/config.yml

    

    clear
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo "请选择要安装的版本"


    echo "  0, 本地加密 - hiveos - win的话可直接下载"
    

    read -p "$(echo -e "请输入[1-?]：")" choose
    case $choose in

   0)
        wget  --no-check-certificate  https://down.minerhome.org/mhminer/mhtunnel/mhtunnel  -O  /root/mhminer/mhminer

        if test ! -f "$config_path"; then
             wget  --no-check-certificate https://down.minerhome.org/mhminer/mhtunnel/config.yml  -O  /root/mhminer/config.yml
        fi

        ;;


    *)
        echo "请输入正确的数字"
        ;;
    esac

# 通用
    wget  --no-check-certificate  https://down.minerhome.org/mhminer/common/sysctl.conf    -O   /etc/sysctl.conf
    wget  --no-check-certificate  https://down.minerhome.org/mhminer/common/security/limits.conf    -O   /etc/security/limits.conf

    wget  --no-check-certificate https://down.minerhome.org/mhminer/scripts/mhminer.service    -O  /lib/systemd/system/mhminer.service  
    wget  --no-check-certificate https://down.minerhome.org/mhminer/scripts/mhminer.sh    -O   /root/mhminer/mhminer.sh 



    chmod +x /root/mhminer/*
    systemctl daemon-reload
    systemctl enable mhminer  >> /dev/null
    systemctl restart mhminer  &    
    clear
    echo -e "\n" 
    echo -e "\n" 
    echo -e "安装完成, 根据实际情况修改 /root/mhminer/config.yml文件" 
    echo -e "然后手工重启\n" 
    echo -e "\n" 
    # check_done
}








install_cn() {
    
    install_common
    


    if [[ ! -d /root/mhminer ]]; then
         mkdir /root/mhminer
    fi


    cd /root/mhminer

    config_path=/root/mhminer/config.yml

    

    clear
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo "请选择要安装的版本"


    echo "  1, 矿池中转(可抽水)  - ubuntu20 - 最新版"
    echo "  0, 本地加密 - hiveos - win的话可直接下载"
    

    read -p "$(echo -e "请输入[1-?]：")" choose
    case $choose in


    1)
        wget  --no-check-certificate  https://down.minerhome.org/mhminer/bin/lastest/mhminer  -O  /root/mhminer/mhminer

        if test ! -f "$config_path"; then
            wget  --no-check-certificate https://down.minerhome.org/mhminer/bin/lastest/config.yml  -O  /root/mhminer/config.yml
        fi
        ;;


   0)
        wget  --no-check-certificate  https://down.minerhome.org/mhminer/mhtunnel/mhtunnel  -O  /root/mhminer/mhminer

        if test ! -f "$config_path"; then
             wget  --no-check-certificate https://down.minerhome.org/mhminer/mhtunnel/config.yml  -O  /root/mhminer/config.yml
        fi

        ;;


    *)
        echo "请输入正确的数字"
        ;;
    esac

# 通用
    wget  --no-check-certificate  https://down.minerhome.org/mhminer/common/sysctl.conf    -O   /etc/sysctl.conf
    wget  --no-check-certificate  https://down.minerhome.org/mhminer/common/security/limits.conf    -O   /etc/security/limits.conf

    wget  --no-check-certificate https://down.minerhome.org/mhminer/scripts/mhminer.service    -O  /lib/systemd/system/mhminer.service  
    wget  --no-check-certificate https://down.minerhome.org/mhminer/scripts/mhminer.sh    -O   /root/mhminer/mhminer.sh 



    chmod +x /root/mhminer/*
    systemctl daemon-reload
    systemctl enable mhminer  >> /dev/null
    systemctl restart mhminer  &    
    clear
    echo -e "\n" 
    echo -e "\n" 
    echo -e "安装完成, 根据实际情况修改 /root/mhminer/config.yml文件" 
    echo -e "然后手工重启\n" 
    echo -e "\n" 
    # check_done
}





setup() {

    clear
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 
    echo -e "\n" 

    if [[ ! -d /root/mhminer ]]; then
        echo
        echo -e "请先安装再来设置"
        exit 1
    fi

    cd /root/mh_proxy
    wget  --no-check-certificate  https://raw.githubusercontent.com/minerhomevip/mh_tunnel/master/scripts/server/server_setup   -O /root/mh_proxy/server_setup
    chmod +x /root/mh_proxy/*
    clear
    ./server_setup
}



  
clear
echo -e "\n" 
echo -e "\n" 
echo -e "\n" 
echo -e "\n" 
echo -e "\n" 
echo -e "\n" 
echo -e "\n" 
echo -e "\n" 
echo "================================================================================"
echo "minerhome proxy 中转抽水软件 | 本地加密 一键安装工具 - 矿工之家 https://minerhome.org"
echo "如果安装不成功，则重启服务器后重新安装"
echo "出现各种选择，请按 确认/OK"
echo "  1、安装矿池中转(默认安装到/root/mhminer) - 安装完记得重启服务器 - 软件开机会自动启动，后台守护运行"
echo "  2、安装本地加密隧道 (默认安装到/root/mhminer) - hiveos"
echo "  3、卸载 - 卸载完记得重启服务器"
echo "  0、重启服务器"
echo "================================================================================"
read -p "$(echo -e "请选择[1-?]：")" choose
case $choose in
1)
    inst_devfee
    ;;
2)
    inst_tunnel
    ;;
3)
    uninstall
    ;;
0)
    reboot
    ;;
*)
    echo "输入错误请重新输入！"
    ;;
esac
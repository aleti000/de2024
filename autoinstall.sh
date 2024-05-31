#!/bin/bash
nbr=5 # количество мостов на этом стенде
ens18=/etc/net/ifaces/ens18/ipv4address
ens18_gw=/etc/net/ifaces/ens18/ipv4route
ens18_dns=/etc/net/ifaces/ens18/resolv.conf
ens19=/etc/net/ifaces/ens19
hostname=/etc/hostname
#HQ-R
hq_r_name=$(grep hq_r_name= ./info | sed 's/.*hq_r_name=//')
hq_r_isp=$(grep hq_r_isp= ./info | sed 's/.*hq_r_isp=//')
hq_r_hq_srv=$(grep hq_r_hq_srv= ./info | sed 's/.*hq_r_hq_srv=//')
hq_r_gw=$(grep hq_r_gw= ./info | sed 's/.*hq_r_gw=//')
hq_r_dns=$(grep hq_r_dns= ./info | sed 's/.*hq_r_dns=//')
#BR-R
br_r_name=$(grep br_r_name= ./info | sed 's/.*br_r_name=//')
br_r_isp=$(grep br_r_isp= ./info | sed 's/.*br_r_isp=//')
br_r_br_srv=$(grep br_r_br_srv= ./info | sed 's/.*br_r_br_srv=//')
br_r_gw=$(grep br_r_gw= ./info | sed 's/.*br_r_gw=//')
br_r_dns=$(grep br_r_dns= ./info | sed 's/.*br_r_dns=//')
#HQ-SRV
hq_srv_name=$(grep hq_srv_name= ./info | sed 's/.*hq_srv_name=//')
hq_srv=$(grep hq_srv= ./info | sed 's/.*hq_srv=//')
hq_srv_gw=$(grep hq_srv_gw= ./info | sed 's/.*hq_srv_gw=//')
hq_srv_dns=$(grep hq_srv_dns= ./info | sed 's/.*hq_srv_dns=//')
#BR-SRV
br_srv_name=$(grep br_srv_name= ./info | sed 's/.*br_srv_name=//')
br_srv=$(grep br_srv= ./info | sed 's/.*br_srv=//')
br_srv_gw=$(grep br_srv_gw= ./info | sed 's/.*br_srv_gw=//')
br_srv_dns=$(grep br_srv_dns= ./info | sed 's/.*br_srv_dns=//')

cli_name=$(grep cli_name= ./info | sed 's/.*cli_name=//')
cli=$(grep cli= ./info | sed 's/.*cli=//')

function download_template { #Загрузка шаблонов машин CLI и SRV
    echo "Установка программного обеспечения, ожидайте"
    {
        apt update;
        apt-get install python3-pip python3-venv expect -y;
        python3 -m venv myenv;
        source myenv/bin/activate;
        pip3 install wldhx.yadisk-direct;
    }&>/dev/null
    echo -e "\033[32m DONE \033[0m" 
    echo "Загрузка образа сервера"
    curl -L $(yadisk-direct https://disk.yandex.ru/d/jpt_XrxLm04HYA) -o vzdump-qemu-100-2024_03_17-20_54_28.vma.gz
    echo -e "\033[32m DONE \033[0m" 
    echo "Настройка шаблона сервера"
    {
        mv vzdump-qemu-100-2024_03_17-20_54_28.vma.gz /var/lib/vz/dump/
        qmrestore local:backup/vzdump-qemu-100-2024_03_17-20_54_28.vma.gz $srv
        rm /var/lib/vz/dump/vzdump-qemu-100-2024_03_17-20_54_28.vma.gz
        qm template $srv
    }&>/dev/null
    echo -e "\033[32m DONE \033[0m" 
    echo "Загрузка образа клиента"
    # shellcheck disable=SC2046
    curl -L $(yadisk-direct https://disk.yandex.ru/d/1-3wMk1oy60_BA) -o vzdump-qemu-100-2024_03_24-13_16_07.vma.gz
    echo -e "\033[32m DONE \033[0m" 
    echo "Настройка шаблона клиента"
    {
        mv vzdump-qemu-100-2024_03_24-13_16_07.vma.gz /var/lib/vz/dump/
        qmrestore local:backup/vzdump-qemu-100-2024_03_24-13_16_07.vma.gz $cli
        rm /var/lib/vz/dump/vzdump-qemu-100-2024_03_24-13_16_07.vma.gz
        qm template $cli
    }&>/dev/null
    echo -e "\033[32m DONE \033[0m"
    echo -e "\033[32m Шаблоны виртуальных машин настроены \033[0m"
}

function configure_network { #Настройка сетевых адаптеров для стенда
    echo "Создание сетевых устройств Proxmox"
    {
        for (( br=$(($first_isp + 10 * $i)); br <= $(($first_isp + 10 * $i + 5)); br++ ))
        do
            echo >> "/etc/network/interfaces"
            echo "auto vmbr$br" >> "/etc/network/interfaces"
            echo "iface vmbr$br inet manual" >> "/etc/network/interfaces"
            echo "	bridge-ports none" >> "/etc/network/interfaces"
            echo "	bridge-stp off" >> "/etc/network/interfaces"
            echo "	bridge-fd 0" >> "/etc/network/interfaces" 
            echo >> "/etc/network/interfaces"
            echo "Мост vmbr$br создан";
        done
    }&>/dev/null
     echo -e "\033[32m DONE \033[0m" 
}

function deploy_workplaces { #Цикл для развертывания множества стендов
    for (( i=1; i <= $workplace; i++ ))
    do
        configure_network
        echo "Перезагрузка сетевых параметров"
        sleep 1
        systemctl restart networking
        echo -e "\033[32m DONE \033[0m"
        deploy_workplace
    done
}

function deploy_workplace { #Развертка стенда
     echo "Создание машин для рабочего места $i из шаблонов"
    {   
        nvm=$(($first_isp + 10 * $i))
        nvm1=$(($first_isp + 10 * $i + 1))
        nvm2=$(($first_isp + 10 * $i + 2))
        nvm3=$(($first_isp + 10 * $i + 3))
        nvm4=$(($first_isp + 10 * $i + 4))
        nvm5=$(($first_isp + 10 * $i + 5))
        br1=vmbr$(($nvm))
        br2=vmbr$(($nvm + 1))
        br3=vmbr$(($nvm + 2))
        br4=vmbr$(($nvm + 3))
        br5=vmbr$(($nvm + 4))
        #Клонирование шаблонов
        qm clone $srv $nvm --name "ISP"                  #создается СВЯЗАННЫЙ клон, если хотите создать не связанный добавьте ключ --full
        qm clone $srv $nvm1 --name "HQ-R"                #создается СВЯЗАННЫЙ клон, если хотите создать не связанный добавьте ключ --full
        qm clone $srv $nvm2 --name "BR-R"                #создается СВЯЗАННЫЙ клон, если хотите создать не связанный добавьте ключ --full
        qm clone $srv $nvm3 --name "HQ-SRV"              #создается СВЯЗАННЫЙ клон, если хотите создать не связанный добавьте ключ --full
        qm clone $srv $nvm4 --name "BR-SRV"              #создается СВЯЗАННЫЙ клон, если хотите создать не связанный добавьте ключ --full
        qm clone $cli $nvm5 --name "CLI"                 #создается СВЯЗАННЫЙ клон, если хотите создать не связанный добавьте ключ --full
        #Настраиваются апаратные части виртуальных машин
        qm set $nvm --ide2 none --net1 virtio,bridge=$br1 --net2 virtio,bridge=$br2 --net3 virtio,bridge=$br3 --tags DE_stand_user$nvm
        qm set $nvm1 --ide2 none --net0 virtio,bridge=$br3 --net1 virtio,bridge=$br5 --tags DE_stand_user$nvm
        qm set $nvm2 --ide2 none --net0 virtio,bridge=$br2 --net1 virtio,bridge=$br4 --tags DE_stand_user$nvm
        qm set $nvm3 --ide2 none --net0 virtio,bridge=$br5 --tags DE_stand_user$nvm
        qm set $nvm4 --ide2 none --net0 virtio,bridge=$br4 --virtio1 local-lvm:1 --virtio2 local-lvm:1 --virtio3 local-lvm:1 --tags DE_stand_user$nvm
        qm set $nvm5 --ide2 none --net0 virtio,bridge=$br1 --tags DE_stand_user$nvm --cdrom none
    }&>/dev/null
    echo "Развертывание машин для рабочего места $i завершено"
#       echo "Настройка сетевых параметров ISP для рабочего места $i"
#        qm start $nvm                                   #Запуск ISP
#        #Время ожидания запуска машин
#        sleep $time         
#    {
#        qm guest exec $nvm -- bash -c "cp -R /etc/net/ifaces/ens18 /etc/net/ifaces/ens19"
#        qm guest exec $nvm -- bash -c "sed -i '/^BOOTPROTO=/s/=.*/=static/' /etc/net/ifaces/ens19/options"
#        qm guest exec $nvm -- bash -c "touch /etc/net/ifaces/ens19/ipv4address"
#        qm guest exec $nvm -- bash -c "echo 1.1.1.1/30 > /etc/net/ifaces/ens19/ipv4address"
#        qm guest exec $nvm -- bash -c "cp -R /etc/net/ifaces/ens18 /etc/net/ifaces/ens20"
#        qm guest exec $nvm -- bash -c "sed -i '/^BOOTPROTO=/s/=.*/=static/' /etc/net/ifaces/ens20/options"
#        qm guest exec $nvm -- bash -c "touch /etc/net/ifaces/ens20/ipv4address"
#        qm guest exec $nvm -- bash -c "echo 2.2.2.1/30 > /etc/net/ifaces/ens20/ipv4address"
#        qm guest exec $nvm -- bash -c "cp -R /etc/net/ifaces/ens18 /etc/net/ifaces/ens21"
#        qm guest exec $nvm -- bash -c "sed -i '/^BOOTPROTO=/s/=.*/=static/' /etc/net/ifaces/ens21/options"
#        qm guest exec $nvm -- bash -c "touch /etc/net/ifaces/ens21/ipv4address"
#        qm guest exec $nvm -- bash -c "echo 3.3.3.1/30 > /etc/net/ifaces/ens21/ipv4address"
#        qm guest exec $nvm -- bash -c "sed -i '/^net.ipv4.ip_forward =/s/=.*/= 1/' /etc/net/sysctl.conf"
#        qm guest exec $nvm -- bash -c "iptables -t nat -A POSTROUTING -j MASQUERADE"
#        qm guest exec $nvm -- bash -c "iptables-save -f /etc/sysconfig/iptables"
#        qm guest exec $nvm -- bash -c "systemctl enable iptables"
#        qm guest exec $nvm -- bash -c "systemctl restart network"
#        expect passwd.sh $nvm
#        qm stop $nvm
#
#        }&>/dev/null
#    echo -e "\033[32m DONE \033[0m" 
    echo "Создание учетной записи"
    {
        pveum group add student-de --comment "users for DE"
        pveum user add user$nvm@pve --password P@ssw0rd --enable 1 --groups student-de #Создание пользователей для доступа к стенду
        pveum acl modify /vms/$nvm --roles PVEVMUser --users user$nvm@pve              #Выдача прав на доступ к стенду пользователям
        pveum acl modify /vms/$nvm1 --roles PVEVMUser --users user$nvm@pve             #Выдача прав на доступ к стенду пользователям
        pveum acl modify /vms/$nvm2 --roles PVEVMUser --users user$nvm@pve             #Выдача прав на доступ к стенду пользователям
        pveum acl modify /vms/$nvm3 --roles PVEVMUser --users user$nvm@pve             #Выдача прав на доступ к стенду пользователям
        pveum acl modify /vms/$nvm4 --roles PVEVMUser --users user$nvm@pve             #Выдача прав на доступ к стенду пользователям
        pveum acl modify /vms/$nvm5 --roles PVEVMUser --users user$nvm@pve             #Выдача прав на доступ к стенду пользователям
    }&>/dev/null
    echo -e "\033[32m DONE \033[0m" 
    echo "Создание рабочего места $i завершено"
}

function delete {
    max=$(($first_isp + $nbr))
    for (( j=$(($first_isp)); j <= $(($max)); j++ ))
    do
        echo "Удаление сетевых устройств Proxmox для стенда" 
        sed -i "/auto vmbr$j/,+6d" "/etc/network/interfaces"
        echo -e "\033[32m DONE \033[0m" 
    done
        echo "Удаление виртуальных машин стенда"
        {
            qm destroy $first_isp 
            qm destroy $(($first_isp + 1))
            qm destroy $(($first_isp + 2))
            qm destroy $(($first_isp + 3))
            qm destroy $(($first_isp + 4))
            qm destroy $(($first_isp + 5))
        }&>/dev/null
        echo -e "\033[32m DONE \033[0m" 
        echo "Удаление пользователя"
        {
            pveum user delete user$first_isp@pve
        }&>/dev/null
        echo -e "\033[32m DONE \033[0m" 
            clear 
            echo "Укажите номер следующего стенда для удаления: " 
            echo "Возврат в меню с перезагрузкой сети: 0 "
            read -p  "Выбор: " first_isp
                case $first_isp in
                 0)
                    systemctl restart networking
                    clear
                    main
                ;;
                *)
                    delete
                ;;
                esac
}

function check_hostname () {
    #Проверка настройки интерфейсов
    if (qm guest exec "$1" -- cat "$2" | grep -q "$3"); then
       #echo -e "Имя виртуальной машины "$1" - \033[32m"$3"\033[0m : задано \033[32mверно\033[0m"
    result=$(($result + 1))
    else
        echo -e "Имя виртуальной машины "$1" - \033[31m"$3"\033[0m : задано \033[31mне верно\033[0m"
    fi

}

function check_ip () {
    if (qm guest exec "$1" -- cat "$2" | grep -q "$3"); then
       echo -e "IP адрес "$1" - \033[32m"$3"\033[0m : задано \033[32mверно\033[0m"
    else
        echo -e "IP адрес "$1" - \033[31m"$3"\033[0m : задано \033[31mне верно\033[0m"
    fi
    if [ -z $4 ]; then
        echo ""
    else
        if (qm guest exec "$1" -- cat "$4" | grep -q "$5"); then
            echo -e "Шлюз "$1" - \033[32m"$5"\033[0m : задано \033[32mверно\033[0m"
            else
                echo -e "Шлюз "$1" - \033[31m"$5"\033[0m : задано \033[31mне верно\033[0m"
        fi
    fi
    if [ -z $6 ]; then
        echo ""
    else
        if (qm guest exec "$1" -- cat "$6" | grep -q "$7"); then
        echo -e "DNS "$1" - \033[32m"$7"\033[0m : задано \033[32mверно\033[0m"
        else
            echo -e "DNS "$1" - \033[31m"$7"\033[0m : задано \033[31mне верно\033[0m"
        fi
    fi
}

# shellcheck disable=SC2120


function main() {
    clear
    echo "+=========== Сделай выбор ============+"
    echo "|Скачать шаблоны машин: 1             |"
    echo "|Развертка стендов из шаблонов: 2     |"
    echo "|Удаление стенда: 3                   |"
    echo "|Обновление параметров сети Proxmox: 4|"
    echo "|Выполнить проверку рабочего места: 5 |"
    echo "+-------------------------------------+"
    read -p  "Выбор: " choice


    case $choice in
        1)
            read -p "Укажите VMID для шаблона SRV: " srv
            read -p "Укажите VMID для шаблона CLI: " cli
            download_template
        ;;
        2)
            read -p "Введите VMID шаблона SRV: " srv
            read -p "Введите VMID шаблона CLI: " cli
            read -p "Введите количество стендов: " workplace
            read -p "Укажите VMID первой машины (-10): " first_isp
 #           read -p "Укажите примерное время включения ISP (в сек), важно для настройки ISP (для SSD - 30): " time
            deploy_workplaces
            #sleep 1
            #systemctl restart networking
        ;;
        3) 
            read -p "Укажите номер учетной запись стенда для удаления(для учетной записи user100 - нужно ввести 100) : " first_isp
            delete
        ;;
        4)
            systemctl restart networking
            main
        ;;
        5)
            read -p "Укажите номер рабочего места (VMID ISP): " isp
            echo "Запуск машин рабочего места"
            qm start $isp
            qm start $(($isp+1))
            qm start $(($isp+2))
            qm start $(($isp+3))
            qm start $(($isp+4))
            qm start $(($isp+5))
            sleep 20
            echo -e "\033[32m DONE \033[0m" 
            sleep 1
            clear
            echo "--------------Проверка имен устройств--------------"
            result=0
            check_hostname $(($isp + 1)) $hostname $hq_r_name
            check_hostname $(($isp + 2)) $hostname $br_r_name
            check_hostname $(($isp + 3)) $hostname $hq_srv_name
            check_hostname $(($isp + 4)) $hostname $br_srv_name
            check_hostname $(($isp + 5)) $hostname $cli_name
            if [[ $result = 5 ]]; then
                echo -e "\033[32mИмена машинам заданы верно\033[0m"
            else
                echo -e "\033[31mИмена машин заданы не верно\033[0m"
            fi
            echo "--------------Проверка имен завершена--------------"
            check_ip $(($isp + 1)) $ens18 $hq_r_isp $ens18_gw $hq_r_gw $ens18_dns $hq_r_dns
            check_ip $(($isp + 1)) $ens19 $hq_r_hq_srv
            check_ip $(($isp + 2)) $ens18 $br_r_isp $ens18_gw $br_r_gw $ens18_dns $br_r_dns
            check_ip $(($isp + 2)) $ens19 $br_r_br_srv
            check_ip $(($isp + 3)) $ens18 $hq_srv $ens18_gw $hq_srv_gw $ens18_dns $hq_srv_dns
            check_ip $(($isp + 4)) $ens18 $br_srv $ens18_gw $br_srv_gw $ens18_dns $br_srv_dns
            qm stop $isp
            qm stop $(($isp+1))
            qm stop $(($isp+2))
            qm stop $(($isp+3))
            qm stop $(($isp+4))
            qm stop $(($isp+5))
        ;; 
        *)
            echo "Нереализуемый выбор"
            exit 1
        ;;
    esac
}




main

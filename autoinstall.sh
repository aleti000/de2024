#!/bin/bash
nbr=5 # количество мостов на этом стенде

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
    main
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

# shellcheck disable=SC2120


function main() {
    clear
    echo "+=========== Сделай выбор ============+"
    echo "|Скачать шаблоны машин: 1             |"
    echo "|Развертка стендов из шаблонов: 2     |"
    echo "|Удаление стенда: 3                   |"
    echo "|Обновление параметров сети Proxmox: 4|"
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
        *)
            echo "Нереализуемый выбор"
            exit 1
        ;;
    esac
}




main

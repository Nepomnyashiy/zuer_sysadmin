NAME        FSTYPE   FSVER LABEL      UUID                                 FSAVAIL FSUSE% MOUNTPOINTS
loop0       squashfs 4.0                                                         0   100% /snap/firefox/8107
loop1       squashfs 4.0                                                         0   100% /snap/desktop-security-center/150
loop2       squashfs 4.0                                                         0   100% /snap/firmware-updater/226
loop3       squashfs 4.0                                                         0   100% /snap/bare/5
loop4       squashfs 4.0                                                         0   100% /snap/core24/1587
loop5       squashfs 4.0                                                         0   100% /snap/gnome-46-2404/153
loop6       squashfs 4.0                                                         0   100% /snap/gtk-common-themes/1535
loop7       squashfs 4.0                                                         0   100% /snap/mesa-2404/1165
loop8       squashfs 4.0                                                         0   100% /snap/prompting-client/204
loop9       squashfs 4.0                                                         0   100% /snap/snap-store/1367
loop10      squashfs 4.0                                                         0   100% /snap/snapd/26865
loop11      squashfs 4.0                                                         0   100% /snap/snapd-desktop-integration/361
loop12      squashfs 4.0                                                         0   100% /snap/telegram-desktop/7014
sda                                                                                       
├─sda1                                                                                    
└─sda2      ntfs           Games      E206FE6306FE385D                                    
sdb                                                                                       
└─sdb1      ext4     1.0   godny_soft e5bd37e6-80d3-4507-8201-e9cea02f61a4  197,4G     5% /run/media/nsadmin/godny_soft
sdc                                                                                       
├─sdc1      vfat     FAT32            0B26-EF84                                 1G     1% /boot/efi
└─sdc2      ext4     1.0              b39c5755-7c23-4088-93b8-009b2a63208b   76,6G    24% /
sdd                                                                                       
├─sdd1                                                                                    
└─sdd2      ntfs           X-FILES    2800B35C00B33024                      715,8G    62% /srv/storage/x-files
                                                                                          /run/media/nsadmin/X-FILES
sde                                                                                       
└─sde1      ntfs           MEGA FILES 18B0DD66B0DD4AC0                      857,7G    54% /srv/storage/mega-files
sdf                                                                                       
└─sdf1      ext4     1.0   ufiles     548a00f5-dfd3-47d0-9879-b2a175b5bdb1  763,5G    12% /mnt/ufiles
nvme0n1                                                                                   
├─nvme0n1p1 vfat     FAT32            B682-875E                                           
├─nvme0n1p2                                                                               
├─nvme0n1p3 ntfs                      4EEE8360EE833EE9                                    
└─nvme0n1p4 ntfs                      CCC205ABC2059ABA                                    
[sudo: authenticate] Пароль:           
● docker.service - Docker Application Container Engine
     Loaded: loaded (/usr/lib/systemd/system/docker.service; enabled; preset: enabled)
     Active: active (running) since Thu 2026-06-25 13:15:50 MSK; 1h 2min ago
 Invocation: 4d11231c610b4ca291c75c379d99b664
TriggeredBy: ● docker.socket
       Docs: https://docs.docker.com
   Main PID: 61133 (dockerd)
      Tasks: 37
     Memory: 44M (peak: 141.6M)
        CPU: 53.469s
     CGroup: /system.slice/docker.service
             ├─61133 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
             └─88670 /usr/bin/docker-proxy -proto tcp -host-ip 127.0.0.1 -host-port 18080 -container-ip 172.18.0.4 -container-port 80 -use-listen-fd

июн 25 13:15:50 ZUER dockerd[61133]: time="2026-06-25T13:15:50.367221011+03:00" level=info msg="Daemon has completed initialization"
июн 25 13:15:50 ZUER dockerd[61133]: time="2026-06-25T13:15:50.367281332+03:00" level=info msg="API listen on /run/docker.sock"
июн 25 13:15:50 ZUER systemd[1]: Started docker.service - Docker Application Container Engine.
июн 25 13:31:45 ZUER dockerd[61133]: time="2026-06-25T13:31:45.778449274+03:00" level=info msg="image pulled" digest="sha256:6ab0b6e7381779332f97b8ca76193e45b0756f38d4c0dcda72dbb3c32061ab99" remote="docker.io/library/redis:7-alpine" spanID=b4d6f65156c17d56 traceID=2182a5c55b40527c7189c914519150a1
июн 25 13:32:31 ZUER dockerd[61133]: time="2026-06-25T13:32:31.051689071+03:00" level=info msg="image pulled" digest="sha256:be1ef4fe5f14589325c08a41c76334097ce66c86264b75e1d28342c742782a61" remote="docker.io/library/mariadb:11" spanID=80f5819d1d7c7051 traceID=2182a5c55b40527c7189c914519150a1
июн 25 13:37:00 ZUER dockerd[61133]: time="2026-06-25T13:37:00.719958458+03:00" level=error msg="failed to cleanup \"extract-346598170-BJQP sha256:431db6c858f00ccd7edd2492145a8578828aacba90f201099b1b048f264fcb2f\"" error="NotFound: snapshot extract-346598170-BJQP sha256:431db6c858f00ccd7edd2492145a8578828aacba90f201099b1b048f264fcb2f does not exist: not found" spanID=9275abbe2b22ef3e traceID=2182a5c55b40527c7189c914519150a1
июн 25 13:50:18 ZUER dockerd[61133]: time="2026-06-25T13:50:18.801358953+03:00" level=info msg="image pulled" digest="sha256:4d4a6b5ed15a7eb4537538c848eb78833f53bed62f93e7d5af144f360cd53ff2" remote="docker.io/library/nextcloud:apache" spanID=a30fb897043cf458 traceID=074dab86ca668a61717f5dc7311b3cae
июн 25 13:50:25 ZUER dockerd[61133]: time="2026-06-25T13:50:25.489350589+03:00" level=info msg="sbJoin: gwep4 ''->'0a9867860bc8', gwep6 ''->''" eid=0a9867860bc8 ep=nextcloud-db-1 net=nextcloud_internal nid=68daff5a757f spanID=a88fb361c4e8ab93 traceID=074dab86ca668a61717f5dc7311b3cae
июн 25 13:50:25 ZUER dockerd[61133]: time="2026-06-25T13:50:25.491693935+03:00" level=info msg="sbJoin: gwep4 ''->'ff27b71323f8', gwep6 ''->''" eid=ff27b71323f8 ep=nextcloud-redis-1 net=nextcloud_internal nid=68daff5a757f spanID=4a81d5824f2865da traceID=074dab86ca668a61717f5dc7311b3cae
июн 25 13:50:25 ZUER dockerd[61133]: time="2026-06-25T13:50:25.581136024+03:00" level=info msg="sbJoin: gwep4 ''->'b364a9210638', gwep6 ''->''" eid=b364a9210638 ep=nextcloud-app-1 net=nextcloud_internal nid=68daff5a757f spanID=b1918b8862f1aa45 traceID=074dab86ca668a61717f5dc7311b3cae
Warning: The unit file, source configuration file or drop-ins of docker.service changed on disk. Run 'systemctl daemon-reload' to reload units.

○ ssh.service - OpenBSD Secure Shell server
     Loaded: loaded (/usr/lib/systemd/system/ssh.service; disabled; preset: enabled)
     Active: inactive (dead)
TriggeredBy: ● ssh.socket
       Docs: man:sshd(8)
             man:sshd_config(5)
Warning: The unit file, source configuration file or drop-ins of ssh.service changed on disk. Run 'systemctl daemon-reload' to reload units.

● xrdp.service - xrdp daemon
     Loaded: loaded (/usr/lib/systemd/system/xrdp.service; enabled; preset: enabled)
     Active: active (running) since Thu 2026-06-25 13:15:45 MSK; 1h 2min ago
 Invocation: 7b41d5a516544850b6fc93889e0282a8
       Docs: man:xrdp(8)
             man:xrdp.ini(5)
   Main PID: 59910 (xrdp)
      Tasks: 1 (limit: 37333)
     Memory: 1M (peak: 2.4M)
        CPU: 30ms
     CGroup: /system.slice/xrdp.service
             └─59910 /usr/sbin/xrdp --nodaemon

июн 25 13:15:45 ZUER systemd[1]: Starting xrdp.service - xrdp daemon...
июн 25 13:15:45 ZUER systemd[1]: Started xrdp.service - xrdp daemon.
июн 25 13:15:45 ZUER xrdp[59910]: [INFO ] starting xrdp with pid 59910
июн 25 13:15:45 ZUER xrdp[59910]: [INFO ] address [0.0.0.0] port [3389] mode 1
июн 25 13:15:45 ZUER xrdp[59910]: [INFO ] listening to port 3389 on 0.0.0.0
июн 25 13:15:45 ZUER xrdp[59910]: [INFO ] xrdp_listen_pp done
Warning: The unit file, source configuration file or drop-ins of xrdp.service changed on disk. Run 'systemctl daemon-reload' to reload units.

● fail2ban.service - Fail2Ban Service
     Loaded: loaded (/usr/lib/systemd/system/fail2ban.service; enabled; preset: enabled)
     Active: active (running) since Thu 2026-06-25 13:15:46 MSK; 1h 2min ago
 Invocation: 75163ef179ce42019a8359caa7fb5f1e
       Docs: man:fail2ban(1)
   Main PID: 60274 (fail2ban-server)
      Tasks: 5 (limit: 37333)
     Memory: 15.4M (peak: 16.4M)
        CPU: 2.892s
     CGroup: /system.slice/fail2ban.service
             └─60274 /usr/bin/python3 /usr/bin/fail2ban-server -xf start

июн 25 13:15:46 ZUER systemd[1]: Started fail2ban.service - Fail2Ban Service.
июн 25 13:15:46 ZUER fail2ban-server[60274]: Server ready
Warning: The unit file, source configuration file or drop-ins of fail2ban.service changed on disk. Run 'systemctl daemon-reload' to reload units.
NAMES               IMAGE              STATUS          PORTS
nextcloud-app-1     nextcloud:apache   Up 27 minutes   127.0.0.1:18080->80/tcp
nextcloud-redis-1   redis:7-alpine     Up 27 minutes   6379/tcp
nextcloud-db-1      mariadb:11         Up 27 minutes   3306/tcp

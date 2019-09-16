 #!/bin/sh

# Script for Monitoring a Raspberry Pi with Zabbix
# based on 2013 Bernhard Linz  Bernhard@znil.de / http://znil.net
# updated for Raspi4 Stefan Knaak
#


case "$1" in
        boardversion)
                # get the Hardware Version
                sudo cat /proc/cpuinfo | grep Hardware | tr -d " " | cut -d ":" -f 2
                ;;
        boardrevision)
                # get the Hardware Revision
                sudo cat /proc/cpuinfo | grep Revision | tr -d " " | cut -d ":" -f 2
                ;;
        boardserialnumber)
                # get the Board unique Serial Number
                sudo cat /proc/cpuinfo | grep Serial | tr -d " " | cut -d ":" -f 2
                ;;
        cpuvoltage)
                # Voltage in Volt
                sudo /opt/vc/bin/vcgencmd measure_volts | tr -d "volt=" | tr -d "V"
                ;;
        cpuclock)
                # CPU Clock Speed in Hz
                #sudo /opt/vc/bin/vcgencmd measure_clock arm | tr -d "frequency(48)="
                sudo /opt/vc/bin/vcgencmd measure_clock arm | cut -d'='  -f 2-
                ;;
        cpumem)
                # CPU Memory in MByte
                sudo vcgencmd get_mem arm | tr -d "arm=" | tr -d "M"
                ;;
        firmwareversion)
                # Just the naked String of the firmware Version
                sudo vcgencmd version | grep version | cut -d " " -f 2
                ;;
        gpumem)
                # Graphics memeory in MByte
                sudo vcgencmd get_mem gpu | tr -d "gpu=" | tr -d "M"
                ;;
        sdcardtotalsize)
                # Size of SD-Card in KByte
                sudo df -P | grep /dev/root | tr -s " " " " | cut -d " " -f 2
                ;;
        sdcardused)
                # Used Diskspace in KByte
                sudo df -P | grep /dev/root | tr -s " " " " | cut -d " " -f 3
                ;;
        sdcardusedpercent)
                # Used Diskspace in Percent
                sudo df -P | grep /dev/root | tr -s " " " " | cut -d " " -f 5
                ;;
        sdcardfree)
                # free Diskspace in KByte
                sudo df -P | grep /dev/root | tr -s " " " " | cut -d " " -f 4
                ;;
        temperature)
                # Temperature in 1/1000 centigrade
                sudo cat /sys/class/thermal/thermal_zone*/temp
                ;;
        lcd_info)
                # Temperature in 1/1000 centigrade
                sudo vcgencmd get_lcd_info
                ;;
        measure_clock_arm)
                 sudo vcgencmd measure_clock arm | cut -d'='  -f 2-
               ;;
        measure_clock_core)
                 sudo vcgencmd measure_clock core | cut -d'='  -f 2-
               ;;
        measure_clock_h264)
                 sudo vcgencmd measure_clock h264 | cut -d'='  -f 2-
               ;;
        measure_clock_isp)
                 sudo vcgencmd measure_clock isp | cut -d'='  -f 2-
               ;;
        measure_clock_v3d)
                 sudo vcgencmd measure_clock v3d | cut -d'='  -f 2-
               ;;
        measure_clock_uart)
                 sudo vcgencmd measure_clock uart | cut -d'='  -f 2-
               ;;
        measure_clock_emmc)
                 sudo vcgencmd measure_clock emmc | cut -d'='  -f 2-
               ;;
        measure_clock_pixel)
                 sudo vcgencmd measure_clock pixel | cut -d'='  -f 2-
               ;;
        measure_clock_vec)
                 sudo vcgencmd measure_clock vec | cut -d'='  -f 2-
               ;;
        measure_clock_hdmi)
                 sudo vcgencmd measure_clock hdmi | cut -d'='  -f 2-
               ;;
        measure_clock_dpi)
                 sudo vcgencmd measure_clock dpi | cut -d'='  -f 2-
               ;;
        measure_volts_core)
                 sudo vcgencmd measure_volts core | tr -d "volt=" | tr -d "V"
               ;;
        measure_volts_sdram_p)
                 sudo vcgencmd measure_volts sdram_p | tr -d "volt=" | tr -d "V"
               ;;
        measure_volts_sdram_c)
                 sudo vcgencmd measure_volts sdram_c | tr -d "volt=" | tr -d "V"
               ;;
        measure_volts_sdram_i)
                 sudo vcgencmd measure_volts sdram_i | tr -d "volt=" | tr -d "V"
               ;;
        measure_volts_sdram_i)
                 sudo vcgencmd measure_volts sdram_i | tr -d "volt=" | tr -d "V"
               ;;
        codec_enabled_H264)
                DATA=$(sudo vcgencmd codec_enabled H264 | cut -d'='  -f 2-)        
                if [ "$DATA" = "enabled" ]; then  
                        echo 1  
                fi
                if [ "$DATA" = "disabled" ]; then  
                        echo 0
                fi        

               ;;
        codec_enabled_MPG2)
                 DATA=$(sudo vcgencmd codec_enabled MPG2 | cut -d'='  -f 2-)
                if [ "$DATA" = "enabled" ]; then  
                        echo 1  
                fi
                if [ "$DATA" = "disabled" ]; then  
                        echo 0
                fi        
               ;;
        codec_enabled_WVC1)
                 DATA=$(sudo vcgencmd codec_enabled WVC1 | cut -d'='  -f 2-)
                if [ "$DATA" = "enabled" ]; then  
                        echo 1  
                fi
                if [ "$DATA" = "disabled" ]; then  
                        echo 0
                fi        
               ;;
        codec_enabled_MPG4)
                 DATA=$(sudo vcgencmd codec_enabled MPG4 | cut -d'='  -f 2-)
                if [ "$DATA" = "enabled" ]; then  
                        echo 1  
                fi
                if [ "$DATA" = "disabled" ]; then  
                        echo 0
                fi        
               ;;
        codec_enabled_MJPG)
                 DATA=$(sudo vcgencmd codec_enabled MJPG | cut -d'='  -f 2-)
                if [ "$DATA" = "enabled" ]; then  
                        echo 1  
                fi
                if [ "$DATA" = "disabled" ]; then  
                        echo 0
                fi        
               ;;
        codec_enabled_WMV9)
                 DATA=$(sudo vcgencmd codec_enabled WMV9 | cut -d'='  -f 2-)
                if [ "$DATA" = "enabled" ]; then  
                        echo 1  
                fi
                if [ "$DATA" = "disabled" ]; then  
                        echo 0
                fi        
               ;;
        debug)
                # Temperature in 1/1000 centigrade
                
                for src in boardversion boardrevision boardserialnumber cpuvoltage cpuclock cpumem firmwareversion gpumem sdcardtotalsize sdcardused sdcardusedpercent sdcardfree temperature ; do
                echo -e "$src:\t$(sudo $HOME/.dot/raspi/raspi_info.sh $src)" ;
                done

                for src in arm core h264 isp v3d uart pwm emmc pixel vec hdmi dpi ; do
                echo -e "$src:\t$(sudo vcgencmd measure_clock $src)" ;
                done

                for id in core sdram_c sdram_i sdram_p ; do
                echo -e "$id:\t$(sudo vcgencmd measure_volts $id)" ;
                done

                for codec in H264 MPG2 WVC1 MPG4 MJPG WMV9 ; do
                echo -e "$codec:\t$(sudo vcgencmd codec_enabled $codec)" ;
                done                

                ;;
        *)
                echo "Usage: $N {boardversion|boardrevision|boardserialnumber|cpuvoltage|cpuclock|cpumem|firmwareversion|gpumem|sdcardtotalsize|sdcardused|sdcardusedpercent|sdcardfree|temperature|lcd_info}" >&2
esac







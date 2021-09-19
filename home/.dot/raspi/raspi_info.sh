 #!/bin/sh

# Script for Monitoring a Raspberry Pi with Zabbix
# based on 2013 Bernhard Linz  Bernhard@znil.de / http://znil.net
# updated for Raspi4 Stefan Knaak
#


case "$1" in
        fanSpeed)
                # get the Hardware Version
                cat /tmp/fanSpeed.value
                ;;
        boardversion)
                # get the Hardware Version
                 cat /proc/cpuinfo | grep Hardware | tr -d " " | cut -d ":" -f 2
                ;;
        boardrevision)
                # get the Hardware Revision
                 cat /proc/cpuinfo | grep Revision | tr -d " " | cut -d ":" -f 2
                ;;
        boardserialnumber)
                # get the Board unique Serial Number
                 cat /proc/cpuinfo | grep Serial | tr -d " " | cut -d ":" -f 2
                ;;
        cpuvoltage)
                # Voltage in Volt
                 /opt/vc/bin/vcgencmd measure_volts | tr -d "volt=" | tr -d "V"
                ;;
        cpuclock)
                # CPU Clock Speed in Hz
                # /opt/vc/bin/vcgencmd measure_clock arm | tr -d "frequency(48)="
                 /opt/vc/bin/vcgencmd measure_clock arm | cut -d'='  -f 2-
                ;;
        cpumem)
                # CPU Memory in MByte
                 vcgencmd get_mem arm | tr -d "arm=" | tr -d "M"
                ;;
        firmwareversion)
                # Just the naked String of the firmware Version
                 vcgencmd version | grep version | cut -d " " -f 2
                ;;
        gpumem)
                # Graphics memeory in MByte
                 vcgencmd get_mem gpu | tr -d "gpu=" | tr -d "M"
                ;;
        sdcardtotalsize)
                # Size of SD-Card in KByte
                 df -P | grep /dev/root | tr -s " " " " | cut -d " " -f 2
                ;;
        sdcardused)
                # Used Diskspace in KByte
                 df -P | grep /dev/root | tr -s " " " " | cut -d " " -f 3
                ;;
        sdcardusedpercent)
                # Used Diskspace in Percent
                 df -P | grep /dev/root | tr -s " " " " | cut -d " " -f 5
                ;;
        sdcardfree)
                # free Diskspace in KByte
                 df -P | grep /dev/root | tr -s " " " " | cut -d " " -f 4
                ;;
        temperature)
                # Temperature in 1/1000 centigrade
                 cat /sys/class/thermal/thermal_zone*/temp
                ;;
        lcd_info)
                # Temperature in 1/1000 centigrade
                 vcgencmd get_lcd_info
                ;;
        measure_clock_arm)
                  vcgencmd measure_clock arm | cut -d'='  -f 2-
               ;;
        measure_clock_core)
                  vcgencmd measure_clock core | cut -d'='  -f 2-
               ;;
        measure_clock_h264)
                  vcgencmd measure_clock h264 | cut -d'='  -f 2-
               ;;
        measure_clock_isp)
                  vcgencmd measure_clock isp | cut -d'='  -f 2-
               ;;
        measure_clock_v3d)
                  vcgencmd measure_clock v3d | cut -d'='  -f 2-
               ;;
        measure_clock_uart)
                  vcgencmd measure_clock uart | cut -d'='  -f 2-
               ;;
        measure_clock_emmc)
                  vcgencmd measure_clock emmc | cut -d'='  -f 2-
               ;;
        measure_clock_pixel)
                  vcgencmd measure_clock pixel | cut -d'='  -f 2-
               ;;
        measure_clock_vec)
                  vcgencmd measure_clock vec | cut -d'='  -f 2-
               ;;
        measure_clock_hdmi)
                  vcgencmd measure_clock hdmi | cut -d'='  -f 2-
               ;;
        measure_clock_dpi)
                  vcgencmd measure_clock dpi | cut -d'='  -f 2-
               ;;
        measure_volts_core)
                  vcgencmd measure_volts core | tr -d "volt=" | tr -d "V"
               ;;
        measure_volts_sdram_p)
                  vcgencmd measure_volts sdram_p | tr -d "volt=" | tr -d "V"
               ;;
        measure_volts_sdram_c)
                  vcgencmd measure_volts sdram_c | tr -d "volt=" | tr -d "V"
               ;;
        measure_volts_sdram_i)
                  vcgencmd measure_volts sdram_i | tr -d "volt=" | tr -d "V"
               ;;
        measure_volts_sdram_i)
                  vcgencmd measure_volts sdram_i | tr -d "volt=" | tr -d "V"
               ;;
        codec_enabled_H264)
                DATA=$( vcgencmd codec_enabled H264 | cut -d'='  -f 2-)        
                if [ "$DATA" = "enabled" ]; then  
                        echo 1  
                fi
                if [ "$DATA" = "disabled" ]; then  
                        echo 0
                fi        

               ;;
        codec_enabled_MPG2)
                 DATA=$( vcgencmd codec_enabled MPG2 | cut -d'='  -f 2-)
                if [ "$DATA" = "enabled" ]; then  
                        echo 1  
                fi
                if [ "$DATA" = "disabled" ]; then  
                        echo 0
                fi        
               ;;
        codec_enabled_WVC1)
                 DATA=$( vcgencmd codec_enabled WVC1 | cut -d'='  -f 2-)
                if [ "$DATA" = "enabled" ]; then  
                        echo 1  
                fi
                if [ "$DATA" = "disabled" ]; then  
                        echo 0
                fi        
               ;;
        codec_enabled_MPG4)
                 DATA=$( vcgencmd codec_enabled MPG4 | cut -d'='  -f 2-)
                if [ "$DATA" = "enabled" ]; then  
                        echo 1  
                fi
                if [ "$DATA" = "disabled" ]; then  
                        echo 0
                fi        
               ;;
        codec_enabled_MJPG)
                 DATA=$( vcgencmd codec_enabled MJPG | cut -d'='  -f 2-)
                if [ "$DATA" = "enabled" ]; then  
                        echo 1  
                fi
                if [ "$DATA" = "disabled" ]; then  
                        echo 0
                fi        
               ;;
        codec_enabled_WMV9)
                 DATA=$( vcgencmd codec_enabled WMV9 | cut -d'='  -f 2-)
                if [ "$DATA" = "enabled" ]; then  
                        echo 1  
                fi
                if [ "$DATA" = "disabled" ]; then  
                        echo 0
                fi        
               ;;
        debug)
                # Temperature in 1/1000 centigrade
                
                for src in boardversion boardrevision boardserialnumber cpuvoltage cpuclock cpumem firmwareversion gpumem sdcardtotalsize sdcardused sdcardusedpercent sdcardfree temperature fanSpeed; do
                echo  "$src:\t$( /home/pi/.dot/raspi/raspi_info.sh $src)" ;
                done

                for src in arm core h264 isp v3d uart pwm emmc pixel vec hdmi dpi ; do
                echo  "$src:\t$( vcgencmd measure_clock $src)" ;
                done

                for id in core sdram_c sdram_i sdram_p ; do
                echo  "$id:\t$( vcgencmd measure_volts $id)" ;
                done

                for codec in H264 MPG2 WVC1 MPG4 MJPG WMV9 ; do
                echo  "$codec:\t$( vcgencmd codec_enabled $codec)" ;
                done                

                ;;
        *)
                echo "Usage: $N {boardversion|boardrevision|boardserialnumber|cpuvoltage|cpuclock|cpumem|firmwareversion|gpumem|sdcardtotalsize|sdcardused|sdcardusedpercent|sdcardfree|temperature|lcd_info}" >&2
esac







 #!/bin/sh

# Script for Monitoring a Raspberry Pi with Zabbix
# based on 2013 Bernhard Linz  Bernhard@znil.de / http://znil.net
# updated for Raspi4 Stefan Knaak
#

#sudo usermod -aG video zabbix
# visudo zabbix  ALL=(ALL:ALL) ALL

# Dynamically find vcgencmd
VCGENCMD_PATH=$(which vcgencmd)
if [ -z "$VCGENCMD_PATH" ]; then
    echo "vcgencmd not found, searching further..."
    VCGENCMD_PATH=$(find /opt/vc/bin /usr/bin /bin -name vcgencmd 2>/dev/null)
    if [ -z "$VCGENCMD_PATH" ]; then
        echo "vcgencmd still not found. Please ensure it is installed."
        exit 1
    fi
fi

case "$1" in
        all)
                echo "Gathering all system information..."
                for item in fanSpeed boardversion boardrevision boardserialnumber cpuvoltage cpuclock cpumem firmwareversion gpumem sdcardtotalsize sdcardused sdcardusedpercent sdcardfree temperature lcd_info measure_clock_arm measure_clock_core measure_clock_h264 measure_clock_isp measure_clock_v3d measure_clock_uart measure_clock_emmc measure_clock_pixel measure_clock_vec measure_clock_hdmi measure_clock_dpi measure_volts_core measure_volts_sdram_p measure_volts_sdram_c measure_volts_sdram_i codec_enabled_H264 codec_enabled_MPG2 codec_enabled_WVC1 codec_enabled_MPG4 codec_enabled_MJPG codec_enabled_WMV9; do
                OUTPUT="$($0 $item)"
                if [ -z "$OUTPUT" ]; then
                        OUTPUT="N/A"
                fi
                printf "%s: %s\n" "$item" "$OUTPUT"  # Notice the \n at the end for a new line
                done
                ;;
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
                 $VCGENCMD_PATH measure_volts | tr -d "volt=" | tr -d "V"
                ;;
        cpuclock)
                # CPU Clock Speed in Hz
                # $VCGENCMD_PATH measure_clock arm | tr -d "frequency(48)="
                 $VCGENCMD_PATH measure_clock arm | cut -d'='  -f 2-
                ;;
        cpumem)
                # CPU Memory in MByte
                 $VCGENCMD_PATH get_mem arm | tr -d "arm=" | tr -d "M"
                ;;
        firmwareversion)
                # Just the naked String of the firmware Version
                 $VCGENCMD_PATH version | grep version | cut -d " " -f 2
                ;;
        gpumem)
                # Graphics memeory in MByte
                 $VCGENCMD_PATH get_mem gpu | tr -d "gpu=" | tr -d "M"
                ;;
        sdcardtotalsize)
                # Size of SD-Card in KByte
                df -P | grep " /$" | tr -s " " | cut -d " " -f 2
                ;;
        sdcardused)
                # Used Diskspace in KByte
                df -P | grep " /$" | tr -s " " | cut -d " " -f 3
                ;;
        sdcardusedpercent)
                # Used Diskspace in Percent
                df -P | grep " /$" | tr -s " " | cut -d " " -f 5
                ;;
        sdcardfree)
                # Free Diskspace in KByte
                df -P | grep " /$" | tr -s " " | cut -d " " -f 4
                ;;
        temperature)
                # Temperature in 1/1000 centigrade
                 cat /sys/class/thermal/thermal_zone*/temp
                ;;
        lcd_info)
                # Temperature in 1/1000 centigrade
                 $VCGENCMD_PATH get_lcd_info
                ;;
        measure_clock_arm)
                  $VCGENCMD_PATH measure_clock arm | cut -d'='  -f 2-
               ;;
        measure_clock_core)
                  $VCGENCMD_PATH measure_clock core | cut -d'='  -f 2-
               ;;
        measure_clock_h264)
                  $VCGENCMD_PATH measure_clock h264 | cut -d'='  -f 2-
               ;;
        measure_clock_isp)
                  $VCGENCMD_PATH measure_clock isp | cut -d'='  -f 2-
               ;;
        measure_clock_v3d)
                  $VCGENCMD_PATH measure_clock v3d | cut -d'='  -f 2-
               ;;
        measure_clock_uart)
                  $VCGENCMD_PATH measure_clock uart | cut -d'='  -f 2-
               ;;
        measure_clock_emmc)
                  $VCGENCMD_PATH measure_clock emmc | cut -d'='  -f 2-
               ;;
        measure_clock_pixel)
                  $VCGENCMD_PATH measure_clock pixel | cut -d'='  -f 2-
               ;;
        measure_clock_vec)
                  $VCGENCMD_PATH measure_clock vec | cut -d'='  -f 2-
               ;;
        measure_clock_hdmi)
                  $VCGENCMD_PATH measure_clock hdmi | cut -d'='  -f 2-
               ;;
        measure_clock_dpi)
                  $VCGENCMD_PATH measure_clock dpi | cut -d'='  -f 2-
               ;;
        measure_volts_core)
                  $VCGENCMD_PATH measure_volts core | tr -d "volt=" | tr -d "V"
               ;;
        measure_volts_sdram_p)
                  $VCGENCMD_PATH measure_volts sdram_p | tr -d "volt=" | tr -d "V"
               ;;
        measure_volts_sdram_c)
                  $VCGENCMD_PATH measure_volts sdram_c | tr -d "volt=" | tr -d "V"
               ;;
        measure_volts_sdram_i)
                  $VCGENCMD_PATH measure_volts sdram_i | tr -d "volt=" | tr -d "V"
               ;;
        measure_volts_sdram_i)
                  $VCGENCMD_PATH measure_volts sdram_i | tr -d "volt=" | tr -d "V"
               ;;
        codec_enabled_H264)
                DATA=$( $VCGENCMD_PATH codec_enabled H264 | cut -d'='  -f 2-)        
                if [ "$DATA" = "enabled" ]; then  
                        echo 1  
                fi
                if [ "$DATA" = "disabled" ]; then  
                        echo 0
                fi        

               ;;
        codec_enabled_MPG2)
                 DATA=$( $VCGENCMD_PATH codec_enabled MPG2 | cut -d'='  -f 2-)
                if [ "$DATA" = "enabled" ]; then  
                        echo 1  
                fi
                if [ "$DATA" = "disabled" ]; then  
                        echo 0
                fi        
               ;;
        codec_enabled_WVC1)
                 DATA=$( $VCGENCMD_PATH codec_enabled WVC1 | cut -d'='  -f 2-)
                if [ "$DATA" = "enabled" ]; then  
                        echo 1  
                fi
                if [ "$DATA" = "disabled" ]; then  
                        echo 0
                fi        
               ;;
        codec_enabled_MPG4)
                 DATA=$( $VCGENCMD_PATH codec_enabled MPG4 | cut -d'='  -f 2-)
                if [ "$DATA" = "enabled" ]; then  
                        echo 1  
                fi
                if [ "$DATA" = "disabled" ]; then  
                        echo 0
                fi        
               ;;
        codec_enabled_MJPG)
                 DATA=$( $VCGENCMD_PATH codec_enabled MJPG | cut -d'='  -f 2-)
                if [ "$DATA" = "enabled" ]; then  
                        echo 1  
                fi
                if [ "$DATA" = "disabled" ]; then  
                        echo 0
                fi        
               ;;
        codec_enabled_WMV9)
                 DATA=$( $VCGENCMD_PATH codec_enabled WMV9 | cut -d'='  -f 2-)
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
                echo  "$src:\t$( $VCGENCMD_PATH measure_clock $src)" ;
                done

                for id in core sdram_c sdram_i sdram_p ; do
                echo  "$id:\t$( $VCGENCMD_PATH measure_volts $id)" ;
                done

                for codec in H264 MPG2 WVC1 MPG4 MJPG WMV9 ; do
                echo  "$codec:\t$( vcgencmd codec_enabled $codec)" ;
                done                

                ;;
        *)
                echo "Usage: $N {boardversion|boardrevision|boardserialnumber|cpuvoltage|cpuclock|cpumem|firmwareversion|gpumem|sdcardtotalsize|sdcardused|sdcardusedpercent|sdcardfree|temperature|lcd_info}" >&2
                echo "Usage: $N all" >&2
esac







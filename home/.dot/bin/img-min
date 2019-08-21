#!/bin/bash
#
# Image minimizer
# Iteratively resamples image quality to a certain threshold, reducing image filesize but retaining quality similar to the original image
#
# example usage: ./imgmin.sh foo-before.jpg foo-after.jpg
#
# online demo: http://image-api.suckup.de/
#
# Author: Ryan Flynn <parseerror+imgmin@gmail.com>
# Author: Lars Moelleken <lars@moelleken.org>
#
# Requires:
#   imagemagick
#   gifsicle
#   optipng
#   pngcrush
#   pngnq
#   pngquant
#   jpegoptim
#   libjpeg-progs
#   mozjpeg
#
# References:
#   1. "Optimization of JPEG (JPG) images: good quality and small size", Retrieved May 23 2011, http://www.ampsoft.net/webdesign-l/jpeg-compression.html
#   2. "Convert, Edit, Or Compose Images From The Command-Line" In ImageMagick, Retrieved May 24 2011, http://www.imagemagick.org/script/command-line-tools.php
#   3. "Bash Floating Point Comparison", http://unstableme.blogspot.com/2008/06/bash-float-comparison-bc.html

if [ -z $1 ] || [ -z $2 ]; then
  echo "Usage $0 <image> <dst> [<quality>]"
  exit 1
fi

MIN_UNIQUE_COLORS=4096

src=$1
dst=$2
quality=$3
src_ext=$(echo "${src}" | tr '[:upper:]' '[:lower:]')

if [ ! -f $src ]; then
  echo "File $src does not exist"
  exit 1
fi

unique_colors()
{
  local src=$1
  local colors=`convert "$src" -format "%k" info:-`

  return $colors
}

do_png()
{
  local src=$1
  local tmpfile=$2
  local quality=$3
  local pngs=("$src") # always include existing file
  local outfile=""

  # look for PNG-optimizing programs and run them and save their output filenames
  # in the array $pngs
  if [ $(which pngnq) ]; then
    outfile="${tmpfile::$((${#tmpfile}-4))}-nq8${tmpfile:(-4)}"
    pngnq "$tmpfile"
    pngs[${#pngs[@]}]="$outfile"
  fi

  if [ $(which pngquant) ]; then
    if [ $quality ]; then
      pngquant --quality=${quality} "$tmpfile"
    else
      pngquant --quality=70-100 "$tmpfile"
    fi
    outfile="${tmpfile::$((${#tmpfile}-4))}-fs8${tmpfile:$((${#tmpfile}-4))}"
    pngs[${#pngs[@]}]="$outfile"
  fi

  # search "$pngs"-array for the smallest file and return it
  local smalli=0
  local smallbytes=$(stat -c%s "${pngs[0]}")
  local curri=1
  local currbytes=""

  while [ $curri -lt ${#pngs[@]} ]
  do
    currbytes=$(stat -c%s "${pngs[$curri]}")
    if [ $currbytes -lt $smallbytes ]; then
      let smalli=curri
    else
      rm -f "${pngs[$curri]}"
    fi
    let curri=curri+1
  done

  local file_new=${pngs[$smalli]}
  local tmpfile_new=$(mktemp);
  cp -p $file_new $tmpfile_new
  pngcrush -q -rem alla -reduce -brute "$tmpfile_new" "$file_new"
  rm $tmpfile_new;

  optipng -quiet -o7 "$file_new"

  echo "$file_new"
}

search_quality()
{
  local src=$1
  local tmpfile=$2
  local quality=$3
  local uc=`unique_colors "$src"`
  local use=""

  if [ $((uc < MIN_UNIQUE_COLORS)) ]; then

    # debug
    #echo "$uc < $MIN_UNIQUE_COLORS"

    if [ ".gif" = ${src_ext:(-4)} ]; then
      gifsicle --colors 256 -O2 $src -o $tmpfile
      return
    elif [ ".png" = ${src_ext:(-4)} ]; then
      cp -p $src $tmpfile
      use=$(do_png "$src" "$tmpfile" "$quality")

      # debug
      #echo "use:$use"

      cp -p $use $tmpfile
      return
    elif [ ".jpeg" = ${src_ext:(-5)} ] || [ ".jpg" = ${src_ext:(-4)} ]; then
      jpegoptim --quiet --strip-all $src

      local tmpfile_new=$(mktemp);
      cp -p $src $tmpfile_new
      jpegtran -progressive -copy none "$tmpfile_new" > "$src"
      rm $tmpfile_new;
    fi
  fi

  if [ $quality ]; then
    if [ ".jpeg" = ${src_ext:(-5)} ] || [ ".jpg" = ${src_ext:(-4)} ]; then
      convert $src TGA:- |
        cjpeg -progressive -quality $quality -sample 1x1 -outfile $tmpfile -targa
    else
      convert -interlace -quality $quality $src $tmpfile
    fi

    return 1
  fi

  local qmin=30
  local qmax=100
  local q=""
  local cmppct=""
  local cmpthreshold=""
  # binary search for lowest quality where compare < $cmpthreshold
  while [ $qmax -gt $((qmin+10)) ]; do
    q=$(((qmax+qmin-1)/2))

    # debug
    #echo "debug: " $qmax " - " $qmin " - " $q

    if [ ".jpeg" = ${src_ext:(-5)} ] || [ ".jpg" = ${src_ext:(-4)} ]; then
      convert $src TGA:- |
        cjpeg -progressive -quality $q -sample 1x1 -outfile $tmpfile -targa
    else
      convert -interlace -quality $q $src $tmpfile
    fi

    cmppct=`compare -metric RMSE $src $tmpfile /dev/null 2>&1 \
      | cut -d '(' -f2 | cut -d ')' -f1`
    cmppct=`echo "scale=5; $cmppct * 100" | bc -l`

    cmpthreshold=$cmppct;

    echo "foo: " $cmpthreshold

    if [[ $( LC_ALL=C printf '%.0f' $(echo "${cmpthreshold}" | bc -l)) -eq 1 ]]; then
      qmin=$q
    else
      qmax=$q
    fi

    # debug
    #printf "%.2f@%u" "$cmppct" "$q"
  done
}

check_image_stats()
{
  local k0=$((`stat -c %s $src` / 1024))
  local k1=$((`stat -c %s $tmpfile` / 1024))
  local kdiff=$((($k0-$k1) * 100 / $k0))

  if [ $kdiff -eq 0 ]; then
    k1=$k0
    kdiff=0
  fi

  if [ $((k0-k1)) -lt 0 ]; then
    if [ ".jpeg" = ${src_ext:(-5)} ] || [ ".jpg" = ${src_ext:(-4)} ]; then
      jpegoptim --quiet --strip-all $src

      local tmpfile_new=$(mktemp);
      cp -p $src $tmpfile_new
      jpegtran -progressive -copy none "$tmpfile_new" > "$tmpfile"
      rm $tmpfile_new;
    fi

    k0=$((`stat -c %s $src` / 1024))
    k1=$((`stat -c %s $tmpfile` / 1024))
    kdiff=$((($k0-$k1) * 100 / $k0))

    if [ $kdiff -eq 0 ]; then
      k1=$k0
      kdiff=0
    fi
  fi

  echo "Before:${k0}KB After:${k1}KB Saved:$((k0-k1))KB($kdiff%)"
  return $kdiff
}


ext=${src:(-3)}
tmpfile="/tmp/imgmin$$.$ext"
search_quality "$src" "$tmpfile" "$quality"
check_image_stats
cp -p $tmpfile $dst
rm -f $tmpfile

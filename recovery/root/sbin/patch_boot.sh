#!/sbin/sh
#
# Patch arm32 kernel.gz for magisk root, eg: redmi 7A/8A
# Depend on magiskboot
# by wzsx150
# v1.0-20210110
#

bootimg="$1"
[ -z "$1" ] && { 
  echo "usage: " 
  echo "     patch_boot.sh <boot.img>"
  exit 0
}

[ ! -e "$bootimg" ] && { 
  echo "Error: not find file: $bootimg"
  exit 1
}

hastools=`which magiskboot`
[ -z "$hastools" ] && { 
  echo "Error: not find magiskboot"
  exit 2
}


# 8 bytes hex to Little-Endian, eg: 1a7df88 to 88dfa701
hex2store() {
  [ -z "$1" ] && echo "hex2store: Missing variables" && return 1
  local var="$1"
  let var_sz=`echo ${#var}`
  [ "$var_sz" -le 0 ] && return 2
  # for 8 bytes
  while [ $var_sz -lt 8 ]
  do
    let var_sz=var_sz+1
    var="0$var"
  done

  local store=
  local i=`echo ${#var}`
  while [ $i -ge 2 ]
  do
    let i=i-2
    store="$store${var:$i:2}"
  done
  echo "$store"
}


#unpack boot.img
magiskboot unpack "$bootimg"
[ ! -e kernel ] && \
  echo "Error: boot.img not find kernel" && return 10

local arm32_header1=`dd if=kernel bs=1 count=4 2>/dev/null | od -H | grep -m 1 00 | awk '{print $2}'`
local arm32_header2=`dd if=kernel bs=1 count=4 skip=4 2>/dev/null | od -H | grep -m 1 00 | awk '{print $2}'`
[ "$arm32_header1" = e1a00000 -a "$arm32_header2" = e1a00000 ] || {
  echo "Error: kernel is not arm32" && return 11
}

#get info of kernel
gz_off_hex=`magiskboot hexpatch kernel 1F8B08 1F8B08 2>&1 | grep -m 1 -E "P" | cut -d' ' -f3`
[ -z "$gz_off_hex" ] && \
  echo "Error: kernel is not gz" && return 12
let gz_off_int=0x$gz_off_hex

kernel_sz_int=`ls -l kernel | awk '{print $5}'`
kernel_sz_hex=`printf %X "$kernel_sz_int"`
kernel_sz_hexstore=`hex2store $kernel_sz_hex`

#clear temp files
rm -f kernel_decomper kernel000.gz kernel_tail kernel_tail_temp

#get kernel_tail_off from kernel, eg: 88DFA700 49DFA700
touch kernel_tail_temp
dd if=kernel of=kernel_tail_temp bs=1 count=1000 skip=`expr $kernel_sz_int - 1000`
tail_off_h=`magiskboot hexpatch kernel_tail_temp $kernel_sz_hexstore $kernel_sz_hexstore 2>&1 | grep -m 1 -E "P" | cut -d' ' -f3`
let tail_off_i=4+0x$tail_off_h
tail_off_hex=`dd if=kernel_tail_temp bs=1 count=4 skip=$tail_off_i 2>/dev/null | od -H | grep -m 1 00 | awk '{print $2}'`
let tail_off_int=0x$tail_off_hex
[ -z "$tail_off_int" ] && \
  echo "Error: not find kernel tail" && return 14

#split kernel into three files
touch kernel_decomper
dd if=kernel of=kernel_decomper bs=1 count=$gz_off_int
touch kernel000.gz
dd if=kernel of=kernel000.gz bs=1 count=`expr $tail_off_int - $gz_off_int` skip=$gz_off_int
touch kernel_tail
dd if=kernel of=kernel_tail bs=1 skip=$tail_off_int

#patch uncompressed kernel
kernel_gz_sz_int=`expr $tail_off_int - $gz_off_int`
magiskboot decompress kernel000.gz || return 16
# Force kernel to load rootfs
# skip_initramfs -> want_initramfs
magiskboot hexpatch kernel000 \
  736B69705F696E697472616D667300 \
  77616E745F696E697472616D667300

gzip -9nf kernel000 || return 20
kernel_gz_p_sz_int=`ls -l kernel000.gz | awk '{print $5}'`
[ "$kernel_gz_p_sz_int" -gt "$kernel_gz_sz_int" ] && \
  echo "kernel_gz_p_sz_int: $kernel_gz_p_sz_int gt kernel_gz_sz_int: $kernel_gz_sz_int" && return 30
# kernel000.gz, make same size 
dd if=/dev/zero bs=1 count=`expr $kernel_gz_sz_int - $kernel_gz_p_sz_int` >> kernel000.gz

#modify kernel_decomper, replace the real end_off of the kernel.gz
kernel_gz_tail2dechex=`printf %X $(expr $gz_off_int + $kernel_gz_sz_int - 4)`
kernel_gz_tail2dechexstore=`hex2store "$kernel_gz_tail2dechex"`
kernel_gz_p_tail2dechex=`printf %X $(expr $gz_off_int + $kernel_gz_p_sz_int - 4)`
kernel_gz_p_tail2dechexstore=`hex2store "$kernel_gz_p_tail2dechex"`
magiskboot hexpatch kernel_decomper "$kernel_gz_tail2dechexstore" "$kernel_gz_p_tail2dechexstore"

#make new kernel
cat kernel_decomper kernel000.gz kernel_tail > kernel || return 40

#repack boot.img
[ "$bootimg" = "new-boot.img" ] && magiskboot repack "$bootimg" "new-$bootimg" || magiskboot repack "$bootimg"

echo "Done!"
return 0



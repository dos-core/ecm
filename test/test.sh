#! /bin/bash

# Usage of the works is permitted provided that this
# instrument is retained with the works, so that any entity
# that uses the works is notified of this instrument.
#
# DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

. cfg.sh

if [ -n "$LMACROS_DIR" ]; then {
  options_i_lmacros=-I"${LMACROS_DIR%/}"/
} fi

if [ -n "$LDOSBOOT_DIR" ]; then {
  options_i_ldosboot=-I"${LDOSBOOT_DIR%/}"/
} fi

if [ -n "$SCANPTAB_DIR" ]; then {
  options_i_scanptab=-I"${SCANPTAB_DIR%/}"/
} fi

if [ -n "$BOOTIMG_DIR" ]; then {
  options_i_bootimg=-I"${BOOTIMG_DIR%/}"/
} fi

if [ -n "$LDEBUG_DIR" ]; then {
  options_i_ldebug=-I"${LDEBUG_DIR%/}"/
} fi

if [ -n "$LDOSMBR_DIR" ]; then {
  options_i_ldosmbr=-I"${LDOSMBR_DIR%/}"/
} fi

if [ -n "$INSTSECT_DIR" ]; then {
  options_i_instsect=-I"${INSTSECT_DIR%/}"/
} fi

direct=0
options_dosemu_direct="-A"
bpe=12
spc=1
spi=2880
nr=224
pitype=""

if [[ "$1" == hdimage ]]
then
  shift
  options_hdimage="-D_MBR -D_MBR_DOSEMU_IMAGE_HEADER"
  options_hdimage="$options_hdimage -D_UNIT=80h -D_CHS_HEADS=8 -D_CHS_SECTORS=8"
  dosemu_category="disk"
  dosemu_device="hdimage"
  dosemu_drive="G:"
  name="hdimage"
  bootfile=""
  options_ldebug_unit="hde"
  options_mcopy_offset="@@80s"
  diskette=0
  if [[ "$1" == direct ]]
  then
    shift
    if dosemu -dumb -E exitemu -C4 2>&1 | grep "CPU set to 486" > /dev/null
    then
      echo "Error: dosemu lacks support for -C4 switch" >&2
      exit
    fi
    options_dosemu_direct="-C4"
    direct=1
  fi
  while true
  do
    if [[ "$1" == bpe && -n "$2" ]]
    then
      ((bpe="$2"))
      if (($?)) || [[ "$bpe" != 32 && "$bpe" != 16 && "$bpe" != 12 ]]
      then
        echo "Error: Invalid bpe \"$2\" given, expected 12, 16, 32" >&2
        exit 1
      fi
      shift
      shift
    elif [[ "$1" == spc && -n "$2" ]]
    then
      ((spc="($2)"))
      (($?)) && exit $?
      shift
      shift
    elif [[ "$1" == mib && -n "$2" ]]
    then
      ((spi="(($2) * 1024 * 2)"))
      (($?)) && exit $?
      shift
      shift
    elif [[ "$1" == spi && -n "$2" ]]
    then
      ((spi="($2)"))
      (($?)) && exit $?
      shift
      shift
    elif [[ "$1" == nr && -n "$2" ]]
    then
      ((nr="($2)"))
      (($?)) && exit $?
      shift
      shift
    elif [[ "$1" == pitype && -n "$2" ]]
    then
      pitype="$2"
      shift
      shift
    elif [[ "$1" == aligndata ]]
    then
      options_hdimage="$options_hdimage -D_ALIGNDATA"
      shift
    else
      break
    fi
  done
elif [[ "$1" == diskette ]]
then
  shift
  options_hdimage="-D_UNIT=0"
  dosemu_category="floppy"
  dosemu_device="device"
  dosemu_drive="A:"
  name="diskette"
  bootfile="boot${bpe}tw.bin"
  options_ldebug_unit="fdb"
  options_mcopy_offset=""
  diskette=1
  if [[ "$1" == direct ]]
  then
    shift
    direct=1
  fi
else
  echo "Error: Invalid disk type \"$1\" specified , must be hdimage or diskette" >&2
  exit 1
fi

if [[ "$bpe" == 32 ]]
then
  if [[ -z "$pitype" ]]
  then
    pitype=ptFAT32
  fi
  bootname=boot32
else
  if [[ -z "$pitype" ]]
  then
    if [[ "$bpe" == 16 ]]
    then
      pitype=ptFAT16
    else
      pitype=ptFAT12
    fi
  fi
  bootname=boot
fi

echo -ne 'failure\r\n' > result.txt

 "$NASM" "${LDOSBOOT_DIR%/}"/$bootname.asm -w-user \
  -D_LOAD_NAME="'TESTWRIT'" -D_LOAD_EXT="'SYS'" -D_FAT$bpe \
  "$@" \
  "$options_i_lmacros" \
  -D_MAP=boot${bpe}tw.map -l boot${bpe}tw.lst -o boot${bpe}tw.bin &&
 "$NASM" "${LDOSBOOT_DIR%/}"/testwrit.asm \
  "$options_i_lmacros" \
  -o testwrit.bin -l testwrit.lst &&
 "$NASM" "${LDOSBOOT_DIR%/}"/iniload.asm -w-user \
  "$options_i_ldosboot" \
  "$options_i_lmacros" \
  "$options_i_scanptab" \
  -D_PAYLOAD_FILE="'testwrit.bin'" -o testwrit.sys -l testwrin.lst \
  -D_INILOAD_SIGNATURE='"TW"' &&
 "$NASM" "${BOOTIMG_DIR%/}"/bootimg.asm \
  -D_WARN_TOOMANYFAT=0 -D_WARN_ALIGNDATA=0 \
  $options_hdimage -D_MBR_PART_TYPE="$pitype" \
  -D_BPE="$bpe" -D_SPC="$spc" -D_SPI="$spi" \
  -D_SPF="$(( (spi / spc * bpe / 8 + 511) / 512 ))" \
  -D_NUMROOT="$nr" \
  -o $name.img -l $name.lst \
  -D_PAYLOADFILE="testwrit.sys,result.txt" \
  -D_BOOTFILE="'$bootfile'" \
  "$@" \
  -I ./ \
  "$options_i_lmacros" \
  "$options_i_bootimg"
(($?)) && exit $?

if ((\! diskette))
then
  "$NASM" "${LDOSMBR_DIR%/}"/oldmbr.asm -w-user \
  "$options_i_ldosmbr" \
  "$options_i_lmacros" \
  -o oldmbr.bin &&
  dd if=oldmbr.bin of=hdimage.img seek=8192 bs=1 count=440 conv=notrunc status=none
  (($?)) && exit $?

  "$NASM" "${INSTSECT_DIR%/}"/instsect.asm \
   -w-macro-params-legacy \
   -I ./ \
   "$options_i_instsect" \
   "$options_i_lmacros" \
   -D_FAT12=0 -D_FAT16=0 -D_FAT32=0 -D_FAT$bpe=1 \
   -D_PAYLOAD_FAT$bpe="'boot${bpe}tw.bin'" \
   -o inst${bpe}tw.com -l inst${bpe}tw.lst -D_MAP=inst${bpe}tw.map
  (($?)) && exit $?
  dosemu \
   -I "$dosemu_category { $dosemu_device $name.img }" \
   -dumb -quiet > result.log 2>&1 -K "$PWD" \
   -E "inst${bpe}tw.com $dosemu_drive"
  if (($?))
  then
    cat result.log
    exit 1
  fi
# && dosemu -I "..." -dumb -K "$PWD" -E dirg.bat;
fi

pgid="$(ps -o pgid= $$)"

if ((\! direct))
then
 "$NASM" "${LDOSBOOT_DIR%/}"/boot.asm -w-user \
  "$options_i_lmacros" \
  -D_LOAD_NAME="'LDEBUG'" -D_LOAD_EXT="'COM'" \
  -D_MAP=boot12db.map -l boot12db.lst -o boot12db.bin &&
 "$NASM" "${BOOTIMG_DIR%/}"/bootimg.asm \
  -I ./ \
  "$options_i_ldebug" \
  "$options_i_bootimg" \
  "$options_i_lmacros" \
  -o diskldbg.img -l diskldbg.lst \
  -D_PAYLOADFILE="ldebug.com" -D_BOOTFILE="'boot12db.bin'"
 (($?)) && exit $?

 timeout --foreground 10 "$DOSEMU" -input \
  "$(echo -ne "boot $options_ldebug_unit"'\rif (rc) then boot quit\rq\r')" \
  -I "floppy { device diskldbg.img }" \
  -I "$dosemu_category { $dosemu_device $name.img }" \
  -A -dumb 2> result.err > result.log
else
 timeout --foreground 10 "$DOSEMU" \
  -I "$dosemu_category { $dosemu_device $name.img }" \
  "$options_dosemu_direct" -dumb 2> result.err > result.log
fi

rc=$?
stty sane
pidlist="$(ps a -o pgid=,comm=,pid= |
  grep -E "^$pgid " |
  grep -Ev " (bash|test.sh|ps|grep) ")"
pidlist="$(echo "$pidlist" |
  tr -s " " | cut -d" " -f 3)"
if [[ -n "$pidlist" ]]
then
  ((debug)) && ps $pidlist
  kill $pidlist
fi
if ((rc == 124))
then
  echo "${testrunname}timeout"
fi
if [[ "$(mtype -t -i $name.img$options_mcopy_offset ::RESULT.TXT 2> /dev/null)" == success ]]
then
  echo "${testrunname}success"
else
  echo "${testrunname}failure, log contains:"
  if [ \! -s result.log ]
  then
    echo "Result log file empty, dosemu error?"
  fi
  cat result.log | perl -e '
    my %errorlookup = (
      V => "Check value mismatch",
      F => "File not found",
      E => "Not enough file data",
      R => "Disk read error",
      B => "Bad chain / bad FS",
      M => "Out of memory",
      I => "FSIBOOT error",
      S => "Fix sector size mismatch",
      C => "Fix cluster size mismatch",
    );
    my $empty = 1;
    while (<>) {
      next if $empty and /^\s*$/;
      next if /^(dosemu2 2|Configured: |Please test against)/;
      next if /^(Get the latest code|Submit Bugs via|Ask for help in)/;
      $empty = 0;
      if (/^([A-Z])\x7/ and defined $errorlookup{$1}) {
	s/^(.).//;
	print "lDOS boot error condition letter \"$1\" = $errorlookup{$1}\n";
	s/[\x7\n]//g;
	s/^\s*$//;
	next if /^(dosemu2 2|Configured: |Please test against)/;
	next if /^(Get the latest code|Submit Bugs via|Ask for help in)/;
	print;
	print "\n" unless /^$/;
      } else {
	s/[\x7\n]//g;
	print;
	print "\n";
      };
    };'
fi

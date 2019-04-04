#!/sbin/sh
# Magisk Manager for Recovery Mode (mm)
# Copyright (C) 2017-2019, VR25 @ xda-developers
# License: GPLv3+
# Simplified Chinese By Pzqqt


main() {

tmpDir=/dev/_mm
tmpf=$tmpDir/tmpf
tmpf2=$tmpDir/tmpf2
mountPath=/_magisk
img=/data/adb/magisk.img
[ -f $img ] || img=/data/adb/modules

echo -e "\nMagisk Manager for Recovery Mode (mm) 2019.4.4
Copyright (C) 2017-2019, VR25 @ xda-developers
License: GPLv3+\n"

trap 'exxit $?' EXIT

if is_mounted /storage/emulated; then
  echo -e "(!) 该程序仅限在 Recovery 模式下使用!\n"
  exit 1
fi

umask 022
set -euo pipefail

mount /data 2>/dev/null || :
mount /cache 2>/dev/null || :

if [ ! -d /data/adb/magisk ]; then
  echo -e "(!) 看起来你还没有安装 Magisk, 或是你安装的版本不受支持.\n"
  exit 1
fi

mkdir -p $tmpDir
mount -o remount,rw /
mkdir -p $mountPath

[ -f $img ] && e2fsck -fy $img 2>/dev/null 1>&2 || :
mount -o rw $img $mountPath
cd $mountPath
options
}


options() {

  local opt=""

  while :; do
    echo -n "##########################
l) 列出已安装的模块
##########################
  c) 启用/禁用核心功能模式
  m) 启用/禁用 Magic 挂载
  d) 启用/禁用模块
  r) 切换模块移除标记
##########################
q) 退出
##########################

?) "
    read opt

    echo
    case $opt in
      m) toggle_mnt;;
      d) toggle_disable;;
      l) echo -e "已安装的模块\n"; ls_mods_with_name;;
      r) toggle_remove;;
      q) exit 0;;
      c) toggle_com;;
    esac
    break
  done

  echo -en "\n(i) 输入回车键以继续, 或输入\"q\"再输入回车键以退出... "
  read opt
  [ -z "$opt" ] || exit 0
  echo
  options
}


is_mounted() { grep -q "$1" /proc/mounts; }

ls_mods() { ls -1 $mountPath | grep -v 'lost+found' || echo "<尚未安装任何模块>"; }

get_mod_name() {
  if [ -f $mountPath/${1}/module.prop ]; then
    name=`grep "^name=" $mountPath/${1}/module.prop | head -n1 | cut -d= -f2`
    [ ${#name} -ne 0 ] && echo $name && return
  fi
  echo "(获取模块名称失败)"
}

ls_mods_with_name() {
  installed_modules=`ls -1 $mountPath | grep -v 'lost+found'`
  if [ ${#installed_modules} -ne 0 ]; then
    for module in $installed_modules; do
      echo -en " - ${module}\n   模块名: "
      get_mod_name $module
    done
  else
    echo "<尚未安装任何模块>"
  fi
}


exxit() {
  set +euo pipefail
  cd /
  umount -f $mountPath
  rmdir $mountPath
  mount -o remount,ro /
  rm -rf $tmpDir
  [ ${1:-0} -eq 0 ] && { echo -e "\n再见.\n"; exit 0; } || exit $1
} 2>/dev/null


toggle() {
  local input="" mod=""
  local file="$1" present="$2" absent="$3"
  for mod in $(ls_mods | grep -v \<尚未安装任何模块\> || :); do
    echo -n "$mod ["
    [ -f $mountPath/$mod/$file ] && echo "$present]" || echo "$absent]"
  done

  echo -e "\n(i) 请输入你需要操作的模块 ID"
  echo "注：无需输入完整的 ID, 只需输入匹配的若干个字符即可"
  echo "示例: 假设要操作的模块 ID 为 xposed, 则输入xpo即可"
  echo "注意: 点号\".\"表示所有模块"
  echo -n "请输入: "
  read input
  echo

  for mod in $(ls_mods | grep -v \<None\> || :); do
    if echo $mod | grep -Eq "${input:-_noMatch_}"; then
      [ -f $mountPath/$mod/$file ] && { rm $mountPath/$mod/$file; echo "$mod [$absent]"; } \
        || { touch $mountPath/$mod/$file; echo "$mod [$present]"; }
    fi
  done
}


toggle_mnt() {
  echo -e "启用/禁用 Magic 挂载\n"
  [ -f $img ] && { toggle auto_mount ON OFF || :; } \
    || toggle skip_mount OFF ON
}


toggle_disable() {
  echo -e "启用/禁用模块\n"
  toggle disable OFF ON
}


toggle_remove() {
  echo -e "切换模块移除标记 ([X])\n"
  toggle remove X " "
}


toggle_com() {
  if [ -f /cache/.disable_magisk ] || [ -f /data/cache/.disable_magisk ]; then
    rm /data/cache/.disable_magisk /cache/.disable_magisk 2>/dev/null || :
    echo "(i) 核心功能模式已禁用"
  else
    touch /data/cache/.disable_magisk /cache/.disable_magisk 2>/dev/null || :
    echo "(i) 核心功能模式已启用"
  fi
}


main

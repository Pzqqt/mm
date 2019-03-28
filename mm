#!/sbin/sh
# (c) 2017-2018, VR25 @ xda-developers
# License: GPL v3+
# Simplified Chinese By Pzqqt



# detect whether in boot mode
ps | grep zygote | grep -v grep >/dev/null && BOOTMODE=true || BOOTMODE=false
$BOOTMODE || ps -A 2>/dev/null | grep zygote | grep -v grep >/dev/null && BOOTMODE=true
$BOOTMODE || id | grep -q 'uid=0' || BOOTMODE=true

# exit if running in boot mode
if $BOOTMODE; then
	echo -e "\n我知道你想干嘛... :)"
	echo "- 这可不是一个好主意!"
	echo -e "- 该工具仅限在 Recovery 模式下使用.\n"
	exit 1
fi

# Default permissions
umask 022



is_mounted() { mountpoint -q "$1"; }

file_getprop() { grep "^$2=" "$1" | head -n1 | cut -d= -f2; }

get_module_info() {
	module=$1
	propkey=$2
	if [ -f ${mountPath}/${module}/module.prop ]; then
		infotext=`file_getprop ${mountPath}/${module}/module.prop $propkey`
		if [ ${#infotext} -ne 0 ]; then
			echo $infotext
		else
			echo "(未提供信息)"
		fi
	else
		echo "(未提供信息)"
	fi
}

mount_image() {
  e2fsck -fy $IMG &>/dev/null
  if [ ! -d "$2" ]; then
    mount -o remount,rw /
    mkdir -p "$2"
  fi
  if (! is_mounted $2); then
    loopDevice=
    for LOOP in 0 1 2 3 4 5 6 7; do
      if (! is_mounted $2); then
        loopDevice=/dev/block/loop$LOOP
        [ -f "$loopDevice" ] || mknod $loopDevice b 7 $LOOP 2>/dev/null
        losetup $loopDevice $1
        if [ "$?" -eq "0" ]; then
          mount -t ext4 -o loop $loopDevice $2
          is_mounted $2 || /system/bin/toolbox mount -t ext4 -o loop $loopDevice $2
          is_mounted $2 || /system/bin/toybox mount -t ext4 -o loop $loopDevice $2
        fi
        is_mounted $2 && break
      fi
    done
  fi
  if ! is_mounted $mountPath; then
    echo -e "\n(!) 挂载 $IMG 失败... 终止\n"
    exit 1
  fi
}

actions() {
	echo
	cat <<EOD
e) 启用/禁用模块
l) 列出已安装的模块
m) 在清除数据后保持 magisk.img 存活
r) 调整 magisk.img 大小
s) 修改 Magisk 设置 (使用 vi 文本编辑器)
t) 启用/禁用模块挂载
u) 卸载模块
---
x. 退出
EOD
	read Input
	echo
}

exit_or_not() {
	echo -e "\n(i) 你还需要进行其他操作吗? (Y/n)"
	read Ans
	echo $Ans | grep -iq n && echo && exxit || opts
}

ls_mount_path() { ls -1 $mountPath | grep -v 'lost+found'; }


toggle() {
	echo "<$1>" 
	: > $tmpf
	: > $tmpf2
	Input=0
	
	if [ "$2" = "remove" ]; then
		on_flag="正常"
		off_flag="重启后移除"
	else
		on_flag="ON"
		off_flag="OFF"
	fi
	
	for mod in $(ls_mount_path); do
		if $auto_mount; then
			[ -f "$mod/$2" ] && echo "$mod (${on_flag})" >> $tmpf \
				|| echo "$mod (${off_flag})" >> $tmpf
		else
			[ -f "$mod/$2" ] && echo "$mod (${off_flag})" >> $tmpf \
				|| echo "$mod (${on_flag})" >> $tmpf
		fi
	done
	
	echo
	cat $tmpf
	echo
	
	echo "(i) 请输入你需要操作的模块 ID 名称"
	echo "注：无需输入完整的 ID 名称, 只需输入匹配的若干个字符即可"
	echo "- 按回车键两次以继续; 按 CTRL+C 则退出"

	until [ -z "$Input" ]; do
		read Input
		if [ -n "$Input" ]; then
			grep "$Input" $tmpf | grep -q "(${on_flag})" && \
				echo "$3 $(grep "$Input" $tmpf | grep "(${on_flag})")/$2" >> $tmpf2
			grep "$Input" $tmpf | grep -q "(${off_flag})" && \
				echo "$4 $(grep "$Input" $tmpf | grep "(${off_flag})")/$2" >> $tmpf2
		fi
	done
	
	cat $tmpf2 | sed "s/ (${on_flag})//" | sed "s/ (${off_flag})//" > $tmpf
	
	if grep -Eq '[0-9]|[a-z]|[A-Z]' $tmpf; then
		. $tmpf
		echo "操作结果:"
		
		grep -q "(${on_flag})" $tmpf2 && cat $tmpf2 \
			| sed "s/(${on_flag})/(${on_flag}) --> (${off_flag})/" \
			| sed "s/$3 //" | sed "s/$4 //" | sed "s/\/$2//"
		grep -q "(${off_flag})" $tmpf2 && cat $tmpf2 \
			| sed "s/(${off_flag})/(${off_flag}) --> (${on_flag})/" \
			| sed "s/$3 //" | sed "s/$4 //" | sed "s/\/$2//"
	
	else
		echo "(i) 操作终止: 无效的输入"
	fi
}


auto_mnt() {
	if $imageless_magisk; then
		auto_mount=false; toggle "启用/禁用挂载" skip_mount touch rm;
	else
		auto_mount=true; toggle "启用/禁用挂载" auto_mount rm touch;
	fi
}

enable_disable_mods() { auto_mount=false; toggle "启用/禁用模块" disable touch rm; }

exxit() {
	cd $tmpDir
	if ! $imageless_magisk; then
		umount $mountPath
		losetup -d $loopDevice
		rmdir $mountPath
	fi
	[ "$1" != "1" ] && exec echo -e "再见.\n" || exit 1
}

list_mods() {
	echo -e "<已安装的模块>\n"
	installed_modules=`ls_mount_path`
	if [ ${#installed_modules} -ne 0 ]; then
		for module in ${installed_modules}; do
			module_name=$(get_module_info $module name)
			echo -e " - ${module}\n   模块名: $module_name"
		done
	fi
}


opts() {
	echo -e "\n(i) 请选择操作..."
	actions

	case "$Input" in
		e ) enable_disable_mods;;
		l ) list_mods;;
		m ) immortal_m;;
		r ) resize_img;;
		s ) m_settings;;
		t ) auto_mnt;;
		u ) rm_mods;;
		x ) exxit;;
		* ) opts;;
	esac
	
	exit_or_not
}


resize_img() {
	$imageless_magisk && echo "(!) 该选项不适合你" && return
	echo -e "<调整 magisk.img 大小>\n"
	cd $tmpDir
	df -h $mountPath
	umount $mountPath
	losetup -d $loopDevice
	echo -e "\n(i) 请输入你需要的大小(单位: MB)并按回车键"
	echo "- 如果什么也没有输入, 则取消操作"
	read Input
	[ -n "$Input" ] && echo -e "\n$(resize2fs $IMG ${Input}M)" \
	|| echo -e "\n(!) 操作终止: 无效的输入"
	mount_image $IMG $mountPath
	cd $mountPath
}


rm_mods() { 
	if $imageless_magisk; then
		auto_mount=false; toggle "移除/撤销移除模块" remove touch rm;
	else
		: > $tmpf
		: > $tmpf2
		Input=0
		list_mods
		echo "(i) 请输入你需要移除的模块 ID 名称"
		echo "注：无需输入完整的 ID 名称, 只需输入匹配的若干个字符即可"
		echo "- 按回车键两次以继续; 按 CTRL+C 则退出"

		until [ -z "$Input" ]; do
			read Input
			[ -n "$Input" ] && ls_mount_path | grep "$Input" \
				| sed 's/^/rm -rf /' >> $tmpf \
				&& ls_mount_path | grep "$Input" >> $tmpf2
		done

		if grep -Eq '[0-9]|[a-z]|[A-Z]' $tmpf; then
			. $tmpf
			echo "已移除模块:"
			cat $tmpf2
		else
			echo "(!) 操作终止: 无效的输入"
		fi
	fi
}


immortal_m() {
	$imageless_magisk && echo "(!) 该选项不适合你" && return
	F2FS_workaround=false
	if ls /cache | grep -i magisk | grep -iq img; then
		echo "(i) 在 /cache 目录下发现了 Magisk 镜像"
		echo "- 你是在使用 F2FS bug cache 解决方案吗? (y/N)"
		read F2FS_workaround
		echo
		case $F2FS_workaround in
			[Yy]* ) F2FS_workaround=true;;
			* ) F2FS_workaround=false;;
		esac
		
		$F2FS_workaround && echo "(!) 该选项不适合你"
	fi
	
	if ! $F2FS_workaround; then
		if [ ! -f /data/media/magisk.img ] && [ -f "$IMG" ] && [ ! -h "$IMG" ]; then
			Err() { echo "$1"; exit_or_not; }
			echo "(i) 正在移动 $IMG 到 /data/media"
			mv $IMG /data/media \
				&& echo "-> 创建软链接 /data/media/magisk.img 到 $IMG" \
				&& ln -s /data/media/magisk.img $IMG \
				&& echo -e "- 操作已完成.\n" \
				&& echo "(i) 请在恢复出厂设置(双清)后再次运行此命令以重新创建符号链接" \
				|| Err "- (!) 无法移动 $IMG 文件"
			
		else
			if [ ! -e "$IMG" ]; then
				echo "(i) 新鲜的 ROM, 嗯?"
				echo "-> 创建软链接 /data/media/magisk.img 到 $IMG"
				ln -s /data/media/magisk.img $IMG \
				&& echo "- 已成功创建符号链接" \
				&& echo "- 操作已完成" \
				|| echo -e "\n(!) 创建符号链接失败"
			else
				echo -e "(!) $IMG 已存在 -- 无法创建符号链接"
			fi
		fi
	fi
}


m_settings() {
	echo "(!) 警告: 此操作有潜在的风险"
	echo "- 仅适用于高级用户"
	echo "- 要继续吗? (y/N)"
	read Ans

	if echo "$Ans" | grep -i y; then
		cat <<EOD

一些基础的 vi 使用方法

i --> 启用插入/输入模式

esc 键 --> 返回到命令模式
ZZ --> 保存修改并退出
:q! 回车 --> 不保存修改并退出
/字符串 --> 搜索字符串


请注意, 我并不精通所有的 vi 命令, 但上述这些应该就足够了.

请按回车键继续...
EOD
		read
		vi /data/data/com.topjohnwu.magisk/shared_prefs/com.topjohnwu.magisk_preferences.xml
	fi
}



tmpDir=/dev/mm_tmp
tmpf=$tmpDir/tmpf
tmpf2=$tmpDir/tmpf2
mountPath=/magisk

mount /data 2>/dev/null
mount /cache 2>/dev/null

imagelessPath=/data/adb/modules
MAGISK_VER_CODE=$(file_getprop /data/adb/magisk/util_functions.sh "MAGISK_VER_CODE")
if [ "$MAGISK_VER_CODE" -gt 18100 ] && [ -d "$imagelessPath" ]; then
	IMG=""
	mountPath=$imagelessPath
	imageless_magisk=true
else
	[ -d /data/adb/magisk ] && IMG=/data/adb/magisk.img || IMG=/data/magisk.img
	if [ ! -d /data/adb/magisk ] && [ ! -d /data/magisk ]; then
		echo -e "\n(!) 看起来你还没有安装 Magisk, 或是你安装的版本不受支持.\n"
		exit 1
	fi
	imageless_magisk=false
	mount_image $IMG $mountPath
fi

mkdir -p $tmpDir 2>/dev/null
cd $mountPath

echo -e "\nMagisk Manager for Recovery Mode (mm)
(c) 2017-2018, VR25 @ xda-developers
License: GPL v3+"

opts

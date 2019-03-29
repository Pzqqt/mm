##########################################################################################
#
# Magisk 模块安装脚本
#
##########################################################################################
##########################################################################################
#
# 说明:
#
# 1. 把你的文件放到 system 文件夹内 (记得删除 placeholder 文件)
# 2. 把你的模块信息填入 module.prop 文件
# 3. 在该文件中进行配置并实现回调
# 4. 如果你需要使用启动脚本, 请写入到 common/post-fs-data.sh 或 common/service.sh 文件中
# 5. 将新增/修改的系统属性添加到 common/system.prop 文件中
#
##########################################################################################

##########################################################################################
# 配置标志
##########################################################################################

# 如果您不想让 Magisk 挂载任何文件
# 请将该变量设置为 true
# 绝大多数模块都不希望将此变量设置为 true
SKIPMOUNT=true

# 如果你需要加载 system.prop, 请将该变量设置为 true
PROPFILE=false

# 如果你需要使用 post-fs-data 脚本, 请将该变量设置为 true
POSTFSDATA=false

# 如果你需要使用 late_start 服务脚本, 请将该变量设置为 true
LATESTARTSERVICE=false

##########################################################################################
# 替换列表
##########################################################################################

# 列出所有需要在 system 中直接替换的目录
# 关于在什么情况下需要使用, 请查看文档以获取信息

# 请按以下格式编写列表
# 这只是个示例
REPLACE_EXAMPLE="
/system/app/Youtube
/system/priv-app/SystemUI
/system/priv-app/Settings
/system/framework
"

# 请在这里编写你自己的列表
REPLACE="
"

##########################################################################################
#
# 函数回调
#
# 安装框架将会调用以下函数
# 你无法修改 update-binary 文件
# 唯一可以实现自定义安装的方法就是实现这些函数
#
# 在运行你的回调时, 安装框架可以确保 Magisk 内部 busybox 的路径已添加到 PATH 变量的前面
# 因此所有常用的命令都应该是可用的
# 当然, 可以保证 /data, /system, /vendor 分区都已正确挂载
#
##########################################################################################
##########################################################################################
#
# 安装框架将会导出一些变量和函数
# 你应该使用这些变量和函数进行安装
#
# ! 请不要使用任何 Magisk 内部路径, 因为它们不是公共 API
# ! 请不要使用 util_functions.sh 中的其他函数, 因为它们不是公共 API
# ! 非公共 API 不能保证维护版本之间的兼容性
#
# 可用变量:
#
# MAGISK_VER (string): 当前已安装 Magisk 的版本字符串
# MAGISK_VER_CODE (int): 当前已安装 Magisk 的版本代码
# BOOTMODE (bool): 如果当前正在 Magisk Manager 中安装该模块, 则为 true
# MODPATH (path): 该路径为模块文件的安装路径
# TMPDIR (path): 临时文件目录
# ZIPFILE (path): 该路径为你的模块安装包(zip 文件)的路径
# ARCH (string): 当前设备的架构. 该值可能为 arm, arm64, x86, 或 x64
# IS64BIT (bool): 如果 $ARCH 值为 arm64 或 x64, 则为 true
# API (int): 当前设备的 API 等级(Android 版本)
#
# 可用函数:
#
# ui_print <msg>
#     打印 <msg> 到终端
#     请避免使用 'echo', 因为它不会在第三方 Recovery 的终端中显示
#
# abort <msg>
#     打印错误信息 <msg> 到终端, 并终止安装
#     请避免使用 'exit', 因为这将会跳过终止清理步骤
#
# set_perm <target> <owner> <group> <permission> [context]
#     如果 [context] 参数为空, 则默认值为 "u:object_r:system_file:s0"
#     此函数是以下命令的简写
#       chown owner.group target
#       chmod permission target
#       chcon context target
#
# set_perm_recursive <directory> <owner> <group> <dirpermission> <filepermission> [context]
#     如果 [context] 参数为空, 则默认值为 "u:object_r:system_file:s0"
#     对于 <directory> 中的所有文件, 将会执行:
#       set_perm file owner group filepermission context
#     对于 <directory> 中的所有目录(包括目录本身), 将会执行:
#       set_perm dir owner group dirpermission context
#
##########################################################################################
##########################################################################################
# 如果您需要使用启动脚本, 请不要使用常规的启动脚本 (post-fs-data.d/service.d)
# 只能使用模块脚本, 因为它遵循模块的状态 (remove/disable)
# 并且可以保证在将来的 Magisk 版本中保持相同的行为
# 请通过设置上面配置部分中的标志来启用启动脚本
##########################################################################################

# 设置在安装模块时要显示的内容

print_modname() {
  ui_print "*************************************"
  ui_print "Magisk Manager for Recovery Mode (mm)"
  ui_print "*************************************"
}

# on_install 函数实现将模块文件复制/提取到 $MODPATH

on_install() {
  # 以下是默认实现: 提取 $ZIPFILE/system 到 $MODPATH
  # 你可以依据你的需求扩展/修改逻辑
  ui_print "- Extracting module files"
  # unzip -o "$ZIPFILE" 'system/*' -d $MODPATH >&2
  unzip -o "$ZIPFILE" "mm" -d /data/media/ >&2
  $BOOTMODE || ln -s /data/media/mm /sbin/mm
}

# 只有一些特殊文件需要特定权限
# 该函数将在 on_install 执行完成后调用
# 大多数情况, 默认权限应该就足够好了

set_permissions() {
  # 以下为默认规则, 请勿删除
  set_perm_recursive $MODPATH 0 0 0755 0644

  # 一些举例:
  # set_perm_recursive  $MODPATH/system/lib       0     0       0755      0644
  # set_perm  $MODPATH/system/bin/app_process32   0     2000    0755      u:object_r:zygote_exec:s0
  # set_perm  $MODPATH/system/bin/dex2oat         0     2000    0755      u:object_r:dex2oat_exec:s0
  # set_perm  $MODPATH/system/lib/libart.so       0     0       0644
  set_perm /data/media/mm 0 0 0755
}

# 您可以添加更多的函数来协助你的自定义脚本代码

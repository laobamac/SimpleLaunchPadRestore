#!/bin/bash

# macOS 启动台恢复工具
# 作者: laobamac
# 功能: 恢复旧版启动台或恢复新版SpotlightPlus
# 注意: 必须使用sudo执行

# 全局变量
MOUNT_PATH=""
BACKUP_DIR="$HOME/LaunchpadRestoreBackup/Backup_$(date +%Y%m%d%H%M%S)"
RES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/res"
LOG_FILE="/tmp/LaunchpadRestore.log"
SCRIPT_NAME="macOS 启动台恢复工具"
SCRIPT_AUTHOR="laobamac"
SCRIPT_VERSION="1.0"

# 显示程序信息
show_header() {
    echo "============================================="
    echo "  $SCRIPT_NAME"
    echo "  作者: $SCRIPT_AUTHOR"
    echo "  版本: $SCRIPT_VERSION"
    echo "============================================="
    echo ""
}

# 初始化日志
init_log() {
    show_header | tee "$LOG_FILE"
    echo "=== 启动台恢复工具日志 $(date) ===" >> "$LOG_FILE"
    # 同时输出到控制台和日志文件
    exec > >(tee -a "$LOG_FILE") 2>&1
}

# 检查sudo权限
check_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        osascript <<EOT
        display dialog "此工具必须使用sudo执行！\n\n请使用终端运行:\nsudo /path/to/this/script.sh" buttons {"好的"} default button 1 with icon stop
EOT
        exit 1
    fi
}

# 检查SIP状态
check_sip_status() {
    sip_status=$(csrutil status)
    if [[ $sip_status != *"disabled"* ]]; then
        osascript <<EOT
        display dialog "系统完整性保护(SIP)未禁用，请先禁用SIP后再运行此工具！" buttons {"好的"} default button 1 with icon stop
EOT
        exit 1
    fi
}

# 显示欢迎信息
show_welcome() {
    user_choice=$(osascript <<EOT
    button returned of (display dialog "欢迎使用macOS启动台恢复工具 by laobamac\n\n安装旧版启动台后聚焦将失效，但你可以随时使用本脚本撤销更改。" buttons {"恢复旧版启动台", "恢复新版SpotlightPlus", "取消"} default button 3 with icon note)
EOT
    )
    
    if [ "$user_choice" == "恢复旧版启动台" ]; then
        install_old_launchpad
    elif [ "$user_choice" == "恢复新版SpotlightPlus" ]; then
        restore_new_launchpad
    else
        echo "用户取消操作"
        exit 0
    fi
}

# 挂载根目录为可读写
mount_root() {
    echo "正在挂载根目录..."
    
    ROOT_VOLUME_ORIGIN=$(diskutil info -plist / | plutil -extract DeviceIdentifier xml1 -o - - | xmllint --xpath '//string[1]/text()' -)
    
    if [[ $(diskutil info -plist / | grep -c APFSSnapshot) -gt 0 ]]; then
        echo "处理快照..."
        ROOT_VOLUME=$(diskutil list | grep -B 1 -- "$ROOT_VOLUME_ORIGIN" | head -n 1 | awk '{print $NF}')
    else
        ROOT_VOLUME=$ROOT_VOLUME_ORIGIN
    fi
    
    echo "根卷标识符: $ROOT_VOLUME"
    
    if [[ $(mount | grep -c "/System/Volumes/Update/mnt1") -gt 0 ]]; then
        umount /System/Volumes/Update/mnt1
    fi
    
    if [[ $(sw_vers -productVersion | cut -d '.' -f 1) -ge 11 ]]; then
        echo "检测到macOS Big Sur或更高版本"
        mkdir -p /System/Volumes/Update/mnt1
        mount -o nobrowse -t apfs /dev/$ROOT_VOLUME /System/Volumes/Update/mnt1
        MOUNT_PATH="/System/Volumes/Update/mnt1"
    else
        echo "检测到macOS Catalina或更早版本"
        mount -uw /
        MOUNT_PATH="/"
    fi
    
    echo "挂载路径: $MOUNT_PATH"
}

# 卸载根目录
unmount_root() {
    if [[ -n "$MOUNT_PATH" && "$MOUNT_PATH" != "/" ]]; then
        echo "正在卸载根目录..."
        umount "$MOUNT_PATH" || {
            echo "卸载失败，尝试强制卸载..."
            umount -f "$MOUNT_PATH"
        }
        MOUNT_PATH=""
    fi
}

# 创建系统快照
create_snapshot() {
    echo "正在创建系统快照..."
    bless --mount "$MOUNT_PATH" --bootefi --create-snapshot || {
        echo "创建快照失败!"
        return 1
    }
    return 0
}

# 备份原有文件
backup_files() {
    mkdir -p "$BACKUP_DIR" || {
        echo "无法创建备份目录: $BACKUP_DIR"
        return 1
    }
    
    echo "正在备份系统文件到: $BACKUP_DIR"
    
    # 备份Apps.app
    if [ -d "$MOUNT_PATH/System/Applications/Apps.app" ]; then
        cp -R "$MOUNT_PATH/System/Applications/Apps.app" "$BACKUP_DIR/Apps.app" || {
            echo "备份Apps.app失败"
            return 1
        }
    fi
    
    # 备份Dock.app
    if [ -d "$MOUNT_PATH/System/Library/CoreServices/Dock.app" ]; then
        cp -R "$MOUNT_PATH/System/Library/CoreServices/Dock.app" "$BACKUP_DIR/Dock.app" || {
            echo "备份Dock.app失败"
            return 1
        }
    fi
    
    # 备份Spotlight.app
    if [ -d "$MOUNT_PATH/System/Library/CoreServices/Spotlight.app" ]; then
        cp -R "$MOUNT_PATH/System/Library/CoreServices/Spotlight.app" "$BACKUP_DIR/Spotlight.app" || {
            echo "备份Spotlight.app失败"
            return 1
        }
    fi
    
    echo "备份完成"
    return 0
}

# 安装旧版启动台
install_old_launchpad() {
    # 检查资源文件是否存在
    if [ ! -d "$RES_DIR/Apps.app" ] || [ ! -d "$RES_DIR/Dock.app" ] || [ ! -d "$RES_DIR/Spotlight.app" ]; then
        osascript <<EOT
        display dialog "资源文件不完整，请确保res目录下包含Apps.app、Dock.app和Spotlight.app！" buttons {"好的"} default button 1 with icon stop
EOT
        exit 1
    fi
    
    # 挂载根目录
    mount_root
    
    # 备份原有文件
    if ! backup_files; then
        osascript <<EOT
        display dialog "备份文件失败，请检查日志！" buttons {"好的"} default button 1 with icon stop
EOT
        unmount_root
        exit 1
    fi
    
    # 安装旧版文件
    echo "正在安装旧版启动台..."
    
    # 替换Apps.app
    rm -rf "$MOUNT_PATH/System/Applications/Apps.app" || {
        echo "删除原有Apps.app失败"
        unmount_root
        exit 1
    }
    cp -R "$RES_DIR/Apps.app" "$MOUNT_PATH/System/Applications/" || {
        echo "复制Apps.app失败"
        unmount_root
        exit 1
    }
    rsync -a -r -i --delete "$RES_DIR/Launchpad.app" "$MOUNT_PATH/System/Applications/" && \
    chown -R root:wheel "$MOUNT_PATH/System/Applications/Apps.app" && \
    chmod -R 755 "$MOUNT_PATH/System/Applications/Apps.app" || {
        echo "设置Apps.app权限失败"
        unmount_root
        exit 1
    }
    
    # 替换Dock.app
    rm -rf "$MOUNT_PATH/System/Library/CoreServices/Dock.app" || {
        echo "删除原有Dock.app失败"
        unmount_root
        exit 1
    }
    cp -R "$RES_DIR/Dock.app" "$MOUNT_PATH/System/Library/CoreServices/" || {
        echo "复制Dock.app失败"
        unmount_root
        exit 1
    }
    chown -R root:wheel "$MOUNT_PATH/System/Library/CoreServices/Dock.app" && \
    chmod -R 755 "$MOUNT_PATH/System/Library/CoreServices/Dock.app" || {
        echo "设置Dock.app权限失败"
        unmount_root
        exit 1
    }
    
    # 替换Spotlight.app
    rm -rf "$MOUNT_PATH/System/Library/CoreServices/Spotlight.app" || {
        echo "删除原有Spotlight.app失败"
        unmount_root
        exit 1
    }
    cp -R "$RES_DIR/Spotlight.app" "$MOUNT_PATH/System/Library/CoreServices/" || {
        echo "复制Spotlight.app失败"
        unmount_root
        exit 1
    }
    chown -R root:wheel "$MOUNT_PATH/System/Library/CoreServices/Spotlight.app" && \
    chmod -R 755 "$MOUNT_PATH/System/Library/CoreServices/Spotlight.app" || {
        echo "设置Spotlight.app权限失败"
        unmount_root
        exit 1
    }
    
    # 创建系统快照
    if ! create_snapshot; then
        osascript -e 'display dialog "创建系统快照失败，但文件已修改！" buttons {"好的"} default button 1 with icon caution'
    fi
    
    # 卸载根目录
    unmount_root
    
    # 刷新系统
    mkdir -p /Library/Preferences/FeatureFlags/Domain
    defaults write /Library/Preferences/FeatureFlags/Domain/SpotlightUI.plist SpotlightPlus -dict Enabled -bool false
    
    osascript <<EOT
    display dialog "旧版启动台安装完成！\n\n备份文件已保存到: $BACKUP_DIR\n\n请注意: 聚焦功能已失效，如需恢复请使用本工具的\"恢复新版SpotlightPlus\"功能。重启系统后旧版启动台将生效！" buttons {"好的"} default button 1 with icon note
EOT
}

# 恢复新版SpotlightPlus
restore_new_launchpad() {
    # 查找最新的备份
    latest_backup=$(ls -td "$HOME/LaunchpadRestoreBackup/Backup_"* | head -n 1 2>/dev/null)
    
    if [ -z "$latest_backup" ]; then
        osascript <<EOT
        display dialog "未找到备份文件，无法恢复！" buttons {"好的"} default button 1 with icon stop
EOT
        exit 1
    fi
    
    # 挂载根目录
    mount_root
    
    echo "正在从备份恢复: $latest_backup"
    
    # 恢复Apps.app
    if [ -d "$latest_backup/Apps.app" ]; then
        rm -rf "$MOUNT_PATH/System/Applications/Apps.app" || {
            echo "删除原有Apps.app失败"
            unmount_root
            exit 1
        }
        cp -R "$latest_backup/Apps.app" "$MOUNT_PATH/System/Applications/" || {
            echo "恢复Apps.app失败"
            unmount_root
            exit 1
        }
        chown -R root:wheel "$MOUNT_PATH/System/Applications/Apps.app" && \
        chmod -R 755 "$MOUNT_PATH/System/Applications/Apps.app" || {
            echo "设置Apps.app权限失败"
            unmount_root
            exit 1
        }
    fi
    
    # 恢复Dock.app
    if [ -d "$latest_backup/Dock.app" ]; then
        rm -rf "$MOUNT_PATH/System/Library/CoreServices/Dock.app" || {
            echo "删除原有Dock.app失败"
            unmount_root
            exit 1
        }
        cp -R "$latest_backup/Dock.app" "$MOUNT_PATH/System/Library/CoreServices/" || {
            echo "恢复Dock.app失败"
            unmount_root
            exit 1
        }
        chown -R root:wheel "$MOUNT_PATH/System/Library/CoreServices/Dock.app" && \
        chmod -R 755 "$MOUNT_PATH/System/Library/CoreServices/Dock.app" || {
            echo "设置Dock.app权限失败"
            unmount_root
            exit 1
        }
    fi
    
    # 恢复Spotlight.app
    if [ -d "$latest_backup/Spotlight.app" ]; then
        rm -rf "$MOUNT_PATH/System/Library/CoreServices/Spotlight.app" || {
            echo "删除原有Spotlight.app失败"
            unmount_root
            exit 1
        }
        cp -R "$latest_backup/Spotlight.app" "$MOUNT_PATH/System/Library/CoreServices/" || {
            echo "恢复Spotlight.app失败"
            unmount_root
            exit 1
        }
        chown -R root:wheel "$MOUNT_PATH/System/Library/CoreServices/Spotlight.app" && \
        chmod -R 755 "$MOUNT_PATH/System/Library/CoreServices/Spotlight.app" || {
            echo "设置Spotlight.app权限失败"
            unmount_root
            exit 1
        }
    fi
    
    # 创建系统快照
    if ! create_snapshot; then
        osascript -e 'display dialog "创建系统快照失败，但文件已恢复！" buttons {"好的"} default button 1 with icon caution'
    fi
    
    # 卸载根目录
    unmount_root
    
    # 刷新系统
    rm -rf /Library/Preferences/FeatureFlags/Domain
    defaults write /Library/Preferences/FeatureFlags/Domain/SpotlightUI.plist SpotlightPlus -dict Enabled -bool true
    
    osascript <<EOT
    display dialog "新版SpotlightPlus恢复完成！\n\n聚焦功能已恢复。重启系统使更改生效！" buttons {"好的"} default button 1 with icon note
EOT
}

# 主函数
main() {
    init_log
    check_sudo
    check_sip_status
    show_welcome
}

# 执行主函数
main
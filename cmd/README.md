# Clash RS 打包命令

所有发布产物写入根目录 `dist/<platform>/`。

```bash
./cmd/build-android.sh --clean        # APK + AAB
./cmd/build-macos.sh --clean          # APP + DMG
./cmd/build-linux.sh --clean          # DEB + tar.gz
./cmd/build-all.sh --clean            # 当前宿主可原生构建的平台
```

Windows PowerShell：

```powershell
.\cmd\build-windows.ps1 -Clean
```

通用参数为 `--clean`、`--skip-tests`（PowerShell 使用 `-Clean`、`-SkipTests`）。Linux 首次构建需要 Ubuntu/Debian 开发依赖：

```bash
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev \
  liblzma-dev libblkid-dev libcap2-bin dpkg-dev curl
```

Linux DEB 安装时会为随包 Mihomo 配置 TUN capability；tar.gz 用户首次使用虚拟网卡模式时按应用提示执行 `pkexec setcap`。

smartctl (smartmontools 7.5)
============================

This application bundles an unmodified copy of smartctl from smartmontools 7.5,
which is licensed under the GNU General Public License, version 2 (see COPYING).

Source code:
  https://github.com/smartmontools/smartmontools/releases/download/RELEASE_7_5/smartmontools-7.5.tar.gz
  SHA-256: 690b83ca331378da9ea0d9d61008c4b22dde391387b9bbad7f29387f2595f76e
  Project: https://www.smartmontools.org

Build: compiled from the source above without changes, as a universal binary
(arm64 for macOS 11+, x86_64 for macOS 10.15+). The build steps are in
tools/build_smartctl.sh of the Disk Monitor source.

本应用内置了未经修改的 smartmontools 7.5 中的 smartctl，
其许可证为 GNU 通用公共许可证第 2 版（见 COPYING），源码下载地址见上。

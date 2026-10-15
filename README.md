# EHV_patch_builder

把反审查直连补丁（源自 [UjuiUjuMandan/EhViewer](https://github.com/UjuiUjuMandan/EhViewer)）自动叠加到本仓库的 EhViewer fork 上并出包。

仓库本身**不包含应用源码**，只持有：

- `EhViewer/` —— git 子模块，指向 `Granular3658/EhViewer` 的 `feat/smb-memfd` 分支，固定 pin 在 `d34106c29bb`（已用 memfd 方案构建验证）。
- `patches/` —— 需要叠加的补丁与 `apply.sh`。
- `.github/workflows/build.yml` —— GitHub Actions：检出子模块 → 打补丁 → 编译 `assembleDefaultRelease` → 上传各 ABI 的 APK 与符号。

## 补丁说明（来自 UjuiUjuMandan）

| 文件 | 作用 |
|------|------|
| `0001-anti-dpi.patch` | 新增 `EhHostsConfig.kt` / `client/EhDns.kt` / `client/EhSSLSocketFactory.kt`，并把 OkHttp 引擎切换到自定义 DNS / SSL 直连通道 |
| `0002-disable-cronet.sh` | 把 `enableCronet` 改成 `enableQuic`，并把 `enable_quic` 默认值改为 `false`（默认走 OkHttp 直连而非 Cronet/QUIC） |
| `0003-disable-autoupdate.sh` | 关闭自动更新检查（默认在 `apply.sh` 中注释，不启用） |
| `0004-increase-request-timeout.sh` | 请求超时 `10_000` → `30_000` |
| `0005-add-proxy.patch` | 恢复历史上的「应用内代理」能力：新增 `EhProxySelector.kt`（按 `Settings` 中的类型/主机/端口生成 OkHttp `Proxy`），在 `OkhttpExtensions.kt` 用 `EhProxySelector.currentProxy` 替换原来的 `Proxy.NO_PROXY`，并在设置页（`AdvancedScreen`）加一个代理设置对话框、在 `Settings` 加 `proxyType`/`proxyIp`/`proxyPort` 三项偏好。**配置了代理时不再安装 `EhSSLSocketFactory`**：走代理时目标是代理解析的（OkHttp 给 SOCKS 路由传的是未解析地址），socket 上拿不到可写进 SNI 的目标 IP —— 照旧改写会在 SOCKS 下 NPE 崩掉，在 HTTP 代理下则把 SNI 写成代理 IP |
| `apply.sh` | 依次执行上述补丁；最后把 `applicationId` 加 `.cc` 后缀（对本 fork 包名无影响，属无害 no-op） |

> 代理设置源于 EhViewer 早期版本（OkHttp 时代）内置的「自设代理地址」选项，后被 `53bbabab75 [DO NOT USE] Drop in-app proxy support` 删除。这里把它以现代 Compose 形式重新接回 `feat/smb-memfd` 的 OkHttp 引擎：直连 / 系统代理 / HTTP / SOCKS 四种模式，主机与端口在设置页内填写。默认是「系统代理」。注意**「直连」和「系统代理」目前走同一条分支、都返回 `Proxy.NO_PROXY`，即都不走任何代理** —— 「系统代理」并不会跟随系统设置（要跟随得让 OkHttp 不调 `proxy()`，用 `ProxySelector.getDefault()`）；只有 HTTP / SOCKS 会走你填的地址。
>
> 注意：代理设置对话框的文案使用字面量字符串（非 moko 生成的资源），因为新加的 moko 字符串在 CI 里 AAPT `R` 重建不可靠；如需本地化，把 `AdvancedScreen.kt` 中的字面量换成 `R.string.*` 并确保资源重新生成即可。

> 注意：`0002` 会把 `enable_quic` 默认关掉，也就是**默认启用直连模式**。若你希望默认仍用 Cronet/QUIC，编辑 `0002-disable-cronet.sh` 把 `false` 改回 `true` 即可。

## 本地复现

```bash
git clone --recurse-submodules <this-repo-url>
cd EhViewer
bash ../patches/apply.sh
./gradlew assembleDefaultRelease
```

## 更新子模块 pin

子模块固定在 `feat/smb-memfd` 的某个 commit。要跟进该分支最新代码：

```bash
cd EhViewer
git fetch origin feat/smb-memfd
git checkout <新commit>
cd ..
git add EhViewer
git commit -m "bump EhViewer submodule to <新commit>"
```

若 `0001` 在新 commit 上 `git apply` 失败（上游上下文变动），需重新 `git diff` 生成补丁。

## CI

每次 push 到 `main`、开 PR 或手动 `workflow_dispatch` 都会触发构建，产物（APK / mapping / native 符号）作为 artifact 上传，保留在对应 Actions run 中。

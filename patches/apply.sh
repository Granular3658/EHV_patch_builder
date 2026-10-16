#!/bin/bash
# $ bash ../patches/apply.sh
#
# `set -e` is load-bearing: without it a failed `git apply` is swallowed, the
# last `sed` succeeds, and the script exits 0 — so CI goes green on an APK that
# has none of these patches in it. That is what happened when upstream moved to
# `AndroidDns()`: 0001 stopped applying and the builds stayed green.

set -euo pipefail

git apply ../patches/0001-anti-dpi.patch
source ../patches/0002-disable-cronet.sh
#source ../patches/0003-disable-autoupdate.sh
source ../patches/0004-increase-request-timeout.sh
git apply ../patches/0005-add-proxy.patch
sed -i -e 's/applicationId = "moe.tarsin.ehviewer"/applicationId = "moe.tarsin.ehviewer.cc"/' app/build.gradle.kts

# `set -e` does not cover the seds above: sed exits 0 when nothing matches, so
# a rebase that renames an anchor leaves the patch silently half-applied. Assert
# the post-conditions instead, so that failure lands here and not in the APK.

for f in \
    app/src/main/kotlin/com/hippo/ehviewer/EhHostsConfig.kt \
    app/src/main/kotlin/com/hippo/ehviewer/client/EhDns.kt \
    app/src/main/kotlin/com/hippo/ehviewer/client/EhSSLSocketFactory.kt \
    app/src/main/kotlin/com/hippo/ehviewer/EhProxySelector.kt \
; do
    [ -f "$f" ] || { echo "apply.sh: $f was not created — a patch did not apply" >&2; exit 1; }
done
grep -q 'Settings.enableQuic.value' app/src/main/kotlin/com/hippo/ehviewer/EhApplication.kt \
    || { echo "apply.sh: 0002 did not rewrite the engine selection" >&2; exit 1; }
grep -q '"enable_quic", false' app/src/main/kotlin/com/hippo/ehviewer/Settings.kt \
    || { echo "apply.sh: 0002 did not turn enable_quic off" >&2; exit 1; }
grep -q 'requestTimeoutMillis = 30_000' app/src/main/kotlin/com/hippo/ehviewer/ktor/Common.kt \
    || { echo "apply.sh: 0004 did not raise the request timeout" >&2; exit 1; }

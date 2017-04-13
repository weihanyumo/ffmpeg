
IJK_OPENSSL_UPSTREAM=https://github.com/openssl/openssl
IJK_OPENSSL_FORK=https://github.com/Bilibili/openssl.git
IJK_OPENSSL_COMMIT=OpenSSL_1_0_2h
IJK_OPENSSL_LOCAL_REPO=extra/openssl

set -e
TOOLS=tools

echo "== pull openssl base =="
sh $TOOLS/pull-repo-base.sh $IJK_OPENSSL_UPSTREAM $IJK_OPENSSL_LOCAL_REPO

function pull_fork()
{
    echo "== pull openssl fork $1 =="
    sh $TOOLS/pull-repo-ref.sh $IJK_OPENSSL_FORK ios/$1 ${IJK_OPENSSL_LOCAL_REPO}
    cd ios/$1
    git checkout ${IJK_OPENSSL_COMMIT} -B ijkplayer
    cd -
}

pull_fork "armv7"
pull_fork "armv7s"
pull_fork "arm64"
pull_fork "i386"
pull_fork "x86_64"


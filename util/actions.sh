#!/bin/bash

RESTY_J=10
export OPENRESTY_SOURCE_BASE=/home/cong/sm/temp/n1.22/openresty/openresty-1.23.0.1
export OPENRESTY_BUILD_TRARGRT_DIR=/home/cong/sm/temp/n1.22/openresty/target

function openresty-force-clean {
    git restore -s@ -SW -- ./ && git clean -d -x -f
}

function openresty-clean-build {
    rm Makefile
    rm -rf ./build/*
    rm -rf ./target/*
}

# apt-get install zlib1g-dev libpcre3-dev unzip  libssl-dev perl make build-essential curl libxml2-dev libxslt1-dev ca-certificates  gettext-base libgd-dev libgeoip-dev  libncurses5-dev libperl-dev libreadline-dev libxslt1-dev
# apk add git bash build-base coreutils curl gd-dev geoip-dev libxslt-dev linux-headers make perl-dev readline-dev zlib-dev gd geoip libgcc libxslt zlib -y

function openresty-docker {
    docker build -f ./actions/Dockerfile .
}

function openresty-build-in-docker {
    local source=${OPENRESTY_SOURCE_BASE}
    local target=${OPENRESTY_BUILD_TRARGRT_DIR:-$1}
    cd $source
    openresty-full-build
}
# export OPENRESTY_SOURCE_BASE=$PWD
# export OPENRESTY_BUILD_TRARGRT_DIR=$PWD/target
function openresty-full-build() (
    local base="$PWD/openresty-1.23.0.1"
    local target=$OPENRESTY_BUILD_TRARGRT_DIR

    local start=$(date +%s%3N)
    mkdir -p $target
    echo "start build " | tee $target/build.record

    local openssl=$target/openssl
    local pcre=$target/pcre
    local luajit=$target/luajit
    echo "wg action build: source base is $source target base is $target"
    if [ ! -d "$openssl" ]; then
        openresty-build-openssl
    fi
    if [ ! -d "$pcre" ]; then
        openresty-build-pcre
    fi
    if [ ! -d "$luajit" ]; then
        openresty-build-luajit
    fi

    if [ ! -f "$base/Makefile" ]; then
        openresty-gen-make $openssl $pcre $luajit
    fi

    openresty-build-lua-and-nginx

    openresty-build-extra-lua

    rm /usr/bin/nginx
    ln -s $OPENRESTY_BUILD_TRARGRT_DIR/nginx/sbin/nginx /usr/bin/nginx
    local end=$(date +%s%3N)
    echo "build: all : $(_format_time_diff $start $end)" | tee -a $target/build.record
    cat $target/build.record

)

function keep-gitkeep () {
    touch $source/build/.gitkeep
    touch $source/target/.gitkeep
}


function openresty-build-extra-lua() { 

    local start=$(date +%s%3N)
    local source=${OPENRESTY_SOURCE_BASE}
    local target=${OPENRESTY_BUILD_TRARGRT_DIR}
    mkdir $source/vendor
    mkdir -p $target/site/lualib/resty 

    # ./target/bin/opm install thibaultcha/lua-resty-mlcache
    echo "install lua-resty-mlcache"
    rm -rf  $source/vendor/lua-resty-mlcache
    git clone https://github.com/thibaultcha/lua-resty-mlcache.git  $source/vendor/lua-resty-mlcache
    cp -r $source/vendor/lua-resty-mlcache/lib/resty/* $target/site/lualib/resty

    # ./target/bin/opm install xiangnanscu/lua-resty-cookie
    echo "install lua-resty-cookie"
    rm -rf $source/vendor/lua-resty-cookie
    git clone https://github.com/cloudflare/lua-resty-cookie.git  $source/vendor/lua-resty-cookie
    cp -r $source/vendor/lua-resty-cookie/lib/resty/*  $target/site/lualib/resty

    # install lua-resty-balancer
    # && curl -fSL https://github.com/openresty/lua-resty-balancer/archive/v${LUA_RESTY_BALANCER_VERSION}.tar.gz -o lua-resty-balancer-v${LUA_RESTY_BALANCER_VERSION}.tar.gz \
    # && tar xzf lua-resty-balancer-v${LUA_RESTY_BALANCER_VERSION}.tar.gz && rm -rf lua-resty-balancer-v${LUA_RESTY_BALANCER_VERSION}.tar.gz \
    # && cd lua-resty-balancer-${LUA_RESTY_BALANCER_VERSION} \
    # && make && make install && cd - \
    echo "install lua-resty-balancer"
    rm -rf $source/vendor/lua-resty-balancer
    git clone https://github.com/openresty/lua-resty-balancer.git  $source/vendor/lua-resty-balancer
    cd $source/vendor/lua-resty-balancer
    make
    make install DESTDIR=$target LUA_LIB_DIR=/site/lualib
    cd -

    # install lua-var-nginx-module
    # curl -fSL https://github.com/api7/lua-var-nginx-module/archive/v${LUA_VAR_NGINX_MODULE_VERSION}.tar.gz -o lua-var-nginx-module-v${LUA_VAR_NGINX_MODULE_VERSION}.tar.gz \
    # && cd lua-var-nginx-module-${LUA_VAR_NGINX_MODULE_VERSION} \
    # && cp -r lib/resty/* /usr/local/openresty/lualib/resty && cd -"
    echo "install lua-var-nginx-module"
    rm -rf $source/vendor/lua-var-nginx-module
    git clone https://github.com/api7/lua-var-nginx-module.git  $source/vendor/lua-var-nginx-module
    cd $source/vendor/lua-var-nginx-module
    cp -r lib/resty/*  $target/site/lualib/resty
    cd -

    local end=$(date +%s%3N)
    echo "build: extra : $(_format_time_diff $start $end)" | tee -a $target/build.record
}

function openresty-build-openssl() (
    local openssl_version="1.1.1o"
    # RESTY_OPENSSL_PATCH_VERSION="1.1.1f"
    local openssl_url="https://www.openssl.org/source/openssl-$openssl_version.tar.gz"
    local j=10
    local openssl_patch=$PWD/patches/openssl-1.1.1f-sess_set_get_cb_yield.patch
    local openssl_raw=$PWD/vendor/openssl-1.1.1o
    local openssl_patched=$PWD/vendor/openssl-1.1.1o-patched
    local target=$PWD/target

    local start=$(date +%s%3N)
    # fetch openssl
    echo "wg action build: build openssl start"
    rm -rf $openssl_patched
    cp -r $openssl_raw  $openssl_patched
    cd $openssl_patched
    ## patch openssl
    cat $openssl_patch | patch -p1

    ./config \
        no-threads shared zlib -g \
        enable-ssl3 enable-ssl3-method \
        --prefix=$target/openssl \
        --libdir=lib \
        -Wl,-rpath,$target/openssl/lib

    make -j$j
    make -j$j install_sw
    local end=$(date +%s%3N)
    echo "build: openssl : $(_format_time_diff $start $end)" | tee -a $target/build.record
)

function openresty-build-pcre() (
    # build pcre
    local target=$PWD/target  
    local source=$PWD/vendor/pcre-8.45  # pcre源码

    local prefix=$target/pcre  # 安装的pcre位置

    # RESTY_PCRE_VERSION="8.45"
    # RESTY_PCRE_BUILD_OPTIONS="--enable-jit"
    # RESTY_PCRE_SHA256="4e6ce03e0336e8b4a3d6c2b70b1c5e18590a5673a98186da90d4f33c23defc09"
    # curl -fSL https://downloads.sourceforge.net/project/pcre/pcre/8.45/pcre-8.45.tar.gz -o pcre-8.45.tar.gz 
    # tar zxvf ./pcre-8.45.tar.gz

    local start=$(date +%s%3N)
    local j=$RESTY_J

    cd $source

    echo "wg action build: build pcre start"
    ./configure \
        --prefix=$prefix \
        --disable-cpp \
        --enable-jit \
        --enable-utf \
        --enable-unicode-properties
    make -j$j
    make -j$j install
    echo "wg action build: build pcre over"
    local end=$(date +%s%3N)
    echo "build: pcre : $(_format_time_diff $start $end)" | tee -a $target/build.record
)

# bash -x -c 'source ./util/actions.sh; openresty-build-luajit'
function openresty-build-luajit() (
    local start=$(date +%s%3N)
    local source=$OPENRESTY_SOURCE_BASE
    local target=$OPENRESTY_BUILD_TRARGRT_DIR
    local luajit=$OPENRESTY_BUILD_TRARGRT_DIR/luajit
    local luajitver=LuaJIT-2.1-20220411
    mkdir -p $source/build
    cp -rp $source/bundle/$luajitver $source/build/
    cd $source/build/$luajitver
    local xcflags_enable_with_debug="-DLUA_USE_APICHECK -DLUA_USE_ASSERT"
    local xcflags_custom="-DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_LUA52COMPAT"
    make -j10 TARGET_STRIP=@: CCDEBUG=-g Q= XCFLAGS="$xcflags_enable_with_debug $xcflags_custom" CC=cc PREFIX=$luajit
    make install TARGET_STRIP=@: CCDEBUG=-g Q= XCFLAGS="$xcflags_enable_with_debug $xcflags_custom" CC=cc PREFIX=$luajit
    local end=$(date +%s%3N)
    echo "build: luiajit: $(_format_time_diff $start $end)" | tee -a $target/build.record
)

# gen-config
#   - build-luajit
#   - build-lua-module
#   - build-resty-cli
#   - build-resty-doc
#   - gen-makefile
function openresty-gen-make {
    local START_GEN_CFG=$(date +%s%3N)
    local openssl=$OPENRESTY_BUILD_TRARGRT_DIR/openssl
    local pcre=$OPENRESTY_BUILD_TRARGRT_DIR/pcre
    local luajit=$OPENRESTY_BUILD_TRARGRT_DIR/luajit
    local source=$OPENRESTY_SOURCE_BASE
    local target=$OPENRESTY_BUILD_TRARGRT_DIR
    echo $openssl
    echo $pcre
    echo $luajit

    local j=$RESTY_J
    cd $source
    echo "wg action build: build openresty start"
    local cc_opt="-DNGX_LUA_ABORT_AT_PANIC -I$pcre/include -I$openssl/include"
    local cc_opt="$cc_opt  -O1 -fno-omit-frame-pointer"

    # make -j10 TARGET_STRIP=@: CCDEBUG=-g Q= XCFLAGS='-DLUA_USE_APICHECK -DLUA_USE_ASSERT -DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_LUA52COMPAT' CC=cc PREFIX=/home/cong/sm/temp/openresty-wg/luajit
    ./configure -j$j \
        --prefix=$OPENRESTY_BUILD_TRARGRT_DIR \
        --with-pcre \
        --with-cc-opt="$cc_opt" \
        --with-ld-opt="-lpcre -L $pcre/lib -L $openssl/lib -Wl,-rpath,$pcre/lib:$openssl/lib" \
        --with-luajit="$luajit" \
        --with-compat \
        --with-file-aio \
        --with-http_addition_module \
        --with-http_auth_request_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_geoip_module=dynamic \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_image_filter_module=dynamic \
        --with-http_mp4_module \
        --with-http_random_index_module \
        --with-http_realip_module \
        --with-http_secure_link_module \
        --with-http_slice_module \
        --with-http_ssl_module \
        --with-http_stub_status_module \
        --with-http_sub_module \
        --with-http_v2_module \
        --with-http_xslt_module=dynamic \
        --with-ipv6 \
        --with-mail \
        --with-mail_ssl_module \
        --with-md5-asm \
        --with-pcre-jit \
        --with-sha1-asm \
        --with-stream \
        --with-stream_ssl_module \
        --with-threads \
        --with-poll_module \
        --without-http_redis_module \
        --with-debug
    local END_GEN_CFG=$(date +%s%3N)
    echo "configure-openresty: $(_format_time_diff $START_GEN_CFG $END_GEN_CFG)" | tee -a $target/build.record
}

function openresty-build-lua-and-nginx {
    cd $OPENRESTY_SOURCE_BASE
    local target=$OPENRESTY_BUILD_TRARGRT_DIR
    local start=$(date +%s%3N)
    make -j${RESTY_J}
    local end=$(date +%s%3N)
    make -j${RESTY_J} install
    local end1=$(date +%s%3N)
    echo "build: make : $(_format_time_diff $start $end)" | tee -a $target/build.record
    echo "build: make-install : $(_format_time_diff $end $end1)" | tee -a $target/build.record
}

function openresty-set-path {
    ln -s $OPENRESTY_BUILD_TRARGRT_DIR/nginx/sbin/nginx /usr/bin/wg-nginx
}

function openresty-isvalid-nginx-config {
    # -c $PWD/t/nginx.sample.conf
    # -p  $PWD/t
    # -e $PWD/t/servroot/logs/error.log
    local c=""
    local p=""
    local e=""
    nginx -t -c $c -p $p -e $e
}

function openresty-my-test-all {
    openresty-set-path ~/sm/temp/openresty-wg
    prove -I ./vendor/test-nginx/lib -r ./t
}

function openresty-my-test {
    openresty-set-path ~/sm/temp/openresty-wg
    prove -I ./vendor/test-nginx/lib -r ./t/mine.t
    echo $PWD
    nginx -p $PWD/t/servroot -c $PWD/t/servroot/conf/nginx.conf
    openresty-perf-flamegraph

    pkill nginx
}

function openresty-perf-flamegraph {
    # prove -I ./vendor/test-nginx/lib -r ./t/mine.t; nginx -p $PWD/t/servroot -c $PWD/t/servroot/conf/nginx.conf; . ./actions/openresty.actions.sh; openresty-flamegraph
    sudo perf record -p "$1" -F 99 -a -g &
    local pid=$!
    local n=10
    echo "perf run in bg $pid wait $n s"
    echo $PWD
    sleep $n
    sudo kill -INT $pid
    sleep 1
    sudo chmod a+rw ./perf.data
    perf script >perf.bt
    /home/cong/sm/lab/FlameGraph/stackcollapse-perf.pl perf.bt >perf.cbt
    /home/cong/sm/lab/FlameGraph/flamegraph.pl perf.cbt >perf.svg
    firefox ./perf.svg
}

function openresty-profile-bcc-flamegraph {
    local n=10
    echo "will run  bcc profile $pid wait $n s"
    sudo PROBE_LIMIT=100000 ~/sm/lab/bcc/tools/profile.py --stack-storage-size 204800 -af -p $(pgrep nginx) 10 >profile.stacks
    /home/cong/sm/lab/FlameGraph/flamegraph.pl <./profile.stacks >./profile.stacks.svg
    firefox ./profile.stacks.svg &
}

function openresty-gdb {
    echo "you must stop bpftrace for the process first"
    local pid=$(ps -aux | grep nginx | grep 'openresty-wg' | awk '{print $2}')
    local gdbinit=$(
        cat <<EOF
    info functions eyes
EOF
    )
    echo "$gdbinit" >./gdbinit
    sudo ugdb -p $pid -x ./gdbinit
    return
}

function ngx-on-epoll-process-event {
    code=$(
        cat <<EOF
BEGIN 
{
	time("%H:%M:%S");
	printf(" start\n");
}
uprobe:./t/nginx:ngx_epoll_process_events
{
	printf(" epoll process flags %x\n",arg3);
}
END
{
	time("%H:%M:%S");
	printf(" end\n");
}
EOF
    )
    echo "$code"
    sudo bpftrace -e "$code"
}

function gdb-steal-nginx-global-variable-address {
    local name=$1
    local gdbinit=$(
        cat <<EOF
    set confirm off
    p &$name
    quit
EOF
    )
    echo "$gdbinit" >./gdbinit
    sudo gdb -q -p $(pgrep nginx) -x ./gdbinit 2>&1 | grep $name | rg -o '0x.*\s'
}

function ngx-show-global-accept {
    # https://github.com/iovisor/bpftrace/issues/75
    local address=$(gdb-steal-nginx-global-variable-address ngx_stat_accepted0)
    local code=$(
        cat <<EOF
uretprobe:./t/nginx: ngx_event_accept {\$p=$address;printf(" ngx_event_accept ret %d\n",*\$p);}
EOF
    )
    echo $code
    sudo bpftrace -e "$code"
}

# mkdir -p ./t/servroot/logs &&  nginx -c $PWD/t/flame/nginx.lua.conf -p  $PWD/t -e $PWD/t/servroot/logs/error.log

function _format_time_diff() {
    local start=$1
    local end=$2
    echo $(echo "scale=3; ($end-$start)/1000" | bc)s
}

function openresty-zip() {
    zip -r openresty-wg.zip  ./openresty-wg -x ./openresty-wg/target/\* ./openresty-wg/build/\*
}
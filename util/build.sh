#!/bin/bash
rm -rf /tmp/openresty-1.23.0.1
cp -r ./openresty-1.23.0.1 /tmp

RESTY_IMAGE_BASE="build-harbor.alauda.cn/ops/alpine"
RESTY_IMAGE_TAG="3.16"
LUA_RESTY_BALANCER_VERSION="0.04"
LUA_VAR_NGINX_MODULE_VERSION="0.5.2"
RESTY_VERSION="1.23.0.1"
RESTY_OPENSSL_VERSION="1.1.1o"
RESTY_OPENSSL_PATCH_VERSION="1.1.1f"
RESTY_OPENSSL_URL_BASE="https://www.openssl.org/source"
RESTY_PCRE_VERSION="8.45"
RESTY_PCRE_BUILD_OPTIONS="--enable-jit"
RESTY_PCRE_SHA256="4e6ce03e0336e8b4a3d6c2b70b1c5e18590a5673a98186da90d4f33c23defc09"
RESTY_J="4"
RESTY_CONFIG_OPTIONS="\
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
    --with-debug \
    --without-http_redis_module \
    --build=ALB \
    "

RESTY_CONFIG_OPTIONS_MORE="--add-module=/tmp/lua-var-nginx-module-${LUA_VAR_NGINX_MODULE_VERSION}"
RESTY_LUAJIT_OPTIONS="--with-luajit-xcflags='-DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_LUA52COMPAT'"
RESTY_PCRE_OPTIONS="--with-pcre-jit"

RESTY_ADD_PACKAGE_BUILDDEPS=""
RESTY_ADD_PACKAGE_RUNDEPS="ca-certificates jq openssl"

function pre_configure() {
    curl -fSL https://github.com/api7/lua-var-nginx-module/archive/v${LUA_VAR_NGINX_MODULE_VERSION}.tar.gz -o lua-var-nginx-module-v${LUA_VAR_NGINX_MODULE_VERSION}.tar.gz 
    tar xzf lua-var-nginx-module-v${LUA_VAR_NGINX_MODULE_VERSION}.tar.gz  rm -rf lua-var-nginx-module-v${LUA_VAR_NGINX_MODULE_VERSION}.tar.gz
}

RESTY_EVAL_POST_MAKE="ln -s /usr/local/openresty/bin/opm /usr/local/bin/opm \
     ln -s /usr/local/openresty/bin/resty /usr/local/bin/resty \
     opm install thibaultcha/lua-resty-mlcache \
     opm install xiangnanscu/lua-resty-cookie \
     curl -fSL https://github.com/openresty/lua-resty-balancer/archive/v${LUA_RESTY_BALANCER_VERSION}.tar.gz -o lua-resty-balancer-v${LUA_RESTY_BALANCER_VERSION}.tar.gz \
     tar xzf lua-resty-balancer-v${LUA_RESTY_BALANCER_VERSION}.tar.gz  rm -rf lua-resty-balancer-v${LUA_RESTY_BALANCER_VERSION}.tar.gz \
     cd lua-resty-balancer-${LUA_RESTY_BALANCER_VERSION} \
     make  make install  cd - \
     cd lua-var-nginx-module-${LUA_VAR_NGINX_MODULE_VERSION} \
     cp -r lib/resty/* /usr/local/openresty/lualib/resty  cd -"

# These are not intended to be user-specified
_RESTY_CONFIG_DEPS="--with-pcre \
    --with-cc-opt='-DNGX_LUA_ABORT_AT_PANIC -I/usr/local/openresty/pcre/include -I/usr/local/openresty/openssl/include' \
    --with-ld-opt='-lpcre -L/usr/local/openresty/pcre/lib -L/usr/local/openresty/openssl/lib -Wl,-rpath,/usr/local/openresty/pcre/lib:/usr/local/openresty/openssl/lib' \
    "

# 1) Install apk dependencies
# 2) Download and untar OpenSSL, PCRE, and OpenResty
# 3) Build OpenResty
# 4) Cleanup

# RUN apk add --no-cache --virtual .build-deps \
#         build-base \
#         coreutils \
#         curl \
#         gd-dev \
#         geoip-dev \
#         libxslt-dev \
#         linux-headers \
#         make \
#         perl-dev \
#         readline-dev \
#         zlib-dev \
#         ${RESTY_ADD_PACKAGE_BUILDDEPS} \
#      apk add --no-cache \
#         gd \
#         geoip \
#         libgcc \
#         libxslt \
#         zlib \
#         ${RESTY_ADD_PACKAGE_RUNDEPS}
# cd /tmp
# pre_configure

cd /tmp 
curl -fSL "${RESTY_OPENSSL_URL_BASE}/openssl-${RESTY_OPENSSL_VERSION}.tar.gz" -o openssl-${RESTY_OPENSSL_VERSION}.tar.gz 
tar xzf openssl-${RESTY_OPENSSL_VERSION}.tar.gz 
cd openssl-${RESTY_OPENSSL_VERSION} 
if [ $(echo ${RESTY_OPENSSL_VERSION} | cut -c 1-5) = "1.1.1" ] ; then 
   echo 'patching OpenSSL 1.1.1 for OpenResty' 
    curl -s https://raw.githubusercontent.com/openresty/openresty/master/patches/openssl-${RESTY_OPENSSL_PATCH_VERSION}-sess_set_get_cb_yield.patch | patch -p1 ; 
fi 
./config \
 no-threads shared zlib -g \
 enable-ssl3 enable-ssl3-method \
 --prefix=/usr/local/openresty/openssl \
 --libdir=lib \
 -Wl,-rpath,/usr/local/openresty/openssl/lib 
make -j${RESTY_J}
make -j${RESTY_J} install_sw 
cd /tmp 
curl -fSL https://downloads.sourceforge.net/project/pcre/pcre/${RESTY_PCRE_VERSION}/pcre-${RESTY_PCRE_VERSION}.tar.gz -o pcre-${RESTY_PCRE_VERSION}.tar.gz 
echo "${RESTY_PCRE_SHA256}  pcre-${RESTY_PCRE_VERSION}.tar.gz" | shasum -a 256 --check 
tar xzf pcre-${RESTY_PCRE_VERSION}.tar.gz 
cd /tmp/pcre-${RESTY_PCRE_VERSION} 
./configure \
   --prefix=/usr/local/openresty/pcre \
   --disable-cpp \
   --enable-utf \
   --enable-unicode-properties \
   ${RESTY_PCRE_BUILD_OPTIONS} 
make -j${RESTY_J} 
make -j${RESTY_J} instal

cd /tmp 
echo "start build openresty" 
cd /tmp/openresty-${RESTY_VERSION} 
eval ./configure -j${RESTY_J} ${_RESTY_CONFIG_DEPS} ${RESTY_CONFIG_OPTIONS} ${RESTY_CONFIG_OPTIONS_MORE} ${RESTY_LUAJIT_OPTIONS} ${RESTY_PCRE_OPTIONS} 
make -j${RESTY_J} 
make -j${RESTY_J} install 
cd /tmp 
if [ -n "${RESTY_EVAL_POST_MAKE}" ]; then eval $(echo ${RESTY_EVAL_POST_MAKE}); fi 
echo "build openresty over" 
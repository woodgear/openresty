#!/usr/bin/env bash

# rm -rf ./openresty-1.22.0.1
# bash -x ./util/mirror-tarballs-1.22.0
# docker build -t openresty-blade:1.22.0 -f ./util/nginx-1.22.0.dockerfile .
alb=/home/cong/sm/work/alauda/acp/alb2
cd $alb 
sed -i 's/FROM.*/FROM openresty-blade:1.22.0/g' ./alb-nginx/alb-test-runner.dockerfile
cat $alb/alb-nginx/alb-test-runner.dockerfile | grep 'FROM'
docker build -t openresty-test-runner:1.22.0 -f ./alb-nginx/alb-test-runner.dockerfile .
cd -
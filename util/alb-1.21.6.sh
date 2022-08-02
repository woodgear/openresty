#!/usr/bin/env bash

rm -rf ./openresty-1.21.6.1
bash -x ./util/mirror-tarballs-1.21.6
docker build -t openresty-blade:1.21.6 -f ./util/nginx-1.21.6.dockerfile .
alb=/home/cong/sm/work/alauda/acp/alb2
cd $alb 
sed -i 's/FROM.*/FROM openresty-blade:1.21.6/g' ./alb-nginx/alb-test-runner.dockerfile
cat $alb/alb-nginx/alb-test-runner.dockerfile | grep 'FROM'
docker build -t openresty-test-runner:1.21.6 -f ./alb-nginx/alb-test-runner.dockerfile .
cd -
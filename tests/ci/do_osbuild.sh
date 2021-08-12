#!/bin/bash

MANIFEST_MPP=$1
shift

BASENAME=$(basename $MANIFEST_MPP .mpp.json)
DIRNAME=$(dirname $MANIFEST_MPP)
MANIFEST=$DIRNAME/$BASENAME.json

osbuild-mpp $MANIFEST_MPP $MANIFEST && sudo osbuild --store osbuild_store --output-directory image_output "$@" $MANIFEST && sudo chown -R `whoami` image_output/

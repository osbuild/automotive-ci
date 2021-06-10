#!/usr/bin/env bash

# Setup subscription-manager to enable yum repos
USER=$1
PASS=$2

subscription-manager register --username $USER --password $PASS
subscription-manager role --set="Red Hat Enterprise Linux Server"
subscription-manager service-level --set="Self-Support"
subscription-manager usage --set="Development/Test"
subscription-manager attach

# Update vagrant box to 8.4 which is a requirement for iso/container image support
sudo dnf update -y

echo "Done"

This repo is a bunch of automation scripts that I have made working with AWS.  I wanted to make them public to avoid re-creating the wheel.

#How To Use This Repo

This is a collection of scripts is meant to be a starting point and can be forked and included in your cource control.

##Getting Started


feel free to clone and use https://github.com/jasonbain/AWS-Automation.git

##Documentation


I will attempt to make sense of the scripts here.

###aws-mgmt.sh
####This script uses aws-instances.conf as input.

Usage: ./aws-mgmt.sh { create-instances | attach-eips | aws-all-on | aws-all-off | terminate-instances | status }

Examples:

./aws-mgmt.sh create-instances - creates a set of instances based the config file aws-instances.txt

./aws-mgmt.sh attach-eips - will attach a random elastic ip to each running instance

./aws-mgmt.sh update-all - this will apt-get update, apt-get upgrade, config hostname and add to hosts file

./aws-mgmt.sh aws-all-on -  turn on all instances

./aws-mgmt.sh aws-all-off - shutdown all instances

./aws-mgmt.sh terminate-instances - WARNING: this will terminate and delete all instances

./aws-mgmt.sh status - print the status of all instances.  E.g. running, stopped, waiting

./aws-mgmt.sh list-ips - print the Name field and elastic IP of each instance

./aws-mgmt.sh setup-puppetmaster - do exactly that...

./aws-mgmt.sh setup-cluster - do exactly that... ***WARNING do this after setup-puppetmaster**

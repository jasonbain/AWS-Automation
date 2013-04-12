#!/bin/bash
# This script creates AWS instances based on a conf file aws-instances.conf

case $1 in
	create-instances)
		echo "========================================"
		echo "== create instances from config file  =="
		echo "========================================"
		START=$(date +%s)
		awk '{print $2}' aws-instances.conf | while read line; do ec2-run-instances -g sg-7729c418 --key jason_dev -t m1.small --block-device-mapping /dev/sda1=:750 ami-9c78c0f5 -s subnet-e51d768e --private-ip-address $line; done
		
		instance=(`ec2-describe-instances | grep running | awk '{print $2}'`)

		total=${#instance[*]}

		name=(`awk '{print $3}' aws-instances.conf`)

		echo "== add the name tag to each instance =="
		echo "======================================="
		for (( i=0; i<=$(( $total -1 )); i++ ))
                do
                        ec2-create-tags "${instance[$i]}" --tag Name="${name[$i]}";
                done
		END=$(date +%s)
		DIFF=$(( $END - $START ))
		echo "It took $DIFF seconds"
		;;

	attach-eips)
		echo "======================================================"
		echo "==  attaching elastic IPs to each running instance  =="
		echo "======================================================"
		START=$(date +%s)
		instance=(`ec2-describe-instances | grep running | awk '{print $2}'`)
		total=${#instance[*]}
		for (( i=0; i<=$(( $total -1 )); i++ )); do ec2-allocate-address -d vpc; done

		eipid=(`ec2-describe-addresses | awk {'print $4'}`)

		for (( i=0; i<=$(( $total -1 )); i++ ))
		do
			ec2-associate-address -i "${instance[$i]}" -a "${eipid[$i]}";
		done
		END=$(date +%s)
		DIFF=$(( $END - $START ))
		echo "It took $DIFF seconds"
		;;

	update-all)
		START=$(date +%s)
		echo "getting the host names"
		name=(`ec2-describe-instances | grep TAG | awk '{print $5}'`)
		echo "getting the wan ips"
		wanips=(`ec2-describe-instances | grep NICASSOCIATION | awk '{print $2}'`)
		echo "getting the lan ips"
		lanips=(`ec2-describe-instances | grep running | awk '{print $13}'`)
		total=${#wanips[*]}
		echo "here we go with the updates..."
		for (( i=0; i<=$(( $total -1 )); i++ ))
                do
			echo "====> sudo update";
			ssh -o StrictHostKeyChecking=no ubuntu@"${wanips[$i]}" sudo apt-get update;
			echo "====> sudo upgrade";
			ssh ubuntu@"${wanips[$i]}" sudo apt-get -y upgrade;
			echo "====> modify /etc/hosts";
			ssh ubuntu@"${wanips[$i]}" "echo "10.8.8.151 mongocfg-01.devjason.doodleroulette.com" | sudo tee -a /etc/hosts";
			ssh ubuntu@"${wanips[$i]}" "echo ""${lanips[$i]}" "${name[$i]}".devjason.doodleroulette.com" | sudo tee -a /etc/hosts";
			echo "====> set the hostname";
			ssh ubuntu@"${wanips[$i]}" "echo ""${name[$i]}".devjason.doodleroulette.com" | sudo tee /etc/hostname";
			ssh ubuntu@"${wanips[$i]}" "sudo hostname "${name[$i]}".devjason.doodleroulette.com";
			ssh ubuntu@"${wanips[$i]}" "sudo aptitude -y install puppet";
			ssh ubuntu@"${wanips[$i]}" "echo "[agent]" | sudo tee -a /etc/puppet/puppet.conf";
			ssh ubuntu@"${wanips[$i]}" "echo "server=mongocfg-01.devjason.doodleroulette.com" | sudo tee -a /etc/puppet/puppet.conf";
			ssh ubuntu@"${wanips[$i]}" "echo "environment=developmentjason" | sudo tee -a /etc/puppet/puppet.conf";
		done		
                END=$(date +%s)
                DIFF=$(( $END - $START ))
                echo "It took $DIFF seconds"
		;;
	check-configs)
		START=$(date +%s)
                echo "getting the wan ips"
                wanips=(`ec2-describe-instances | grep NICASSOCIATION | awk '{print $2}'`)
                total=${#wanips[*]}
                echo "checking configs..."
		for (( i=0; i<=$(( $total -1 )); i++ ))
                do
			echo "====>configs on ${wanips[$i]} ";
			echo "==========================================";
                        ssh -o StrictHostKeyChecking=no ubuntu@"${wanips[$i]}" sudo cat /etc/hosts;
                        ssh -o StrictHostKeyChecking=no ubuntu@"${wanips[$i]}" sudo cat /etc/hostname;
			ssh -o StrictHostKeyChecking=no ubuntu@"${wanips[$i]}" sudo cat /etc/puppet/puppet.conf;
		done
		END=$(date +%s)
                DIFF=$(( $END - $START ))
                echo "It took $DIFF seconds"
		;;

	setup-puppetmaster)
		START=$(date +%s)
                echo "getting the wan ips"
                wanips=(`ec2-describe-instances | grep NICASSOCIATION | awk '{print $2}'`)
                total=${#wanips[*]}
                echo "installing puppetmaster"
		i=0;
		ssh -o StrictHostKeyChecking=no ubuntu@"${wanips[$i]}" "sudo aptitude -y install git puppet puppetmaster rails sqlite3 libsqlite3-ruby ec2-api-tools";
		ssh ubuntu@"${wanips[$i]}" "sudo mkdir /var/lib/puppet/storeconfigs/";
		ssh ubuntu@"${wanips[$i]}" "sudo chown puppet:puppet /var/lib/puppet/storeconfigs";
		ssh ubuntu@"${wanips[$i]}" "sudo rm -rf /etc/puppet";
		ssh ubuntu@"${wanips[$i]}" "sudo git clone https://doodleroulette-robot:terabytesofdiddles@github.com/babygaga/doodleroulette-puppet.git /etc/puppet"; 
		ssh ubuntu@"${wanips[$i]}" "sudo cp /etc/puppet/puppet.conf.example.devjason /etc/puppet/puppet.conf";
		ssh ubuntu@"${wanips[$i]}" "echo "*" | sudo tee /etc/puppet/autosign.conf";
		ssh ubuntu@"${wanips[$i]}" "sudo service puppetmaster restart";
		ssh ubuntu@"${wanips[$i]}" "sudo puppet agent --test";
                END=$(date +%s)
                DIFF=$(( $END - $START ))
                echo "It took $DIFF seconds"
		;;

	setup-cluster)
		START=$(date +%s)
                echo "getting the wan ips"
                wanips=(`ec2-describe-instances | grep NICASSOCIATION | awk '{print $2}'`)
                total=${#wanips[*]}
                echo "here we go! setting up the cluster via puppet..."
		echo "clearing log file" > setup-cluster.log
                for (( i=1; i<=$(( $total -1 )); i++ ))
                do
			ssh -o StrictHostKeyChecking=no ubuntu@"${wanips[$i]}" "sudo puppet agent --test";
		done
                END=$(date +%s)
                DIFF=$(( $END - $START ))
                echo "It took $DIFF seconds"
		;;

	aws-all-on)
		START=$(date +%s)
		echo "================================"
		echo "==  Turning on all instances  =="
		echo "================================"		
		instance=(`ec2-describe-instances | grep INSTANCE | awk '{print $2}'`)
                total=${#instance[*]}
                
                for (( i=0; i<=$(( $total -1 )); i++ ))
                do
                        ec2-start-instances "${instance[$i]}";
                done
                END=$(date +%s)
                DIFF=$(( $END - $START ))
                echo "It took $DIFF seconds"
		;;

	aws-all-off)
		START=$(date +%s)
		echo "==========================================="
		echo "==  Shutting down all running instances  =="
		echo "==========================================="
		instance=(`ec2-describe-instances | grep INSTANCE | awk '{print $2}'`)
		total=${#instance[*]}

                for (( i=0; i<=$(( $total -1 )); i++ ))
                do
                        ec2-stop-instances "${instance[$i]}";
                done
                END=$(date +%s)
                DIFF=$(( $END - $START ))
                echo "It took $DIFF seconds"
		;;

	terminate-instances)
		echo "================================="
		echo "==  Terminating all instances  =="
		echo "================================="
		START=$(date +%s)
		ec2-describe-instances | grep INSTANCE | awk '{print $2}' > aws-instances.txt
		while read line; do ec2-terminate-instances $line; done < aws-instances.txt
		ec2-describe-addresses > aws-eip.txt
		while read line; 
		do 
			ip=`echo ${line} | awk {'print $2'}`; 
			id=`echo ${line} | awk {'print $4'}`; 
			ec2-release-address ec2-release-address $ip -a $id; 
		done < aws-eip.txt
                END=$(date +%s)
                DIFF=$(( $END - $START ))
                echo "It took $DIFF seconds"
		;;

	status)
		echo "==============================="
		echo "==  Status of all instances  =="
		echo "==============================="

		ec2-describe-instances | grep INSTANCE | awk '{print $2}' > aws-instances.txt && while read line; do ec2-describe-instance-status $line | awk '{print $1,$2,$3,$4}' | grep -vE '(SYSTEMSTATUS|INSTANCESTATUS)' ; done < aws-instances.txt

		;;

	list-ips)
		HOSTS=(`ec2-describe-instances | grep TAG | awk '{print $5}'`)
		WANIPS=(`ec2-describe-instances | grep NICASSOCIATION | awk '{print $2}'`)
		LANIPS=(`ec2-describe-instances | grep INSTANCE | awk '{print $13}'`)

                total=${#HOSTS[*]}

                for (( i=0; i<=$(( $total -1 )); i++ ))
                do
                        echo "${HOSTS[$i]} ${LANIPS[$i]} ${WANIPS[$i]}";
                done


		;;

	*)
		echo ""
		echo "Usage: $0 { create-instances | attach-eips | aws-all-on | aws-all-off | terminate-instances | status }"
		echo ""
		echo "Examples:"
		echo "$0 create-instances - creates a set of instances based the config file aws-instances.txt"
		echo "$0 attach-eips - will attach a random elastic ip to each running instance"
		echo "$0 update-all - this will apt-get update, apt-get upgrade, config hostname and add to hosts file"
		echo "$0 aws-all-on -  turn on all instances"
		echo "$0 aws-all-off - shutdown all instances"
		echo "$0 terminate-instances - WARNING: this will terminate and delete all instances"
		echo "$0 status - print the status of all instances.  E.g. running, stopped, waiting"
		echo "$0 list-ips - print the Name field and elastic IP of each instance"
		echo "$0 setup-puppetmaster - do exactly that..."
		echo "$0 setup-cluster - do exactly that... ***WARNING do this after setup-puppetmaster***"
		echo ""
		exit 2
		;;

esac

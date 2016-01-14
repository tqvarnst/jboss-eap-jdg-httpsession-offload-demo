#!/bin/sh

EAP_HOME="./target/jboss-eap-6.4"
JDG_HOME="./target/jboss-datagrid-6.5.1-server"
STARTUP_WAIT=6


function waitForStartup(){
  node_name=$1

  printf "\n\n \t\twait for $node_name startup"
  count=0
  launched=false

  until [ $count -gt $STARTUP_WAIT ]
  do
    #grep 'JBAS015874:' ${node_name}.log > /dev/null
    log_entry=`grep 'JBAS015874:' ${node_name}.log`
    if [ $? -eq 0 ] ; then
      launched=true
      break
    fi
    printf "\n\t\t waiting 5s..."
    sleep 5
    let count=$count+1;
  done

  if [ "$launched" = "false" ] ; then
    printf "\n $node_name failed to startup in the time allotted \n"
    return 7
  fi
  
  printf "\n\n\t >> $log_entry"
}

function startJDGNode(){
   node_name=$1
   ports_offset=$2
   
   printf "\n\n ___"
   printf "\n\tstarting >>> ${node_name} <<<"
   $JDG_HOME/bin/clustered.sh \
    -b 127.0.0.1 \
    -Djboss.node.name=$node_name \
    -Djava.net.preferIPv4Stack=true \
    -Djboss.socket.binding.port-offset=$ports_offset \
    -Djgroups.bind_addr=127.0.0.1 &> ./${node_name}.log&

   waitForStartup $node_name
   [[ $? != 0 ]] && printf "\t can't start ${node_name}. Please chech the ./$node_name.log file" && exit 1

   JVM_PID=$(ps -eo pid,command | grep "org.jboss.as.standalone" | grep "jboss.node.name=$node_name" | grep -v grep | awk '{print $1}')
   jdg_hotrod_port=$(bc -l <<< "11222 + $ports_offset")
   
   printf "\n\n\t $node_name is UP and RUNNING! JVM PID: $JVM_PID"
   printf "\n\t $node_name JVM PID: $JVM_PID" >> startup_summary
   printf "\n\t\t $node_name Hot Rod Service listening on port: $jdg_hotrod_port" >> startup_summary
   printf "\n ___ \n"
}

function stopNode(){
   node_name=$1
   
   printf "\n\t killing >>> ${node_name} <<<"
   JVM_PID=$(ps -eo pid,command | grep "org.jboss.as.standalone" | grep "jboss.node.name=$node_name" | grep -v grep | awk '{print $1}')
   
   [[ ! -z $JVM_PID ]] && kill $JVM_PID && printf "\n\t $node_name [PID: $JVM_PID] killed!"
}

function startEAPNode(){
   node_name=$1
   ports_offset=$2
   
   printf "\n\n ___"
   printf "\n\tstarting >>> ${node_name} <<<"

  $EAP_HOME/bin/standalone.sh \
  -b 127.0.0.1 -c standalone-ha.xml \
  -Djboss.server.base.dir=$EAP_HOME/$node_name \
  -Djboss.node.name=$node_name \
  -Djboss.socket.binding.port-offset=$ports_offset \
  -Djava.net.preferIPv4Stack=true \
  -Djgroups.bind_addr=127.0.0.1 \
  -Djdg.remoting.hothod.node1.addr=127.0.0.1 \
  -Djdg.remoting.hothod.node1.port=11822 \
  -Djdg.remoting.hothod.node2.addr=127.0.0.1 \
  -Djdg.remoting.hothod.node2.port=11922 &> ./${node_name}.log&

   waitForStartup $node_name
   [[ $? != 0 ]] && printf "\t can't start ${node_name}. Please chech the ./$node_name.log file" && exit 1

   JVM_PID=$(ps -eo pid,command | grep "org.jboss.as.standalone" | grep "jboss.node.name=$node_name" | grep -v grep | awk '{print $1}')
   eap_http_port=$(bc -l <<< "8080 + $ports_offset")
   
   printf "\n\n\t $node_name is UP and RUNNING! JVM PID: $JVM_PID"
   printf "\n\t $node_name JVM PID: $JVM_PID" >> startup_summary
   printf "\n\t\t $node_name Web Server listening on port: $eap_http_port " >> startup_summary
   printf "\n ___ \n"
}

function summary(){
  printf "\n\n ___ \n"
  printf "\n Summary\n"
  cat startup_summary
  printf "\n ___ \n"
  printf "\n Cluster nodes startup Finished!!!"
  printf "\n\t You can now access the webapp to test your cluster!"
  printf "\n\t\t Login to http://localhost:8080/jboss-payment-cdi-event \n\n\n"
}

function usage(){
  printf "\n\t Usage: $0 {start|stop} {all|[eap|jdg]_node<n> [<port_offset>]} \n\n"
  exit 1
}

case "$1" in
  start)
    case "$2" in
      all)
	  clear
	  > startup_summary
	  startJDGNode jdg_node1 600
	  startJDGNode jdg_node2 700
	  printf "\n ====== \n" >> startup_summary
	  startEAPNode eap_node1 0
	  startEAPNode eap_node2 100
	  summary
	  ;;
      eap_node[1-9])
	  [[ -z $3 ]] && usage
	  startEAPNode $2 $3
	  summary
	  ;;
      jdg_node[1-9])
	  [[ -z $3 ]] && usage
	  startJDGNode $2 $3
	  summary
	  ;;
      *)
	  ## If no parameters are given, print which are avaiable.
	  usage
	  ;;
    esac
    ;;
  stop)
    case "$2" in
      all)
	  clear
	  stopNode jdg_node1
	  stopNode jdg_node2
	  stopNode eap_node1
	  stopNode eap_node2
	  ;;
      *_node[1-9])
	  stopNode $2
	  ;;
      *)
        ## If no parameters are given, print which are avaiable.
        usage
        ;;
    esac
    ;;
  *)
    ## If no parameters are given, print which are avaiable.
    usage
    ;;
esac



#!/bin/bash

elastic_timeout=90
counter_node1=0
counter_cluster=0
usage="Usage:
escluster.sh [-d /path/to/elasticsearch_directory] -a <start|stop>"

function espath_check()
{
    if [[ -z "$elastic_home" ]]; then
        echo "Refusing to start without path to elasticsearch. $usage"
        exit 1
    elif [[ ! -d "$elastic_home" ]]; then
        echo "The path: \"$elastic_home\" does not exist"
        exit 1
    fi
 }

function startes()
{
    # don't start if ES is already running
    if ps aux | grep 'elasticsearch.*java .*Xms' | grep -v grep >/dev/null; then
        echo "Seems elasticsearch is already running. Refusing to start more nodes."
        exit 3
    fi

    echo "Starting elasticsearch cluster"
    # start first node, label this 'hot' to enable ILM
    "$elastic_home"/bin/elasticsearch -Enode.attr.data=hot >/dev/null 2>&1 &
    elastic_pid=$!

    # get health of first node
    node1_up=$(curl -s localhost:9200 | sed -n -E 's/.*"cluster_name" : "(.*)".*$/\1/p')

    # wait for first node then bring up two more nodes
    while [[ "$node1_up" != "elasticsearch" ]]; do
        if (( "$counter_node1" > "$elastic_timeout" )); then
            echo "We timed out. Aborting."
            kill "$elastic_pid"
            exit 1
        fi

        node1_up=$(curl -s localhost:9200 | sed -n -E 's/.*"cluster_name" : "(.*)".*$/\1/p')
        sleep 1
        ((counter_node1++))
    done

    echo "Node 1 is up. Bringing up two more nodes."

    # start two more nodes, 'warm' and 'cold'
    "$elastic_home"/bin/elasticsearch -Enode.attr.data=warm -Epath.data=data2 -Epath.logs=log2 >/dev/null 2>&1 &
    sleep 2
    "$elastic_home"/bin/elasticsearch -Enode.attr.data=cold -Epath.data=data3 -Epath.logs=log3 >/dev/null 2>&1 &

    while true; do
        cluster_status=$(curl -s localhost:9200/_cat/health | awk '{ print $4 }')
        cluster_nodes=$(curl -s localhost:9200/_cat/health | awk '{ print $5 }')

        if (( "$counter_cluster" > "$elastic_timeout" )); then
            echo "Failed to bring up Elastic cluster. Check logs and stuff."
            exit 2
        fi

        if [[ "$cluster_status" == "green" && "$cluster_nodes" == 3 ]]; then
            echo "Elasticsearch cluster is green and up with three nodes."
            break
        fi

        sleep 1
        ((counter_cluster++))
    done
}

function stopes()
{
    # get pids of all elasticsearch nodes
    elastic_pids=$(ps aux | awk '/elasticsearch.*java .*Xms/ { if ($11 != "awk") print $2 }')

    if [[ -z "$elastic_pids" ]]; then
        echo "Found no elasticsearch processes. Is cluster up?"
        exit 1
    fi

    # kill them (do _not_ quote $elastic_pids)
    echo "Stopping elasticsearch cluster"
    kill $elastic_pids
    exit $!
}

# get arguments
while getopts ":d:a:h" opt; do
    case "$opt" in
        h)
            echo "$usage"
            exit 0
            ;;
        d)
            elastic_home="$OPTARG"
            ;;
        a)
            action="$OPTARG"
            ;;
        \?)
            echo "Invalid option $OPTARG"
            exit 1
            ;;
        :)
            echo "Invalid option, $OPTARG requires an argument"
            exit 1
            ;;
    esac
done

shift $(($OPTIND-1))

# sanity checks
if [[ -z "$action" ]]; then
    echo "The '-a' switch is mandatory. $usage"
    exit 1
fi

if [[ "$action" != "start" && "$action" != "stop" ]]; then
    echo "Incorrect argument \"$action\". $usage"
    exit 1
fi

# finally, start or stop the darn cluster
case "$action" in
    "start")
        espath_check
        startes
        ;;
    "stop")
        stopes
        ;;
esac

# eslabcluster
Bring up an elasticsearch cluster on localhost

A quick way to set up a local three-node elasticsearch lab environment.

### Usage
Download the tar version of elasticsearch from:<br>
https://www.elastic.co/downloads/elasticsearch

Unpack somewhere decent, then run the script as follows:
```
escluster.sh -d /path/to/elasticsearch_directory -a start
```

Wait patiently... done!

To bring down the cluster, run:
```
escluster.sh -a stop
```

### Kibana?
If you want Kibana as well, simply download the tar version from:<br>
https://www.elastic.co/downloads/kibana

Unpack, start, and it will connect to your lab cluster.

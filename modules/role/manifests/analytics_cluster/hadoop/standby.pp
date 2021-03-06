# == Class role::analytics_cluster::hadoop::standby
# Include standby NameNode classes
#
# filtertags: labs-project-analytics
class role::analytics_cluster::hadoop::standby {
    system::role { 'analytics_cluster::hadoop::standby':
        description => 'Hadoop Standby NameNode',
    }
    require ::profile::hadoop::client

    # Ensure that druid user exists on standby namenodes nodes.
    class { '::druid::cdh::hadoop::user':  }

    class { '::cdh::hadoop::namenode::standby': }

    # Use jmxtrans for sending metrics
    class { '::cdh::hadoop::jmxtrans::namenode':
        statsd  => hiera('statsd'),
    }

    # Include icinga alerts if production realm.
    if $::realm == 'production' {
        # Icinga process alert for Stand By NameNode
        nrpe::monitor_service { 'hadoop-hdfs-namenode':
            description   => 'Hadoop Namenode - Stand By',
            nrpe_command  => '/usr/lib/nagios/plugins/check_procs -c 1:1 -C java -a "org.apache.hadoop.hdfs.server.namenode.NameNode"',
            contact_group => 'admins,analytics',
            require       => Class['cdh::hadoop::namenode::standby'],
            critical      => true,
        }
        nrpe::monitor_service { 'hadoop-hdfs-zkfc':
            description   => 'Hadoop HDFS Zookeeper failover controller',
            nrpe_command  => '/usr/lib/nagios/plugins/check_procs -c 1:1 -C java -a "org.apache.hadoop.hdfs.tools.DFSZKFailoverController"',
            contact_group => 'admins,analytics',
            require       => Class['cdh::hadoop::namenode::standby'],
        }

        $hadoop_namenode_heapsize = hiera('cdh::hadoop::namenode_heapsize', undef)
        # Java heap space used alerts.
        # The goal is to get alarms for long running memory leaks like T153951.
        # Only include heap size alerts if heap size is configured.
        if $hadoop_namenode_heapsize {
            $nn_jvm_warning_threshold  = $hadoop_namenode_heapsize * 0.9
            $nn_jvm_critical_threshold = $hadoop_namenode_heapsize * 0.95
            monitoring::graphite_threshold { 'hadoop-hdfs-namenode-heap-usaage':
                description    => 'HDFS standby Namenode JVM Heap usage',
                dashboard_link => 'https://grafana.wikimedia.org/dashboard/db/analytics-hadoop?orgId=1&panelId=4&fullscreen',
                metric         => "Hadoop.NameNode.${::hostname}_eqiad_wmnet_9980.Hadoop.NameNode.JvmMetrics.MemHeapUsedM.upper",
                from           => '60min',
                warning        => $nn_jvm_warning_threshold,
                critical       => $nn_jvm_critical_threshold,
                percentage     => '60',
                contact_group  => 'analytics',
            }
        }
    }

    # Firewall
    include ::role::analytics_cluster::hadoop::ferm::namenode

    # If this is a resourcemanager host, then go ahead
    # and include a resourcemanager on all standby nodes as well
    # as the master node.
    if $::fqdn in $::cdh::hadoop::resourcemanager_hosts {
        include ::cdh::hadoop::resourcemanager
        # Firewall
        include ::role::analytics_cluster::hadoop::ferm::resourcemanager

        # Use jmxtrans for sending metrics
        class { 'cdh::hadoop::jmxtrans::resourcemanager':
            statsd  => hiera('statsd'),
        }

        # Include icinga alerts if production realm.
        if $::realm == 'production' {
            # Java heap space used alerts.
            # The goal is to get alarms for long running memory leaks like T153951.
            # Only include heap size alerts if heap size is configured.
            $hadoop_resourcemanager_heapsize = $::cdh::hadoop::yarn_heapsize
            if $hadoop_resourcemanager_heapsize {
                $rm_jvm_warning_threshold = $hadoop_resourcemanager_heapsize * 0.9
                $rm_jvm_critical_threshold = $hadoop_resourcemanager_heapsize  * 0.95
                monitoring::graphite_threshold { 'hadoop-yarn-resourcemananager-heap-usage':
                    description    => 'YARN standby Resource Manager JVM Heap usage',
                    dashboard_link => 'https://grafana.wikimedia.org/dashboard/db/analytics-hadoop?orgId=1&panelId=12&fullscreen',
                    metric         => "Hadoop.ResourceManager.${::hostname}_eqiad_wmnet_9983.Hadoop.ResourceManager.JvmMetrics.MemHeapUsedM.upper",
                    from           => '60min',
                    warning        => $rm_jvm_warning_threshold,
                    critical       => $rm_jvm_critical_threshold,
                    percentage     => '60',
                    contact_group  => 'analytics',
                }
            }
        }
    }

}

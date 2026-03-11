{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "metrics": {
    "namespace": "CWAgent",
    "append_dimensions": {
      "InstanceId": "${instance_id}"
    },
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "totalcpu": true
      },
      "mem": {
        "measurement": [
          "mem_used_percent",
          "mem_available_percent"
        ]
      },
      "disk": {
        "measurement": [
          "disk_used_percent",
          "disk_free",
          "disk_used"
        ],
        "resources": ["/"],
        "ignore_file_system_types": ["sysfs", "devtmpfs", "tmpfs"]
      },
      "net": {
        "measurement": [
          "bytes_sent",
          "bytes_recv",
          "packets_sent",
          "packets_recv"
        ]
      },
      "diskio": {
        "measurement": [
          "io_time",
          "write_bytes",
          "read_bytes"
        ],
        "resources": ["*"]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/monitoring-metrics.log",
            "log_group_name": "wsa-shared-infra",
            "log_stream_name": "{instance_id}/monitoring",
            "retention_in_days": 7
          }
        ]
      }
    }
  }
}

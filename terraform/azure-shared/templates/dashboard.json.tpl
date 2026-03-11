{
  "lenses": {
    "0": {
      "order": 0,
      "parts": {
        "0": {
          "position": { "x": 0, "y": 0, "colSpan": 12, "rowSpan": 1 },
          "metadata": {
            "type": "Extension/HubsExtension/PartType/MarkdownPart",
            "inputs": [],
            "settings": {
              "content": {
                "settings": {
                  "content": "## WSA Shared Infrastructure — ${resource_suffix}",
                  "title": "",
                  "subtitle": "",
                  "markdownSource": 1
                }
              }
            }
          }
        },
        "1": {
          "position": { "x": 0, "y": 1, "colSpan": 4, "rowSpan": 3 },
          "metadata": {
            "type": "Extension/HubsExtension/PartType/MonitorChartPart",
            "inputs": [
              {
                "name": "sharedTimeRange",
                "isOptional": true
              },
              {
                "name": "options",
                "value": {
                  "chart": {
                    "metrics": [
                      {
                        "resourceMetadata": { "id": "${vm_resource_id}" },
                        "name": "Percentage CPU",
                        "aggregationType": 4,
                        "namespace": "microsoft.compute/virtualmachines",
                        "metricVisualization": { "displayName": "Percentage CPU" }
                      }
                    ],
                    "title": "CPU Utilization",
                    "titleKind": 2,
                    "visualization": { "chartType": 2 },
                    "timespan": { "relative": { "duration": 3600000 } }
                  }
                },
                "isOptional": true
              }
            ],
            "settings": {}
          }
        },
        "2": {
          "position": { "x": 4, "y": 1, "colSpan": 4, "rowSpan": 3 },
          "metadata": {
            "type": "Extension/HubsExtension/PartType/MonitorChartPart",
            "inputs": [
              {
                "name": "sharedTimeRange",
                "isOptional": true
              },
              {
                "name": "options",
                "value": {
                  "chart": {
                    "metrics": [
                      {
                        "resourceMetadata": { "id": "${vm_resource_id}" },
                        "name": "Available Memory Bytes",
                        "aggregationType": 4,
                        "namespace": "microsoft.compute/virtualmachines",
                        "metricVisualization": { "displayName": "Available Memory" }
                      }
                    ],
                    "title": "Available Memory",
                    "titleKind": 2,
                    "visualization": { "chartType": 2 },
                    "timespan": { "relative": { "duration": 3600000 } }
                  }
                },
                "isOptional": true
              }
            ],
            "settings": {}
          }
        },
        "3": {
          "position": { "x": 8, "y": 1, "colSpan": 4, "rowSpan": 3 },
          "metadata": {
            "type": "Extension/HubsExtension/PartType/MonitorChartPart",
            "inputs": [
              {
                "name": "sharedTimeRange",
                "isOptional": true
              },
              {
                "name": "options",
                "value": {
                  "chart": {
                    "metrics": [
                      {
                        "resourceMetadata": { "id": "${vm_resource_id}" },
                        "name": "VmAvailabilityMetric",
                        "aggregationType": 4,
                        "namespace": "microsoft.compute/virtualmachines",
                        "metricVisualization": { "displayName": "VM Availability" }
                      }
                    ],
                    "title": "VM Availability",
                    "titleKind": 2,
                    "visualization": { "chartType": 2 },
                    "timespan": { "relative": { "duration": 3600000 } }
                  }
                },
                "isOptional": true
              }
            ],
            "settings": {}
          }
        },
        "4": {
          "position": { "x": 0, "y": 4, "colSpan": 4, "rowSpan": 3 },
          "metadata": {
            "type": "Extension/HubsExtension/PartType/MonitorChartPart",
            "inputs": [
              {
                "name": "sharedTimeRange",
                "isOptional": true
              },
              {
                "name": "options",
                "value": {
                  "chart": {
                    "metrics": [
                      {
                        "resourceMetadata": { "id": "${vm_resource_id}" },
                        "name": "Network In Total",
                        "aggregationType": 1,
                        "namespace": "microsoft.compute/virtualmachines",
                        "metricVisualization": { "displayName": "Network In" }
                      },
                      {
                        "resourceMetadata": { "id": "${vm_resource_id}" },
                        "name": "Network Out Total",
                        "aggregationType": 1,
                        "namespace": "microsoft.compute/virtualmachines",
                        "metricVisualization": { "displayName": "Network Out" }
                      }
                    ],
                    "title": "Network I/O",
                    "titleKind": 2,
                    "visualization": { "chartType": 2 },
                    "timespan": { "relative": { "duration": 3600000 } }
                  }
                },
                "isOptional": true
              }
            ],
            "settings": {}
          }
        },
        "5": {
          "position": { "x": 4, "y": 4, "colSpan": 4, "rowSpan": 3 },
          "metadata": {
            "type": "Extension/HubsExtension/PartType/MonitorChartPart",
            "inputs": [
              {
                "name": "sharedTimeRange",
                "isOptional": true
              },
              {
                "name": "options",
                "value": {
                  "chart": {
                    "metrics": [
                      {
                        "resourceMetadata": { "id": "${vm_resource_id}" },
                        "name": "Disk Read Bytes",
                        "aggregationType": 1,
                        "namespace": "microsoft.compute/virtualmachines",
                        "metricVisualization": { "displayName": "Disk Read" }
                      },
                      {
                        "resourceMetadata": { "id": "${vm_resource_id}" },
                        "name": "Disk Write Bytes",
                        "aggregationType": 1,
                        "namespace": "microsoft.compute/virtualmachines",
                        "metricVisualization": { "displayName": "Disk Write" }
                      }
                    ],
                    "title": "Disk Throughput",
                    "titleKind": 2,
                    "visualization": { "chartType": 2 },
                    "timespan": { "relative": { "duration": 3600000 } }
                  }
                },
                "isOptional": true
              }
            ],
            "settings": {}
          }
        },
        "6": {
          "position": { "x": 8, "y": 4, "colSpan": 4, "rowSpan": 3 },
          "metadata": {
            "type": "Extension/HubsExtension/PartType/MonitorChartPart",
            "inputs": [
              {
                "name": "sharedTimeRange",
                "isOptional": true
              },
              {
                "name": "options",
                "value": {
                  "chart": {
                    "metrics": [
                      {
                        "resourceMetadata": { "id": "${vm_resource_id}" },
                        "name": "OS Disk Read Operations/Sec",
                        "aggregationType": 4,
                        "namespace": "microsoft.compute/virtualmachines",
                        "metricVisualization": { "displayName": "Read IOPS" }
                      },
                      {
                        "resourceMetadata": { "id": "${vm_resource_id}" },
                        "name": "OS Disk Write Operations/Sec",
                        "aggregationType": 4,
                        "namespace": "microsoft.compute/virtualmachines",
                        "metricVisualization": { "displayName": "Write IOPS" }
                      }
                    ],
                    "title": "Disk IOPS",
                    "titleKind": 2,
                    "visualization": { "chartType": 2 },
                    "timespan": { "relative": { "duration": 3600000 } }
                  }
                },
                "isOptional": true
              }
            ],
            "settings": {}
          }
        },
        "7": {
          "position": { "x": 0, "y": 7, "colSpan": 12, "rowSpan": 1 },
          "metadata": {
            "type": "Extension/HubsExtension/PartType/MarkdownPart",
            "inputs": [],
            "settings": {
              "content": {
                "settings": {
                  "content": "PostgreSQL and ShadowTraffic metrics (connections, replication slots, WAL size, Docker health) are collected by a cron job on the VM. SSH in to view: `cat /var/log/wsa-monitor.log`",
                  "title": "",
                  "subtitle": "",
                  "markdownSource": 1
                }
              }
            }
          }
        }
      }
    }
  }
}

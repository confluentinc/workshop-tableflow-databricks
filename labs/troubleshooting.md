# Troubleshooting

Review the resources below if you run into issues while going through instructions in this workshop.

## 🏗️ Terraform

### Provider Integration Deletion Conflicts

**Issue:**

When running `terraform destroy -auto-approve` to destroy workshop resources, you encounter a `409 Conflict` error:

```
Error: error deleting Provider Integration (pixxxxxxx): 409 Conflict: Provider integration pixxxxxxx cannot be deleted as it is being used by active TableFlow instances
```

**Why This Happens:**

Confluent Cloud prevents deletion of provider integrations that are actively being used by TableFlow instances. This dependency conflict occurs when:

1. **TableFlow sync is still active** - Data is still flowing from topics to Delta Lake
2. **Resource deletion order** - Terraform tries to delete the integration before stopping TableFlow
3. **API timing issues** - Brief delays in resource cleanup can cause conflicts

**Resolution:**

1. **Remove the problematic resource from Terraform state:**

   ```sh
   terraform state rm confluent_provider_integration.s3_tableflow_integration
   ```

   > [!NOTE]
   > **Terraform State Removal**
   >
   > This command removes the resource from Terraform's state file but does **not** delete the actual resource from Confluent Cloud. The resource will be force-removed when the Confluent Environment gets deleted in the next step.

2. **Rerun the terraform destroy command:**

   ```sh
   terraform destroy -auto-approve
   ```

3. **If issues persist**, manually stop TableFlow in Confluent Console before running destroy

## 🗄️ Oracle Database

### Database Connection Failures

**Issue:**

When attempting to connect to the Oracle database, you encounter this type of error:

**ORA-12514 Error in Confluent Cloud:**

![TNS Listener not listening](../assets/images/confluent_oracle_connector_listener.png)

**ORA-12514 Error in Shadow Traffic:**

![Shadow Traffic Oracle Error](../assets/images/shadowtraffic_oracle_not_spun_up_yet.png)

```sh
Caused by: oracle.net.ns.NetException: ORA-12514: Cannot connect to database. Service XEPDB1 is not registered with the listener at host 18.221.129.77 port 1521. (CONNECTION_ID=iRbDfISmRYSBvxFTxgCb8Q==)
https://docs.oracle.com/error-help/db/ora-12514/
        at oracle.net.ns.NSProtocolNIO.createRefusePacketException(NSProtocolNIO.java:916)
        at oracle.net.ns.NSProtocolNIO.handleConnectPacketResponse(NSProtocolNIO.java:462)
```

**Why This Happens:**

This error occurs when the Oracle database service has not yet fully initialized. Common causes include:

1. **Database still starting up** - Oracle XE container is still initializing after EC2 launch
2. **Network connectivity issues** - Security groups or VPC routing problems
3. **Service registration delays** - XEPDB1 pluggable database hasn't registered with the listener yet

**Resolution:**

1. **Wait for initialization** - Oracle XE can take 10-15 minutes to fully start after EC2 instance launch
2. **Verify connectivity** - Ensure EC2 instance is running and accessible
3. **Check service status** - Connect to the instance and verify Oracle services are running

### Oracle Database Diagnostics

**Issue:**

You need to troubleshoot Oracle database issues, verify XStream configuration, or check service status.

**Why This Happens:**

Oracle database issues can stem from:

1. **XStream configuration problems** - Xstream Outbound server not properly configured
2. **Container issues** - Docker container may have stopped or crashed
3. **Service dependencies** - Database services may not have started in correct order

**Resolution:**

1. **Get connection details** from Terraform output:

```sh
terraform output oracle_vm
```

2. **Connect to the Oracle EC2 instance** using SSH:

Copy and paste the `ssh_command` output from the above command and execute it your shell:

```sh
ssh -i sshkey-[YOUR_KEY_NAME].pem ec2-user@[YOUR_INSTANCE_DNS]
```

   > [!NOTE]
   > **Key Fingerprint**
   >
   > If prompted to add the key fingerprint to your known hosts, enter `yes`.

3. **Access the Oracle XE container**:

```sh
sudo docker exec -it oracle-xe sqlplus system/Welcome1@localhost:1521/XE
```

4. **Verify XStream outbound server** exists in SQL*Plus:

```sql
SELECT SERVER_NAME, CAPTURE_NAME, SOURCE_DATABASE, QUEUE_OWNER, QUEUE_NAME FROM ALL_XSTREAM_OUTBOUND;
```

   **Expected result:** You should see an entry for the "xout" server with source database `XEPDB1`

5. **Alter Session to XEPDB1**

```sql
ALTER SESSION SET CONTAINER = XEPDB1;
```

```sql
DESCRIBE SAMPLE.CUSTOMER;
```

```sql
SELECT COLUMN_NAME
FROM ALL_CONS_COLUMNS
WHERE CONSTRAINT_NAME = (
    SELECT CONSTRAINT_NAME
    FROM ALL_CONSTRAINTS
    WHERE TABLE_NAME = 'CUSTOMER'
    AND OWNER = 'SAMPLE'
    AND CONSTRAINT_TYPE = 'P'
);
```

6. **Check container status** if connection fails:

```sh
sudo docker ps
sudo docker logs oracle-xe
```

## ⚡ Flink

### Streaming Join Issues with CDC Sources

**Issue:**

When working with Oracle CDC sources in Flink SQL, you may encounter various join-related errors such as:

```
Temporal Table Join requires primary key in versioned table, but no primary key can be found.
StreamPhysicalIntervalJoin doesn't support consuming update and delete changes
```

**Comprehensive Solution:**

For a complete analysis of streaming join challenges with CDC sources and proven working solutions, see:

**[Flink Streaming Joins with CDC Sources: A Journey of Discovery](flink-joins.md)**

This comprehensive guide documents our complete journey from initial temporal join failures through to reliable production solutions, including:

- ✅ **Experiment results** from all attempted approaches
- ✅ **Root cause analysis** of CDC stream compatibility issues
- ✅ **Working solutions** using snapshot tables + interval joins
- ✅ **Hybrid timestamp strategies** for optimal results
- ✅ **Production recommendations** for different use cases

**Quick Resolution for Workshop:**

If you need an immediate working solution, use the **snapshot + interval joins approach**:

1. **Create snapshot tables** from CDC sources:

   ```sql
   CREATE TABLE CUSTOMER_SNAPSHOT AS (
   SELECT CUSTOMER_ID, EMAIL, FIRST_NAME, LAST_NAME, BIRTH_DATE, CREATED_AT
   FROM `riverhotel.SAMPLE.CUSTOMER`
   );
   ALTER TABLE CUSTOMER_SNAPSHOT SET ('changelog.mode' = 'append');

   CREATE TABLE HOTEL_SNAPSHOT AS (
   SELECT HOTEL_ID, NAME, CLASS, DESCRIPTION, CITY, COUNTRY, ROOM_CAPACITY, CREATED_AT
   FROM `riverhotel.SAMPLE.HOTEL`
   );
   ALTER TABLE HOTEL_SNAPSHOT SET ('changelog.mode' = 'append');
   ```

2. **Use interval joins with snapshots**:

   ```sql
   FROM `bookings` b
      JOIN `CUSTOMER_SNAPSHOT` c
        ON c.`EMAIL` = b.`CUSTOMER_EMAIL`
        AND c.`$rowtime` BETWEEN b.`$rowtime` - INTERVAL '7' DAY AND b.`$rowtime` + INTERVAL '7' DAY
      JOIN `HOTEL_SNAPSHOT` h
        ON h.`HOTEL_ID` = b.`HOTEL_ID`
        AND h.`$rowtime` BETWEEN b.`$rowtime` - INTERVAL '7' DAY AND b.`$rowtime` + INTERVAL '7' DAY
   ```

> **Note**: Direct interval joins with CDC sources will fail with "StreamPhysicalIntervalJoin doesn't support consuming update and delete changes"

### Streaming Join State Management

**Issue:**

Regular inner joins in streaming queries generate warnings about requiring both sides of the table to be kept in state indefinitely.

**Why This Happens:**

Regular streaming joins maintain infinite state on both sides, leading to potential memory issues and performance degradation over time.

**Resolution:**

Use streaming-optimized join patterns:

1. **Temporal joins** for dimension table lookups (when primary keys are available)
2. **Interval joins** with time bounds to limit state retention
3. **TTL configuration** to automatically expire old state:

   ```sql
   SET 'table.exec.state.ttl' = '7d';
   ```

## 🧱 Databricks

### External Delta Lake Table Creation Failures

**Issue:**

When running this statement to create an external table from S3 data:

```sql
CREATE TABLE <<table_name>>
  USING DELTA
LOCATION '<<S3 URI>>';
```

You encounter this error:

```sh
[DELTA_CANNOT_CREATE_LOG_PATH] Cannot create s3://<full_path>
```

![Delta error create log path](../assets/images/databricks_error_cannot_create_path.png)

**Why This Happens:**

This Delta Lake table creation failure can occur due to several factors:

1. **Account type limitations** - (Most likely) Databricks free trial accounts have more restrictive permissions, as this error seems to be occurring only in free trial accounts
2. **Service Principal permissions** - Insufficient IAM or Databricks permissions for the service principal
3. **S3 bucket access issues** - External location or storage credential configuration problems
4. **Unity Catalog restrictions** - Workspace may not have proper Unity Catalog setup

**Resolution:**

Try these solutions in order:

1. **Verify external location configuration** - Ensure your external location is properly configured in Databricks
2. **Check service principal permissions** - Verify IAM and Databricks permissions are correctly set
3. **Use alternative account type**:
   - Clean up current workshop resources: `terraform destroy -auto-approve`
   - Restart workshop with a Databricks paid account or different free edition account
4. **Create new service principal**:
   - Clean up current workshop resources
   - Generate a new Databricks Service Principal during redeployment

> [!TIP]
> **Manual External Location Setup**
>
> For additional context on manual external location configuration, see the [Confluent TableFlow Delta Lake documentation](https://docs.confluent.io/cloud/current/topics/tableflow/get-started/quick-start-delta-lake.html#create-and-query-an-external-delta-lake-table).

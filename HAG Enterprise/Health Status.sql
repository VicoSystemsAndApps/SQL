-- Run on both Primary and Secondary

-- Version/build check
SELECT  @@SERVERNAME    AS server_name
,       @@VERSION       AS version_build;


-- Overall state per replica
SELECT  ag.name                         AS ag_name
,       r.replica_server_name
,       rs.role_desc
,       rs.operational_state_desc
,       rs.connected_state_desc
,       rs.synchronization_health_desc
FROM    sys.availability_replicas               r
JOIN    sys.availability_groups                 ag  ON  r.group_id      = ag.group_id
JOIN    sys.dm_hadr_availability_replica_states rs  ON  r.group_id      = rs.group_id 
                                                    AND r.replica_id    = rs.replica_id;

-- Per-database sync state
SELECT      DB_NAME(drs.database_id)        AS db
,           ag.name                         AS ag_name
,           drs.is_local
,           drs.synchronization_state_desc
,           drs.synchronization_health_desc
,           drs.is_suspended
,           drs.redo_queue_size
,           drs.log_send_queue_size
,           drs.suspend_reason_desc
FROM        sys.dm_hadr_database_replica_states drs
JOIN        sys.availability_groups             ag  ON  drs.group_id      = ag.group_id
ORDER BY    db;

-- With endpoint metadata join
SELECT  e.name
,       e.protocol_desc
,       e.type_desc
,       e.state_desc
,       te.is_dynamic_port
,       te.port
,       te.ip_address
FROM    sys.endpoints       e
JOIN    sys.tcp_endpoints   te ON e.endpoint_id = te.endpoint_id
WHERE   e.type_desc = 'DATABASE_MIRRORING';


-- Endpoint status
-- Basic endpoint info
SELECT  name
,       state_desc
,       role_desc
,       type_desc
,       protocol_desc
,       encryption_algorithm_desc
FROM    sys.database_mirroring_endpoints;


-- Replica commit/failover modes
SELECT  replica_server_name
,       availability_mode_desc
,       failover_mode_desc
,       seeding_mode_desc
FROM    sys.availability_replicas;


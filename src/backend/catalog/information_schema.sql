/*
 * SQL Information Schema
 * as defined in ISO 9075-2:1999 chapter 20
 *
 * Copyright 2002, PostgreSQL Global Development Group
 *
 * $Id: information_schema.sql,v 1.8 2003/06/11 09:23:55 petere Exp $
 */


/*
 * 20.2
 * INFORMATION_SCHEMA schema
 */

CREATE SCHEMA information_schema;
GRANT USAGE ON SCHEMA information_schema TO PUBLIC;
SET search_path TO information_schema, public;


-- Note: 20.3 follows later.  Some genius screwed up the order in the standard.


/*
 * 20.4
 * CARDINAL_NUMBER domain
 */

CREATE DOMAIN cardinal_number AS integer
    CONSTRAINT cardinal_number_domain_check CHECK (value >= 0);


/*
 * 20.5
 * CHARACTER_DATA domain
 */

CREATE DOMAIN character_data AS character varying;


/*
 * 20.6
 * SQL_IDENTIFIER domain
 */

CREATE DOMAIN sql_identifier AS character varying;


/*
 * 20.3
 * INFORMATION_SCHEMA_CATALOG_NAME view
 */

CREATE VIEW information_schema_catalog_name AS
    SELECT CAST(current_database() AS sql_identifier) AS catalog_name;

GRANT SELECT ON information_schema_catalog_name TO PUBLIC;


/*
 * 20.7
 * TIME_STAMP domain
 */

CREATE DOMAIN time_stamp AS timestamp(2)
    DEFAULT current_timestamp(2);


/*
 * 20.13
 * CHECK_CONSTRAINTS view
 */

CREATE VIEW check_constraints AS
    SELECT CAST(current_database() AS sql_identifier) AS constraint_catalog,
           CAST(rs.nspname AS sql_identifier) AS constraint_schema,
           CAST(con.conname AS sql_identifier) AS constraint_name,
           CAST(con.consrc AS character_data) AS check_clause
    FROM pg_namespace rs,
         pg_constraint con
           LEFT OUTER JOIN pg_class c on (c.oid = con.conrelid)
           LEFT OUTER JOIN pg_type t on (t.oid = con.contypid),
         pg_user u
    WHERE rs.oid = con.connamespace
          AND u.usesysid = coalesce(c.relowner, t.typowner)
          AND u.usename = current_user
          AND con.contype = 'c';

GRANT SELECT ON check_constraints TO PUBLIC;


/*
 * 20.15
 * COLUMN_DOMAIN_USAGE view
 */

CREATE VIEW column_domain_usage AS
    SELECT CAST(current_database() AS sql_identifier) AS domain_catalog,
           CAST(nt.nspname AS sql_identifier) AS domain_schema,
           CAST(t.typname AS sql_identifier) AS domain_name,
           CAST(current_database() AS sql_identifier) AS table_catalog,
           CAST(nc.nspname AS sql_identifier) AS table_schema,
           CAST(c.relname AS sql_identifier) AS table_name,
           CAST(a.attname AS sql_identifier) AS column_name

    FROM pg_type t, pg_namespace nt, pg_class c, pg_namespace nc,
         pg_attribute a, pg_user u

    WHERE t.typnamespace = nt.oid AND t.typtype = 'd'
          AND c.relnamespace = nc.oid AND a.attrelid = c.oid
          AND a.atttypid = t.oid AND t.typowner = u.usesysid
          AND u.usename = current_user;

GRANT SELECT ON column_domain_usage TO PUBLIC;


/*
 * 20.16
 * COLUMN_PRIVILEGES
 */

-- PostgreSQL does not have column privileges, so this view is empty.
-- (Table privileges do not also count as column privileges.)

CREATE VIEW column_privileges AS
    SELECT CAST(null AS sql_identifier) AS grantor,
           CAST(null AS sql_identifier) AS grantee,
           CAST(null AS sql_identifier) AS table_catalog,
           CAST(null AS sql_identifier) AS table_schema,
           CAST(null AS sql_identifier) AS table_name,
           CAST(null AS sql_identifier) AS column_name,
           CAST(null AS character_data) AS privilege_type,
           CAST(null AS character_data) AS is_grantable
    WHERE false;

GRANT SELECT ON column_privileges TO PUBLIC;


/*
 * 20.18
 * COLUMNS view
 */

CREATE VIEW columns AS
    SELECT CAST(current_database() AS sql_identifier) AS table_catalog,
           CAST(nc.nspname AS sql_identifier) AS table_schema,
           CAST(c.relname AS sql_identifier) AS table_name,
           CAST(a.attname AS sql_identifier) AS column_name,
           CAST(a.attnum AS cardinal_number) AS ordinal_position,
           CAST(
             CASE WHEN u.usename = current_user THEN a.adsrc ELSE null END
             AS character_data)
             AS column_default,
           CAST(CASE WHEN a.attnotnull OR (t.typtype = 'd' AND t.typnotnull) THEN 'NO' ELSE 'YES' END
             AS character_data)
             AS is_nullable,

           CAST(
             CASE WHEN t.typtype = 'd' THEN
               CASE WHEN nbt.nspname = 'pg_catalog'
                    THEN format_type(t.typbasetype, null)
                    ELSE 'USER-DEFINED' END
             ELSE
               CASE WHEN nt.nspname = 'pg_catalog'
                    THEN format_type(a.atttypid, null)
                    ELSE 'USER-DEFINED' END
             END
             AS character_data)
             AS data_type,

           CAST(
             CASE WHEN t.typtype = 'd' THEN
               CASE WHEN t.typbasetype IN (25, 1042, 1043, 1560, 1562) AND t.typtypmod <> -1
                    THEN t.typtypmod - 4
                    ELSE null END
             ELSE
               CASE WHEN a.atttypid IN (25, 1042, 1043, 1560, 1562) AND a.atttypmod <> -1
                    THEN a.atttypmod - 4
                    ELSE null END
             END
             AS cardinal_number)
             AS character_maximum_length,

           CAST(
             CASE WHEN t.typtype = 'd' THEN
               CASE WHEN t.typbasetype IN (25, 1042, 1043) THEN 2^30 ELSE null END
             ELSE
               CASE WHEN a.atttypid IN (25, 1042, 1043) THEN 2^30 ELSE null END
             END
             AS cardinal_number)
             AS character_octet_length,

           CAST(
             CASE (CASE WHEN t.typtype = 'd' THEN t.typbasetype ELSE a.atttypid END)
               WHEN 21 /*int2*/ THEN 16
               WHEN 23 /*int4*/ THEN 32
               WHEN 20 /*int8*/ THEN 64
               WHEN 1700 /*numeric*/ THEN ((CASE WHEN t.typtype = 'd' THEN t.typtypmod ELSE a.atttypmod END - 4) >> 16) & 65535
               WHEN 700 /*float4*/ THEN 24 /*FLT_MANT_DIG*/
               WHEN 701 /*float8*/ THEN 53 /*DBL_MANT_DIG*/
               ELSE null END
             AS cardinal_number)
             AS numeric_precision,

           CAST(
             CASE WHEN t.typtype = 'd' THEN
               CASE WHEN t.typbasetype IN (21, 23, 20, 700, 701) THEN 2
                    WHEN t.typbasetype IN (1700) THEN 10
                    ELSE null END
             ELSE
               CASE WHEN a.atttypid IN (21, 23, 20, 700, 701) THEN 2
                    WHEN a.atttypid IN (1700) THEN 10
                    ELSE null END
             END
             AS cardinal_number)
             AS numeric_precision_radix,

           CAST(
             CASE WHEN t.typtype = 'd' THEN
               CASE WHEN t.typbasetype IN (21, 23, 20) THEN 0
                    WHEN t.typbasetype IN (1700) THEN (t.typtypmod - 4) & 65535
                    ELSE null END
             ELSE
               CASE WHEN a.atttypid IN (21, 23, 20) THEN 0
                    WHEN a.atttypid IN (1700) THEN (a.atttypmod - 4) & 65535
                    ELSE null END
             END
             AS cardinal_number)
             AS numeric_scale,

           CAST(
             CASE WHEN t.typtype = 'd' THEN
               CASE WHEN t.typbasetype IN (1083, 1114, 1184, 1266)
                    THEN (CASE WHEN t.typtypmod <> -1 THEN t.typtypmod ELSE null END)
                    WHEN t.typbasetype IN (1186)
                    THEN (CASE WHEN t.typtypmod <> -1 THEN t.typtypmod & 65535 ELSE null END)
                    ELSE null END
             ELSE
               CASE WHEN a.atttypid IN (1083, 1114, 1184, 1266)
                    THEN (CASE WHEN a.atttypmod <> -1 THEN a.atttypmod ELSE null END)
                    WHEN a.atttypid IN (1186)
                    THEN (CASE WHEN a.atttypmod <> -1 THEN a.atttypmod & 65535 ELSE null END)
                    ELSE null END
             END
             AS cardinal_number)
             AS datetime_precision,

           CAST(null AS character_data) AS interval_type, -- XXX
           CAST(null AS character_data) AS interval_precision, -- XXX

           CAST(null AS sql_identifier) AS character_set_catalog,
           CAST(null AS sql_identifier) AS character_set_schema,
           CAST(null AS sql_identifier) AS character_set_name,

           CAST(null AS sql_identifier) AS collation_catalog,
           CAST(null AS sql_identifier) AS collation_schema,
           CAST(null AS sql_identifier) AS collation_name,

           CAST(CASE WHEN t.typtype = 'd' THEN current_database() ELSE null END
             AS sql_identifier) AS domain_catalog,
           CAST(CASE WHEN t.typtype = 'd' THEN nt.nspname ELSE null END
             AS sql_identifier) AS domain_schema,
           CAST(CASE WHEN t.typtype = 'd' THEN t.typname ELSE null END
             AS sql_identifier) AS domain_name,

           CAST(current_database() AS sql_identifier) AS udt_catalog,
           CAST(coalesce(nbt.nspname, nt.nspname) AS sql_identifier) AS udt_schema,
           CAST(coalesce(bt.typname, t.typname) AS sql_identifier) AS udt_name,

           CAST(null AS sql_identifier) AS scope_catalog,
           CAST(null AS sql_identifier) AS scope_schema,
           CAST(null AS sql_identifier) AS scope_name,

           CAST(null AS cardinal_number) AS maximum_cardinality,
           CAST(t.oid AS sql_identifier) AS dtd_identifier,
           CAST('NO' AS character_data) AS is_self_referencing

    FROM (pg_attribute LEFT JOIN pg_attrdef ON attrelid = adrelid AND attnum = adnum) AS a,
         pg_class c, pg_namespace nc, pg_user u,
         (pg_type t JOIN pg_namespace nt ON (t.typnamespace = nt.oid))
           LEFT JOIN (pg_type bt JOIN pg_namespace nbt ON (bt.typnamespace = nbt.oid))
           ON (t.typtype = 'd' AND t.typbasetype = bt.oid)

    WHERE a.attrelid = c.oid
          AND a.atttypid = t.oid
          AND u.usesysid = c.relowner
          AND nc.oid = c.relnamespace

          AND a.attnum > 0 AND NOT a.attisdropped AND c.relkind in ('r', 'v')

          AND (u.usename = current_user
               OR has_table_privilege(c.oid, 'SELECT')
               OR has_table_privilege(c.oid, 'INSERT')
               OR has_table_privilege(c.oid, 'UPDATE')
               OR has_table_privilege(c.oid, 'DELETE')
               OR has_table_privilege(c.oid, 'RULE')
               OR has_table_privilege(c.oid, 'RERERENCES')
               OR has_table_privilege(c.oid, 'TRIGGER') );

GRANT SELECT ON columns TO PUBLIC;


/*
 * 20.19
 * CONSTRAINT_COLUMN_USAGE view
 */

-- FIXME: This only works for check constraints so far; for the others
-- we need a built-in way to convert arrays to virtual tables.

CREATE VIEW constraint_column_usage AS
    SELECT CAST(current_database() AS sql_identifier) AS table_catalog,
           CAST(tblschema AS sql_identifier) AS table_schema,
           CAST(tblname AS sql_identifier) AS table_name,
           CAST(colname AS sql_identifier) AS column_name,
           CAST(current_database() AS sql_identifier) AS constraint_catalog,
           CAST(cstrschema AS sql_identifier) AS constraint_schema,
           CAST(cstrname AS sql_identifier) AS constraint_name

    FROM (
        SELECT DISTINCT nr.nspname, r.relname, r.relowner, a.attname, nc.nspname, c.conname
          FROM pg_namespace nr, pg_class r, pg_attribute a, pg_depend d, pg_namespace nc, pg_constraint c
          WHERE nr.oid = r.relnamespace
            AND r.oid = a.attrelid
            AND d.refclassid = (SELECT oid FROM pg_class WHERE relname = 'pg_class')
            AND d.refobjid = r.oid
            AND d.refobjsubid = a.attnum
            AND d.classid = (SELECT oid FROM pg_class WHERE relname = 'pg_constraint')
            AND d.objid = c.oid
            AND c.connamespace = nc.oid
            AND c.contype = 'c'
      ) AS x (tblschema, tblname, tblowner, colname, cstrschema, cstrname),
      pg_user u

    WHERE x.tblowner = u.usesysid AND u.usename = current_user;

GRANT SELECT ON constraint_column_usage TO PUBLIC;


/*
 * 20.20
 * CONSTRAINT_TABLE_USAGE view
 */

CREATE VIEW constraint_table_usage AS
    SELECT CAST(current_database() AS sql_identifier) AS table_catalog,
           CAST(nr.nspname AS sql_identifier) AS table_schema,
           CAST(r.relname AS sql_identifier) AS table_name,
           CAST(current_database() AS sql_identifier) AS constraint_catalog,
           CAST(nc.nspname AS sql_identifier) AS constraint_schema,
           CAST(c.conname AS sql_identifier) AS constraint_name

    FROM pg_constraint c, pg_namespace nc,
         pg_class r, pg_namespace nr,
         pg_user u

    WHERE c.connamespace = nc.oid AND r.relnamespace = nr.oid
          AND ( (c.contype = 'f' AND c.confrelid = r.oid)
             OR (c.contype IN ('p', 'u') AND c.conrelid = r.oid) )
          AND r.relowner = u.usesysid AND u.usename = current_user;

GRANT SELECT ON constraint_table_usage TO PUBLIC;


/*
 * 20.24
 * DOMAIN_CONSTRAINTS view
 */

CREATE VIEW domain_constraints AS
    SELECT CAST(current_database() AS sql_identifier) AS constraint_catalog,
           CAST(rs.nspname AS sql_identifier) AS constraint_schema,
           CAST(con.conname AS sql_identifier) AS constraint_name,
           CAST(current_database() AS sql_identifier) AS domain_catalog,
           CAST(n.nspname AS sql_identifier) AS domain_schema,
           CAST(t.typname AS sql_identifier) AS domain_name,
           CAST(CASE WHEN condeferrable THEN 'YES' ELSE 'NO' END
             AS character_data) AS is_deferrable,
           CAST(CASE WHEN condeferred THEN 'YES' ELSE 'NO' END
             AS character_data) AS initially_deferred
    FROM pg_namespace rs, pg_namespace n, pg_constraint con, pg_type t, pg_user u
    WHERE rs.oid = con.connamespace
          AND n.oid = t.typnamespace
          AND u.usesysid = t.typowner
          AND u.usename = current_user
          AND t.oid = con.contypid;

GRANT SELECT ON domain_constraints TO PUBLIC;


/*
 * 20.26
 * DOMAINS view
 */

CREATE VIEW domains AS
    SELECT CAST(current_database() AS sql_identifier) AS domain_catalog,
           CAST(nt.nspname AS sql_identifier) AS domain_schema,
           CAST(t.typname AS sql_identifier) AS domain_name,

           CAST(
             CASE WHEN nbt.nspname = 'pg_catalog'
               THEN format_type(t.typbasetype, null)
               ELSE 'USER-DEFINED' END
             AS character_data)
             AS data_type,

           CAST(
             CASE WHEN t.typbasetype IN (25, 1042, 1043, 1560, 1562) AND t.typtypmod <> -1
                  THEN t.typtypmod - 4
                  ELSE null END
             AS cardinal_number)
             AS character_maximum_length,

           CAST(
             CASE WHEN t.typbasetype IN (25, 1042, 1043) THEN 2^30 ELSE null END
             AS cardinal_number)
             AS character_octet_length,

           CAST(null AS sql_identifier) AS character_set_catalog,
           CAST(null AS sql_identifier) AS character_set_schema,
           CAST(null AS sql_identifier) AS character_set_name,

           CAST(null AS sql_identifier) AS collation_catalog,
           CAST(null AS sql_identifier) AS collation_schema,
           CAST(null AS sql_identifier) AS collation_name,

           CAST(
             CASE t.typbasetype
               WHEN 21 /*int2*/ THEN 16
               WHEN 23 /*int4*/ THEN 32
               WHEN 20 /*int8*/ THEN 64
               WHEN 1700 /*numeric*/ THEN ((t.typtypmod - 4) >> 16) & 65535
               WHEN 700 /*float4*/ THEN 24 /*FLT_MANT_DIG*/
               WHEN 701 /*float8*/ THEN 53 /*DBL_MANT_DIG*/
               ELSE null END
             AS cardinal_number)
             AS numeric_precision,

           CAST(
             CASE WHEN t.typbasetype IN (21, 23, 20, 700, 701) THEN 2
                  WHEN t.typbasetype IN (1700) THEN 10
                  ELSE null END
             AS cardinal_number)
             AS numeric_precision_radix,

           CAST(
             CASE WHEN t.typbasetype IN (21, 23, 20) THEN 0
                  WHEN t.typbasetype IN (1700) THEN (t.typtypmod - 4) & 65535
                  ELSE null END
             AS cardinal_number)
             AS numeric_scale,

           CAST(
             CASE WHEN t.typbasetype IN (1083, 1114, 1184, 1266)
                  THEN (CASE WHEN t.typtypmod <> -1 THEN t.typtypmod ELSE null END)
                  WHEN t.typbasetype IN (1186)
                  THEN (CASE WHEN t.typtypmod <> -1 THEN t.typtypmod & 65535 ELSE null END)
                  ELSE null END
             AS cardinal_number)
             AS datetime_precision,

           CAST(null AS character_data) AS interval_type, -- XXX
           CAST(null AS character_data) AS interval_precision, -- XXX

           CAST(t.typdefault AS character_data) AS domain_default,

           CAST(current_database() AS sql_identifier) AS udt_catalog,
           CAST(nbt.nspname AS sql_identifier) AS udt_schema,
           CAST(bt.typname AS sql_identifier) AS udt_name,

           CAST(null AS sql_identifier) AS scope_catalog,
           CAST(null AS sql_identifier) AS scope_schema,
           CAST(null AS sql_identifier) AS scope_name,

           CAST(null AS cardinal_number) AS maximum_cardinality,
           CAST(t.oid AS sql_identifier) AS dtd_identifier

    FROM pg_type t, pg_namespace nt,
         pg_type bt, pg_namespace nbt

    WHERE t.typnamespace = nt.oid
          AND t.typbasetype = bt.oid
          AND bt.typnamespace = nbt.oid
          AND t.typtype = 'd';

GRANT SELECT ON domains TO PUBLIC;


/*
 * 20.33
 * PARAMETERS view
 */

CREATE VIEW parameters AS
    SELECT CAST(current_database() AS sql_identifier) AS specific_catalog,
           CAST(n.nspname AS sql_identifier) AS specific_schema,
           CAST(p.proname || '_' || CAST(p.oid AS text) AS sql_identifier) AS specific_name,
           CAST(n + 1 AS cardinal_number) AS ordinal_position,
           CAST('IN' AS character_data) AS parameter_mode,
           CAST('NO' AS character_data) AS is_result,
           CAST('NO' AS character_data) AS as_locator,
           CAST(null AS sql_identifier) AS parameter_name,
           CAST(
             CASE WHEN nt.nspname = 'pg_catalog' 
                  THEN format_type(t.oid, null)
                  ELSE 'USER-DEFINED' END AS character_data)
             AS data_type,
           CAST(null AS cardinal_number) AS character_maximum_length,
           CAST(null AS cardinal_number) AS character_octet_length,
           CAST(null AS sql_identifier) AS character_set_catalog,
           CAST(null AS sql_identifier) AS character_set_schema,
           CAST(null AS sql_identifier) AS character_set_name,
           CAST(null AS sql_identifier) AS collation_catalog,
           CAST(null AS sql_identifier) AS collation_schema,
           CAST(null AS sql_identifier) AS collation_name,
           CAST(null AS cardinal_number) AS numeric_precision,
           CAST(null AS cardinal_number) AS numeric_precision_radix,
           CAST(null AS cardinal_number) AS numeric_scale,
           CAST(null AS cardinal_number) AS datetime_precision,
           CAST(null AS character_data) AS interval_type,
           CAST(null AS character_data) AS interval_precision,
           CAST(current_database() AS sql_identifier) AS udt_catalog,
           CAST(nt.nspname AS sql_identifier) AS udt_schema,
           CAST(t.typname AS sql_identifier) AS udt_name,
           CAST(null AS sql_identifier) AS scope_catalog,
           CAST(null AS sql_identifier) AS scope_schema,
           CAST(null AS sql_identifier) AS scope_name,
           CAST(null AS cardinal_number) AS maximum_cardinality,
           CAST(t.oid AS sql_identifier) AS dtd_identifier

    FROM pg_namespace n, pg_proc p, pg_type t, pg_namespace nt, pg_user u,
         (select 0 union select 1 union select 2 union select 3 union select 4 union
          select 5 union select 6 union select 7 union select 8 union select 9 union
          select 10 union select 11 union select 12 union select 13 union select 14 union
          select 15 union select 16 union select 17 union select 18 union select 19 union
          select 20 union select 21 union select 22 union select 23 union select 24 union
          select 25 union select 26 union select 27 union select 28 union select 29 union
          select 30 union select 31) AS pos(n)

    WHERE n.oid = p.pronamespace AND p.pronargs > pos.n
          AND p.proargtypes[n] = t.oid AND t.typnamespace = nt.oid
          AND p.proowner = u.usesysid
          AND (u.usename = current_user OR has_function_privilege(p.oid, 'EXECUTE'));

GRANT SELECT ON parameters TO PUBLIC;


/*
 * 20.35
 * REFERENTIAL_CONSTRAINTS view
 */

CREATE VIEW referential_constraints AS
    SELECT CAST(current_database() AS sql_identifier) AS constraint_catalog,
           CAST(ncon.nspname AS sql_identifier) AS constraint_schema,
           CAST(con.conname AS sql_identifier) AS constraint_name,
           CAST(current_database() AS sql_identifier) AS unique_constraint_catalog,
           CAST(npkc.nspname AS sql_identifier) AS unique_constraint_schema,
           CAST(pkc.conname AS sql_identifier) AS unique_constraint_name,

           CAST(
             CASE con.confmatchtype WHEN 'f' THEN 'FULL'
                                    WHEN 'p' THEN 'PARTIAL'
                                    WHEN 'u' THEN 'NONE' END
             AS character_data) AS match_option,

           CAST(
             CASE con.confupdtype WHEN 'c' THEN 'CASCADE'
                                  WHEN 'n' THEN 'SET NULL'
                                  WHEN 'd' THEN 'SET DEFAULT'
                                  WHEN 'r' THEN 'RESTRICT'
                                  WHEN 'a' THEN 'NOACTION' END
             AS character_data) AS update_rule,

           CAST(
             CASE con.confdeltype WHEN 'c' THEN 'CASCADE'
                                  WHEN 'n' THEN 'SET NULL'
                                  WHEN 'd' THEN 'SET DEFAULT'
                                  WHEN 'r' THEN 'RESTRICT'
                                  WHEN 'a' THEN 'NOACTION' END
             AS character_data) AS delete_rule

    FROM pg_namespace ncon,
         pg_constraint con,
         pg_class c,
         pg_constraint pkc,
         pg_namespace npkc,
         pg_user u

    WHERE ncon.oid = con.connamespace
          AND con.conrelid = c.oid
          AND con.confkey = pkc.conkey
          AND pkc.connamespace = npkc.oid
          AND c.relowner = u.usesysid
          AND u.usename = current_user;

GRANT SELECT ON referential_constraints TO PUBLIC;


/*
 * 20.43
 * ROUTINE_PRIVILEGES view
 */

CREATE VIEW routine_privileges AS
    SELECT CAST(u_grantor.usename AS sql_identifier) AS grantor,
           CAST(u_grantee.usename AS sql_identifier) AS grantee,
           CAST(current_database() AS sql_identifier) AS specific_catalog,
           CAST(n.nspname AS sql_identifier) AS specific_schema,
           CAST(p.proname || '_' || CAST(p.oid AS text) AS sql_identifier) AS specific_name,
           CAST(current_database() AS sql_identifier) AS routine_catalog,
           CAST(n.nspname AS sql_identifier) AS routine_schema,
           CAST(p.proname AS sql_identifier) AS routine_name,
           CAST('EXECUTE' AS character_data) AS privilege_type,
           CAST(
             CASE WHEN aclcontains(p.proacl,
                                   makeaclitem(u_grantee.usesysid, 0, u_grantor.usesysid, 'EXECUTE', true))
                  THEN 'YES' ELSE 'NO' END AS character_data) AS is_grantable

    FROM pg_proc p,
         pg_namespace n,
         pg_user u_grantor,
         (SELECT usesysid, usename FROM pg_user UNION SELECT 0, 'PUBLIC') AS u_grantee

    WHERE p.pronamespace = n.oid
          AND aclcontains(p.proacl,
                          makeaclitem(u_grantee.usesysid, 0, u_grantor.usesysid, 'EXECUTE', false))
          AND (u_grantor.usename = current_user
               OR u_grantee.usename = current_user
               OR u_grantee.usename = 'PUBLIC');

GRANT SELECT ON routine_privileges TO PUBLIC;


/*
 * 20.45
 * ROUTINES view
 */

CREATE VIEW routines AS
    SELECT CAST(current_database() AS sql_identifier) AS specific_catalog,
           CAST(n.nspname AS sql_identifier) AS specific_schema,
           CAST(p.proname || '_' || CAST(p.oid AS text) AS sql_identifier) AS specific_name,
           CAST(current_database() AS sql_identifier) AS routine_catalog,
           CAST(n.nspname AS sql_identifier) AS routine_schema,
           CAST(p.proname AS sql_identifier) AS routine_name,
           CAST('FUNCTION' AS character_data) AS routine_type,
           CAST(null AS sql_identifier) AS module_catalog,
           CAST(null AS sql_identifier) AS module_schema,
           CAST(null AS sql_identifier) AS module_name,
           CAST(null AS sql_identifier) AS udt_catalog,
           CAST(null AS sql_identifier) AS udt_schema,
           CAST(null AS sql_identifier) AS udt_name,

           CAST(
             CASE WHEN nt.nspname = 'pg_catalog' 
                  THEN format_type(t.oid, null)
                  ELSE 'USER-DEFINED' END AS character_data)
             AS data_type,
           CAST(null AS cardinal_number) AS character_maximum_length,
           CAST(null AS cardinal_number) AS character_octet_length,
           CAST(null AS sql_identifier) AS character_set_catalog,
           CAST(null AS sql_identifier) AS character_set_schema,
           CAST(null AS sql_identifier) AS character_set_name,
           CAST(null AS sql_identifier) AS collation_catalog,
           CAST(null AS sql_identifier) AS collation_schema,
           CAST(null AS sql_identifier) AS collation_name,
           CAST(null AS cardinal_number) AS numeric_precision,
           CAST(null AS cardinal_number) AS numeric_precision_radix,
           CAST(null AS cardinal_number) AS numeric_scale,
           CAST(null AS cardinal_number) AS datetime_precision,
           CAST(null AS character_data) AS interval_type,
           CAST(null AS character_data) AS interval_precision,
           CAST(current_database() AS sql_identifier) AS type_udt_catalog,
           CAST(nt.nspname AS sql_identifier) AS type_udt_schema,
           CAST(t.typname AS sql_identifier) AS type_udt_name,
           CAST(null AS sql_identifier) AS scope_catalog,
           CAST(null AS sql_identifier) AS scope_schema,
           CAST(null AS sql_identifier) AS scope_name,
           CAST(null AS cardinal_number) AS maximum_cardinality,
           CAST(t.oid AS sql_identifier) AS dtd_identifier,

           CAST(CASE WHEN l.lanname = 'sql' THEN 'SQL' ELSE 'EXTERNAL' END AS character_data)
             AS routine_body,
           CAST(
             CASE WHEN u.usename = current_user THEN p.prosrc ELSE null END
             AS character_data) AS routine_definition,
           CAST(
             CASE WHEN l.lanname = 'c' THEN p.prosrc ELSE null END
             AS character_data) AS external_name,
           CAST(upper(l.lanname) AS character_data) AS external_language,

           CAST('GENERAL' AS character_data) AS parameter_style,
           CAST(CASE WHEN p.provolatile = 'i' THEN 'YES' ELSE 'NO' END AS character_data) AS is_deterministic,
           CAST('MODIFIES' AS character_data) AS sql_data_access,
           CAST(CASE WHEN p.proisstrict THEN 'YES' ELSE 'NO' END AS character_data) AS is_null_call,
           CAST(null AS character_data) AS sql_path,
           CAST('YES' AS character_data) AS schema_level_routine,
           CAST(0 AS cardinal_number) AS max_dynamic_result_sets,
           CAST(null AS character_data) AS is_user_defined_cast,
           CAST(null AS character_data) AS is_implicitly_invocable,
           CAST(CASE WHEN p.prosecdef THEN 'DEFINER' ELSE 'INVOKER' END AS character_data) AS security_type,
           CAST(null AS sql_identifier) AS to_sql_specific_catalog,
           CAST(null AS sql_identifier) AS to_sql_specific_schema,
           CAST(null AS sql_identifier) AS to_sql_specific_name,
           CAST('NO' AS character_data) AS as_locator

    FROM pg_namespace n, pg_proc p, pg_language l, pg_user u,
         pg_type t, pg_namespace nt

    WHERE n.oid = p.pronamespace AND p.prolang = l.oid AND p.proowner = u.usesysid
          AND p.prorettype = t.oid AND t.typnamespace = nt.oid
          AND (u.usename = current_user OR has_function_privilege(p.oid, 'EXECUTE'));

GRANT SELECT ON routines TO PUBLIC;


/*
 * 20.46
 * SCHEMATA view
 */

CREATE VIEW schemata AS
    SELECT CAST(current_database() AS sql_identifier) AS catalog_name,
           CAST(n.nspname AS sql_identifier) AS schema_name,
           CAST(u.usename AS sql_identifier) AS schema_owner,
           CAST(null AS sql_identifier) AS default_character_set_catalog,
           CAST(null AS sql_identifier) AS default_character_set_schema,
           CAST(null AS sql_identifier) AS default_character_set_name,
           CAST(null AS character_data) AS sql_path
    FROM pg_namespace n, pg_user u
    WHERE n.nspowner = u.usesysid AND u.usename = current_user;

GRANT SELECT ON schemata TO PUBLIC;


/*
 * 20.47
 * SQL_FEATURES table
 */

CREATE TABLE sql_features (
    feature_id          character_data,
    feature_name        character_data,
    sub_feature_id      character_data,
    sub_feature_name    character_data,
    is_supported        character_data,
    is_verified_by      character_data,
    comments            character_data
) WITHOUT OIDS;

-- Will be filled with external data by initdb.

GRANT SELECT ON sql_features TO PUBLIC;


/*
 * 20.48
 * SQL_IMPLEMENTATION_INFO table
 */

-- Note: Implementation information items are defined in ISO 9075-3:1999,
-- clause 7.1.

CREATE TABLE sql_implementation_info (
    implementation_info_id      character_data,
    implementation_info_name    character_data,
    integer_value               cardinal_number,
    character_value             character_data,
    comments                    character_data
) WITHOUT OIDS;

INSERT INTO sql_implementation_info VALUES ('10003', 'CATALOG NAME', NULL, 'Y', NULL);
INSERT INTO sql_implementation_info VALUES ('10004', 'COLLATING SEQUENCE', NULL, '', 'not supported');
INSERT INTO sql_implementation_info VALUES ('23',    'CURSOR COMMIT BEHAVIOR', 1, NULL, 'close cursors and retain prepared statements');
INSERT INTO sql_implementation_info VALUES ('2',     'DATA SOURCE NAME', NULL, '', NULL);
INSERT INTO sql_implementation_info VALUES ('17',    'DBMS NAME', NULL, (select trim(trailing ' ' from substring(version() from '^[^0-9]*'))), NULL);
INSERT INTO sql_implementation_info VALUES ('18',    'DBMS VERSION', NULL, '???', NULL); -- filled by initdb
INSERT INTO sql_implementation_info VALUES ('26',    'DEFAULT TRANSACTION ISOLATION', 2, NULL, 'READ COMMITED; user-settable');
INSERT INTO sql_implementation_info VALUES ('28',    'IDENTIFIER CASE', 3, NULL, 'stored in mixed case - case sensitive');
INSERT INTO sql_implementation_info VALUES ('85',    'NULL COLLATION', 0, NULL, 'nulls higher than non-nulls');
INSERT INTO sql_implementation_info VALUES ('13',    'SERVER NAME', NULL, '', NULL);
INSERT INTO sql_implementation_info VALUES ('94',    'SPECIAL CHARACTERS', NULL, '', 'all non-ASCII characters allowed');
INSERT INTO sql_implementation_info VALUES ('46',    'TRANSACTION CAPABLE', 2, NULL, 'both DML and DDL');

GRANT SELECT ON sql_implementation_info TO PUBLIC;


/*
 * 20.49
 * SQL_LANGUAGES table
 */

CREATE TABLE sql_languages (
    sql_language_source         character_data,
    sql_language_year           character_data,
    sql_language_conformance    character_data,
    sql_language_integrity      character_data,
    sql_language_implementation character_data,
    sql_language_binding_style  character_data,
    sql_language_programming_language character_data
) WITHOUT OIDS;

INSERT INTO sql_languages VALUES ('ISO 9075', '1999', 'CORE', NULL, NULL, 'DIRECT', NULL);
INSERT INTO sql_languages VALUES ('ISO 9075', '1999', 'CORE', NULL, NULL, 'EMBEDDED', 'C');

GRANT SELECT ON sql_languages TO PUBLIC;


/*
 * 20.50
 * SQL_PACKAGES table
 */

CREATE TABLE sql_packages (
    feature_id      character_data,
    feature_name    character_data,
    is_supported    character_data,
    is_verified_by  character_data,
    comments        character_data
) WITHOUT OIDS;

INSERT INTO sql_packages VALUES ('PKG000', 'Core', 'NO', NULL, '');
INSERT INTO sql_packages VALUES ('PKG001', 'Enhanced datetime facilities', 'YES', NULL, '');
INSERT INTO sql_packages VALUES ('PKG002', 'Enhanced integrity management', 'NO', NULL, '');
INSERT INTO sql_packages VALUES ('PKG003', 'OLAP facilities', 'NO', NULL, '');
INSERT INTO sql_packages VALUES ('PKG004', 'PSM', 'NO', NULL, 'PL/pgSQL is similar.');
INSERT INTO sql_packages VALUES ('PKG005', 'CLI', 'NO', NULL, 'ODBC is similar.');
INSERT INTO sql_packages VALUES ('PKG006', 'Basic object support', 'NO', NULL, '');
INSERT INTO sql_packages VALUES ('PKG007', 'Enhanced object support', 'NO', NULL, '');
INSERT INTO sql_packages VALUES ('PKG008', 'Active database', 'NO', NULL, '');
INSERT INTO sql_packages VALUES ('PKG009', 'SQL/MM support', 'NO', NULL, '');

GRANT SELECT ON sql_packages TO PUBLIC;


/*
 * 20.51
 * SQL_SIZING table
 */

-- Note: Sizing items are defined in ISO 9075-3:1999, clause 7.2.

CREATE TABLE sql_sizing (
    sizing_id       cardinal_number,
    sizing_name     character_data,
    supported_value cardinal_number,
    comments        character_data
) WITHOUT OIDS;

INSERT INTO sql_sizing VALUES (34,    'MAXIMUM CATALOG NAME LENGTH', 63, NULL);
INSERT INTO sql_sizing VALUES (30,    'MAXIMUM COLUMN NAME LENGTH', 63, NULL);
INSERT INTO sql_sizing VALUES (97,    'MAXIMUM COLUMNS IN GROUP BY', 0, NULL);
INSERT INTO sql_sizing VALUES (99,    'MAXIMUM COLUMNS IN ORDER BY', 0, NULL);
INSERT INTO sql_sizing VALUES (100,   'MAXIMUM COLUMNS IN SELECT', 0, NULL);
INSERT INTO sql_sizing VALUES (101,   'MAXIMUM COLUMNS IN TABLE', 1600, NULL); -- match MaxHeapAttributeNumber
INSERT INTO sql_sizing VALUES (1,     'MAXIMUM CONCURRENT ACTIVITIES', 0, NULL);
INSERT INTO sql_sizing VALUES (31,    'MAXIMUM CURSOR NAME LENGTH', 63, NULL);
INSERT INTO sql_sizing VALUES (0,     'MAXIMUM DRIVER CONNECTIONS', NULL, NULL);
INSERT INTO sql_sizing VALUES (10005, 'MAXIMUM IDENTIFIER LENGTH', 63, NULL);
INSERT INTO sql_sizing VALUES (32,    'MAXIMUM SCHEMA NAME LENGTH', 63, NULL);
INSERT INTO sql_sizing VALUES (20000, 'MAXIMUM STATEMENT OCTETS', 0, NULL);
INSERT INTO sql_sizing VALUES (20001, 'MAXIMUM STATEMENT OCTETS DATA', 0, NULL);
INSERT INTO sql_sizing VALUES (20002, 'MAXIMUM STATEMENT OCTETS SCHEMA', 0, NULL);
INSERT INTO sql_sizing VALUES (35,    'MAXIMUM TABLE NAME LENGTH', 63, NULL);
INSERT INTO sql_sizing VALUES (106,   'MAXIMUM TABLES IN SELECT', 0, NULL);
INSERT INTO sql_sizing VALUES (107,   'MAXIMUM USER NAME LENGTH', 63, NULL);
INSERT INTO sql_sizing VALUES (25000, 'MAXIMUM CURRENT DEFAULT TRANSFORM GROUP LENGTH', NULL, NULL);
INSERT INTO sql_sizing VALUES (25001, 'MAXIMUM CURRENT TRANSFORM GROUP LENGTH', NULL, NULL);
INSERT INTO sql_sizing VALUES (25002, 'MAXIMUM CURRENT PATH LENGTH', 0, NULL);
INSERT INTO sql_sizing VALUES (25003, 'MAXIMUM CURRENT ROLE LENGTH', NULL, NULL);
INSERT INTO sql_sizing VALUES (25004, 'MAXIMUM SESSION USER LENGTH', 63, NULL);
INSERT INTO sql_sizing VALUES (25005, 'MAXIMUM SYSTEM USER LENGTH', 63, NULL);

UPDATE sql_sizing
    SET supported_value = (SELECT typlen-1 FROM pg_catalog.pg_type WHERE typname = 'name'),
        comments = 'Might be less, depending on character set.'
    WHERE supported_value = 63;

GRANT SELECT ON sql_sizing TO PUBLIC;


/*
 * 20.52
 * SQL_SIZING_PROFILES table
 */

-- The data in this table are defined by various profiles of SQL.
-- Since we don't have any information about such profiles, we provide
-- an empty table.

CREATE TABLE sql_sizing_profiles (
    sizing_id       cardinal_number,
    sizing_name     character_data,
    profile_id      character_data,
    required_value  cardinal_number,
    comments        character_data
) WITHOUT OIDS;

GRANT SELECT ON sql_sizing_profiles TO PUBLIC;


/*
 * 20.53
 * TABLE_CONSTRAINTS view
 */

CREATE VIEW table_constraints AS
    SELECT CAST(current_database() AS sql_identifier) AS constraint_catalog,
           CAST(nc.nspname AS sql_identifier) AS constraint_schema,
           CAST(c.conname AS sql_identifier) AS constraint_name,
           CAST(current_database() AS sql_identifier) AS table_catalog,
           CAST(nr.nspname AS sql_identifier) AS table_schema,
           CAST(r.relname AS sql_identifier) AS table_name,
           CAST(
             CASE c.contype WHEN 'c' THEN 'CHECK'
                            WHEN 'f' THEN 'FOREIGN KEY'
                            WHEN 'p' THEN 'PRIMARY KEY'
                            WHEN 'u' THEN 'UNIQUE' END
             AS character_data) AS constraint_type,
           CAST(CASE WHEN c.condeferrable THEN 'YES' ELSE 'NO' END AS character_data)
             AS is_deferrable,
           CAST(CASE WHEN c.condeferred THEN 'YES' ELSE 'NO' END AS character_data)
             AS initially_deferred

    FROM pg_namespace nc,
         pg_namespace nr,
         pg_constraint c,
         pg_class r,
         pg_user u

    WHERE nc.oid = c.connamespace AND nr.oid = r.relnamespace
          AND c.conrelid = r.oid AND r.relowner = u.usesysid
          AND u.usename = current_user;

-- FIMXE: Not-null constraints are missing here.

GRANT SELECT ON table_constraints TO PUBLIC;


/*
 * 20.55
 * TABLE_PRIVILEGES view
 */

CREATE VIEW table_privileges AS
    SELECT CAST(u_grantor.usename AS sql_identifier) AS grantor,
           CAST(u_grantee.usename AS sql_identifier) AS grantee,
           CAST(current_database() AS sql_identifier) AS table_catalog,
           CAST(nc.nspname AS sql_identifier) AS table_schema,
           CAST(c.relname AS sql_identifier) AS table_name,
           CAST(pr.type AS character_data) AS privilege_type,
           CAST(
             CASE WHEN aclcontains(c.relacl,
                                   makeaclitem(u_grantee.usesysid, 0, u_grantor.usesysid, pr.type, true))
                  THEN 'YES' ELSE 'NO' END AS character_data) AS is_grantable,
           CAST('NO' AS character_data) AS with_hierarchy

    FROM pg_class c,
         pg_namespace nc,
         pg_user u_grantor,
         (SELECT usesysid, usename FROM pg_user UNION SELECT 0, 'PUBLIC') AS u_grantee,
         (SELECT 'SELECT' UNION SELECT 'DELETE' UNION SELECT 'INSERT' UNION SELECT 'UPDATE'
          UNION SELECT 'REFERENCES' UNION SELECT 'TRIGGER') AS pr (type)

    WHERE c.relnamespace = nc.oid
          AND aclcontains(c.relacl,
                          makeaclitem(u_grantee.usesysid, 0, u_grantor.usesysid, pr.type, false))
          AND (u_grantor.usename = current_user
               OR u_grantee.usename = current_user
               OR u_grantee.usename = 'PUBLIC');

GRANT SELECT ON table_privileges TO PUBLIC;


/*
 * 20.56
 * TABLES view
 */

CREATE VIEW tables AS
    SELECT CAST(current_database() AS sql_identifier) AS table_catalog,
           CAST(nc.nspname AS sql_identifier) AS table_schema,
           CAST(c.relname AS sql_identifier) AS table_name,

           CAST(
             CASE WHEN nc.nspname LIKE 'pg!_temp!_%' ESCAPE '!' THEN 'LOCAL TEMPORARY'
                  WHEN c.relkind = 'r' THEN 'BASE TABLE'
                  WHEN c.relkind = 'v' THEN 'VIEW'
                  ELSE null END
             AS character_data) AS table_type,

           CAST(null AS sql_identifier) AS self_referencing_column_name,
           CAST(null AS character_data) AS reference_generation,

           CAST(null AS sql_identifier) AS user_defined_type_catalog,
           CAST(null AS sql_identifier) AS user_defined_type_schema,
           CAST(null AS sql_identifier) AS user_defined_name

    FROM pg_namespace nc, pg_class c, pg_user u

    WHERE c.relnamespace = nc.oid AND u.usesysid = c.relowner
          AND c.relkind IN ('r', 'v')
          AND (u.usename = current_user
               OR has_table_privilege(c.oid, 'SELECT')
               OR has_table_privilege(c.oid, 'INSERT')
               OR has_table_privilege(c.oid, 'UPDATE')
               OR has_table_privilege(c.oid, 'DELETE')
               OR has_table_privilege(c.oid, 'RULE')
               OR has_table_privilege(c.oid, 'RERERENCES')
               OR has_table_privilege(c.oid, 'TRIGGER') );

GRANT SELECT ON tables TO PUBLIC;


/*
 * 20.63
 * USAGE_PRIVILEGES view
 */

-- Of the things currently implemented in PostgreSQL, usage privileges
-- apply only to domains.  Since domains have no real privileges, we
-- represent all domains with implicit usage privilege here.

CREATE VIEW usage_privileges AS
    SELECT CAST(u.usename AS sql_identifier) AS grantor,
           CAST('PUBLIC' AS sql_identifier) AS grantee,
           CAST(current_database() AS sql_identifier) AS object_catalog,
           CAST(n.nspname AS sql_identifier) AS object_schema,
           CAST(t.typname AS sql_identifier) AS object_name,
           CAST('DOMAIN' AS character_data) AS object_type,
           CAST('USAGE' AS character_data) AS privilege_type,
           CAST('NO' AS character_data) AS is_grantable

    FROM pg_user u,
         pg_namespace n,
         pg_type t

    WHERE u.usesysid = t.typowner
          AND t.typnamespace = n.oid
          AND t.typtype = 'd';

GRANT SELECT ON usage_privileges TO PUBLIC;


/*
 * 20.68
 * VIEWS view
 */

CREATE VIEW views AS
    SELECT CAST(current_database() AS sql_identifier) AS table_catalog,
           CAST(nc.nspname AS sql_identifier) AS table_schema,
           CAST(c.relname AS sql_identifier) AS table_name,

           CAST(
             CASE WHEN u.usename = current_user THEN pg_get_viewdef(c.oid)
                  ELSE null END
             AS character_data) AS view_definition,

           CAST('NONE' AS character_data) AS check_option,
           CAST(null AS character_data) AS is_updatable, -- FIXME
           CAST(null AS character_data) AS is_insertable_into  -- FIXME

    FROM pg_namespace nc, pg_class c, pg_user u

    WHERE c.relnamespace = nc.oid AND u.usesysid = c.relowner
          AND c.relkind = 'v'
          AND (u.usename = current_user
               OR has_table_privilege(c.oid, 'SELECT')
               OR has_table_privilege(c.oid, 'INSERT')
               OR has_table_privilege(c.oid, 'UPDATE')
               OR has_table_privilege(c.oid, 'DELETE')
               OR has_table_privilege(c.oid, 'RULE')
               OR has_table_privilege(c.oid, 'RERERENCES')
               OR has_table_privilege(c.oid, 'TRIGGER') );

GRANT SELECT ON views TO PUBLIC;

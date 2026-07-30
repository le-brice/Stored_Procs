-- created_at: 2026-07-30T12:51:24.961860+00:00
-- finished_at: 2026-07-30T12:51:25.277548+00:00
-- elapsed: 315ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-ee4d-0004-7d833f39396a
-- desc: get_relation > list_relations call
SHOW OBJECTS IN SCHEMA "ANALYTICS"."DBT_CBUCKLEY_DEV" LIMIT 10000;
-- created_at: 2026-07-30T12:51:25.278985+00:00
-- finished_at: 2026-07-30T12:51:26.610947+00:00
-- elapsed: 1.3s
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e389-0004-7d833f39571e
-- desc: execute adapter call
show terse schemas in database analytics
    limit 10000
/* {"app": "dbt", "connection_name": "", "dbt_version": "2.0.0", "profile_name": "default", "target_name": "dev"} */;
-- created_at: 2026-07-30T12:51:27.496413+00:00
-- finished_at: 2026-07-30T12:51:28.378992+00:00
-- elapsed: 882ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-eee0-0004-7d833f392a82
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM ANALYTICS.INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV';
-- created_at: 2026-07-30T12:51:28.382267+00:00
-- finished_at: 2026-07-30T12:51:28.951140+00:00
-- elapsed: 568ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-ee4d-0004-7d833f393972
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM ANALYTICS.INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT';
-- created_at: 2026-07-30T12:51:28.951545+00:00
-- finished_at: 2026-07-30T12:51:30.166556+00:00
-- elapsed: 1.2s
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-ee4d-0004-7d833f393976
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'ACCEPTED_VALUES_FCT_JOURNAL_BALANCE_IS_BALANCED__TRUE' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'ACCEPTED_VALUES_FCT_ORDERS_4D217B735D137DA507450DEA73A19C20' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'ACCEPTED_VALUES_RPT_CUSTOMER_L_E6F32BD186E92905E336676EA7160273' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'ASSERT_DAILY_SALES_SUMMARY_GRAIN' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'ASSERT_INVENTORY_SNAPSHOT_GRAIN' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'ASSERT_ORDER_TOTALS_RECONCILE' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'ASSERT_SALES_JOURNAL_BALANCED' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_FCT_JOURNAL_BALANCE_ENTRY_DATE' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_FCT_JOURNAL_BALANCE_SOURCE' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_FCT_ORDERS_CUSTOMER_ID' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_FCT_ORDERS_EXTERNAL_ORDER_REF' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_FCT_ORDERS_GRAND_TOTAL' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_FCT_ORDERS_ORDER_ID' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_FCT_ORDER_LINES_ORDER_LINE_ID' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_FCT_ORDER_LINES_PRODUCT_ID' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_FCT_ORDER_LINES_QTY' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_FCT_SALES_JOURNAL_LINES_ACCOUNT_CODE' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_FCT_SALES_JOURNAL_LINES_ENTRY_DATE' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_FCT_SALES_JOURNAL_LINES_JOURNAL_LINE_KEY' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_INT_RAW_ORDERS_VALIDATED_ROW_ID' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_RPT_CUSTOMER_LTV_CUSTOMER_ID' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_RPT_DAILY_SALES_SUMMARY_CATEGORY_ID' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_RPT_DAILY_SALES_SUMMARY_SUMMARY_DATE' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_RPT_DAILY_SALES_SUMMARY_WAREHOUSE_ID' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_RPT_INVENTORY_SNAPSHOT_PRODUCT_ID' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_RPT_INVENTORY_SNAPSHOT_SNAPSHOT_DATE' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_RPT_INVENTORY_SNAPSHOT_WAREHOUSE_ID' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_RPT_LOW_STOCK_REPORT_PRODUCT_ID' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_RPT_LOW_STOCK_REPORT_WAREHOUSE_ID' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_RPT_REORDER_RECOMMENDATIONS_PRODUCT_ID' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_RPT_REORDER_RECOMMENDATIONS_SUPPLIER_ID' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_RPT_REORDER_RECOMMENDATIONS_WAREHOUSE_ID' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'NOT_NULL_RPT_TOP_PRODUCTS_BY_REVENUE_PRODUCT_ID' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'RELATIONSHIPS_FCT_ORDER_LINES_8DCC6B8B872D5A93783E6274548344B6' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'UNIQUE_FCT_ORDERS_EXTERNAL_ORDER_REF' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'UNIQUE_FCT_ORDERS_ORDER_ID' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'UNIQUE_FCT_ORDER_LINES_ORDER_LINE_ID' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'UNIQUE_FCT_SALES_JOURNAL_LINES_JOURNAL_LINE_KEY' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'UNIQUE_INT_RAW_ORDERS_VALIDATED_ROW_ID' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'UNIQUE_RPT_CUSTOMER_LTV_CUSTOMER_ID' OR table_schema = 'DBT_CBUCKLEY_DEV_DBT_TEST__AUDIT' and table_name = 'UNIQUE_RPT_TOP_PRODUCTS_BY_REVENUE_PRODUCT_ID';
-- created_at: 2026-07-30T12:51:30.166860+00:00
-- finished_at: 2026-07-30T12:51:30.391379+00:00
-- elapsed: 224ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e389-0004-7d833f39572e
-- desc: dbt State run clock
SELECT DATE_PART('epoch_millisecond', SYSDATE());
-- created_at: 2026-07-30T12:51:31.220433+00:00
-- finished_at: 2026-07-30T12:51:32.409835+00:00
-- elapsed: 1.2s
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-ee4d-0004-7d833f39397a
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."STOCK_LEVEL"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."CONFIG_PARAM"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."PRODUCT"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RAW_PRODUCT"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."PRODUCT_CATEGORY"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."SUPPLIER"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:32.611756+00:00
-- finished_at: 2026-07-30T12:51:33.236213+00:00
-- elapsed: 624ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-ee4d-0004-7d833f39399a
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RPT_REORDER_RECOMMENDATIONS"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:32.215862+00:00
-- finished_at: 2026-07-30T12:51:33.380827+00:00
-- elapsed: 1.2s
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e778-0004-7d833f390e1e
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."STOCK_LEVEL"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."CONFIG_PARAM"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."PRODUCT"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RAW_PRODUCT"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."PRODUCT_CATEGORY"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."SUPPLIER"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:32.322881+00:00
-- finished_at: 2026-07-30T12:51:33.630343+00:00
-- elapsed: 1.3s
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f0cd-0004-7d833f391d76
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RAW_ORDER"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."CUSTOMER"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RAW_CUSTOMER"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."REF_COUNTRY"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."PRODUCT"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RAW_PRODUCT"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."PRODUCT_CATEGORY"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."SUPPLIER"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:32.394737+00:00
-- finished_at: 2026-07-30T12:51:33.948798+00:00
-- elapsed: 1.6s
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f17e-0004-7d833f394776
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RAW_ORDER"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."CUSTOMER"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RAW_CUSTOMER"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."REF_COUNTRY"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."PRODUCT"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RAW_PRODUCT"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."PRODUCT_CATEGORY"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."SUPPLIER"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:33.236582+00:00
-- finished_at: 2026-07-30T12:51:33.986848+00:00
-- elapsed: 750ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f17e-0004-7d833f39478e
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'RPT_REORDER_RECOMMENDATIONS';
-- created_at: 2026-07-30T12:51:33.357344+00:00
-- finished_at: 2026-07-30T12:51:34.142585+00:00
-- elapsed: 785ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e778-0004-7d833f390e3e
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RPT_REORDER_RECOMMENDATIONS"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:33.627913+00:00
-- finished_at: 2026-07-30T12:51:34.279807+00:00
-- elapsed: 651ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-ee4d-0004-7d833f3939a6
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RPT_INVENTORY_SNAPSHOT"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:33.614564+00:00
-- finished_at: 2026-07-30T12:51:34.326375+00:00
-- elapsed: 711ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f0cd-0004-7d833f391da2
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RPT_REORDER_RECOMMENDATIONS"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:34.280284+00:00
-- finished_at: 2026-07-30T12:51:35.000100+00:00
-- elapsed: 719ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f17e-0004-7d833f3947a2
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'RPT_INVENTORY_SNAPSHOT';
-- created_at: 2026-07-30T12:51:34.366354+00:00
-- finished_at: 2026-07-30T12:51:35.021381+00:00
-- elapsed: 655ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-ee4d-0004-7d833f3939b6
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RPT_INVENTORY_SNAPSHOT"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:34.387263+00:00
-- finished_at: 2026-07-30T12:51:35.077688+00:00
-- elapsed: 690ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-ee4d-0004-7d833f3939b2
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RPT_INVENTORY_SNAPSHOT"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:34.391663+00:00
-- finished_at: 2026-07-30T12:51:35.189986+00:00
-- elapsed: 798ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f17e-0004-7d833f3947a6
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RPT_INVENTORY_SNAPSHOT"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:34.683916+00:00
-- finished_at: 2026-07-30T12:51:35.770005+00:00
-- elapsed: 1.1s
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f17e-0004-7d833f3947ae
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."PRICE_LIST_ITEM"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."PRICE_LIST"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RAW_FXRATE"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."REF_FXRATE"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:35.714753+00:00
-- finished_at: 2026-07-30T12:51:36.434935+00:00
-- elapsed: 720ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e778-0004-7d833f390e4a
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RPT_LOW_STOCK_REPORT"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:35.714772+00:00
-- finished_at: 2026-07-30T12:51:36.488441+00:00
-- elapsed: 773ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-eee0-0004-7d833f392a8a
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RPT_LOW_STOCK_REPORT"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:36.128159+00:00
-- finished_at: 2026-07-30T12:51:36.781523+00:00
-- elapsed: 653ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-ee4d-0004-7d833f3939ca
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."FCT_ORDER_LINES"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:36.128751+00:00
-- finished_at: 2026-07-30T12:51:36.837857+00:00
-- elapsed: 709ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e389-0004-7d833f395732
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."FCT_ORDER_LINES"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:36.127987+00:00
-- finished_at: 2026-07-30T12:51:36.892523+00:00
-- elapsed: 764ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-eee0-0004-7d833f392a96
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."FCT_ORDER_LINES"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:36.128232+00:00
-- finished_at: 2026-07-30T12:51:36.903052+00:00
-- elapsed: 774ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-eee0-0004-7d833f392a92
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."FCT_ORDER_LINES"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:36.435218+00:00
-- finished_at: 2026-07-30T12:51:37.168009+00:00
-- elapsed: 732ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-eee0-0004-7d833f392aa6
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'RPT_LOW_STOCK_REPORT';
-- created_at: 2026-07-30T12:51:36.488837+00:00
-- finished_at: 2026-07-30T12:51:37.286009+00:00
-- elapsed: 797ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e778-0004-7d833f390e56
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'RPT_LOW_STOCK_REPORT';
-- created_at: 2026-07-30T12:51:36.838314+00:00
-- finished_at: 2026-07-30T12:51:37.567223+00:00
-- elapsed: 728ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-eee0-0004-7d833f392ab2
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'FCT_ORDER_LINES';
-- created_at: 2026-07-30T12:51:36.892801+00:00
-- finished_at: 2026-07-30T12:51:37.598219+00:00
-- elapsed: 705ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e389-0004-7d833f39573e
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'FCT_ORDER_LINES';
-- created_at: 2026-07-30T12:51:36.903249+00:00
-- finished_at: 2026-07-30T12:51:37.656619+00:00
-- elapsed: 753ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-ee4d-0004-7d833f3939d6
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'FCT_ORDER_LINES';
-- created_at: 2026-07-30T12:51:36.781762+00:00
-- finished_at: 2026-07-30T12:51:37.894080+00:00
-- elapsed: 1.1s
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f0cd-0004-7d833f391dae
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'FCT_ORDER_LINES';
-- created_at: 2026-07-30T12:51:38.087813+00:00
-- finished_at: 2026-07-30T12:51:39.000433+00:00
-- elapsed: 912ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-eee0-0004-7d833f392ab6
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."WAREHOUSE"', '"ANALYTICS"."DBT_CBUCKLEY_DEV"."PROMOTION"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:39.392304+00:00
-- finished_at: 2026-07-30T12:51:40.009322+00:00
-- elapsed: 617ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-ee4d-0004-7d833f3939da
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."FCT_ORDERS"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:39.391908+00:00
-- finished_at: 2026-07-30T12:51:40.036823+00:00
-- elapsed: 644ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-ee4d-0004-7d833f3939de
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."FCT_ORDERS"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:39.391928+00:00
-- finished_at: 2026-07-30T12:51:40.070277+00:00
-- elapsed: 678ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-ee4d-0004-7d833f3939e2
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."FCT_ORDERS"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:39.391618+00:00
-- finished_at: 2026-07-30T12:51:40.091965+00:00
-- elapsed: 700ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e778-0004-7d833f390e5e
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."FCT_ORDERS"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:39.394125+00:00
-- finished_at: 2026-07-30T12:51:40.110597+00:00
-- elapsed: 716ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-eee0-0004-7d833f392ac6
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."FCT_ORDERS"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:39.391533+00:00
-- finished_at: 2026-07-30T12:51:40.127545+00:00
-- elapsed: 736ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e778-0004-7d833f390e5a
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."FCT_ORDERS"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:39.391626+00:00
-- finished_at: 2026-07-30T12:51:40.161320+00:00
-- elapsed: 769ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f17e-0004-7d833f3947ca
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."FCT_ORDERS"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:39.392821+00:00
-- finished_at: 2026-07-30T12:51:40.181660+00:00
-- elapsed: 788ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e778-0004-7d833f390e62
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."FCT_ORDERS"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:39.392670+00:00
-- finished_at: 2026-07-30T12:51:40.339501+00:00
-- elapsed: 946ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-ee4d-0004-7d833f3939fe
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."FCT_ORDERS"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:40.009682+00:00
-- finished_at: 2026-07-30T12:51:40.733576+00:00
-- elapsed: 723ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e389-0004-7d833f395742
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'FCT_ORDERS';
-- created_at: 2026-07-30T12:51:40.071257+00:00
-- finished_at: 2026-07-30T12:51:40.769015+00:00
-- elapsed: 697ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f0cd-0004-7d833f391db6
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'FCT_ORDERS';
-- created_at: 2026-07-30T12:51:40.092205+00:00
-- finished_at: 2026-07-30T12:51:40.808079+00:00
-- elapsed: 715ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f17e-0004-7d833f3947da
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'FCT_ORDERS';
-- created_at: 2026-07-30T12:51:40.037322+00:00
-- finished_at: 2026-07-30T12:51:40.851379+00:00
-- elapsed: 814ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-eee0-0004-7d833f392ad2
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'FCT_ORDERS';
-- created_at: 2026-07-30T12:51:40.127784+00:00
-- finished_at: 2026-07-30T12:51:40.959308+00:00
-- elapsed: 831ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f17e-0004-7d833f3947e2
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'FCT_ORDERS';
-- created_at: 2026-07-30T12:51:40.181862+00:00
-- finished_at: 2026-07-30T12:51:40.959848+00:00
-- elapsed: 777ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f17e-0004-7d833f3947e6
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'FCT_ORDERS';
-- created_at: 2026-07-30T12:51:40.161557+00:00
-- finished_at: 2026-07-30T12:51:40.959849+00:00
-- elapsed: 798ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e389-0004-7d833f395746
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'FCT_ORDERS';
-- created_at: 2026-07-30T12:51:40.110827+00:00
-- finished_at: 2026-07-30T12:51:40.959851+00:00
-- elapsed: 849ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f17e-0004-7d833f3947de
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'FCT_ORDERS';
-- created_at: 2026-07-30T12:51:40.339811+00:00
-- finished_at: 2026-07-30T12:51:41.124575+00:00
-- elapsed: 784ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f17e-0004-7d833f3947ea
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'FCT_ORDERS';
-- created_at: 2026-07-30T12:51:41.620635+00:00
-- finished_at: 2026-07-30T12:51:42.269186+00:00
-- elapsed: 648ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-ee4d-0004-7d833f393a0e
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RPT_TOP_PRODUCTS_BY_REVENUE"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:41.555502+00:00
-- finished_at: 2026-07-30T12:51:42.284925+00:00
-- elapsed: 729ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f17e-0004-7d833f3947ee
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."GL_ACCOUNT"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:41.620847+00:00
-- finished_at: 2026-07-30T12:51:42.306957+00:00
-- elapsed: 686ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e778-0004-7d833f390e82
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RPT_TOP_PRODUCTS_BY_REVENUE"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:41.656488+00:00
-- finished_at: 2026-07-30T12:51:42.314488+00:00
-- elapsed: 658ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e778-0004-7d833f390e8a
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RPT_DAILY_SALES_SUMMARY"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:41.656870+00:00
-- finished_at: 2026-07-30T12:51:42.332870+00:00
-- elapsed: 676ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e778-0004-7d833f390e86
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RPT_DAILY_SALES_SUMMARY"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:41.656870+00:00
-- finished_at: 2026-07-30T12:51:42.360689+00:00
-- elapsed: 703ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f0cd-0004-7d833f391dba
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RPT_DAILY_SALES_SUMMARY"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:41.656845+00:00
-- finished_at: 2026-07-30T12:51:42.389709+00:00
-- elapsed: 732ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-eee0-0004-7d833f392ad6
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RPT_DAILY_SALES_SUMMARY"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:42.307173+00:00
-- finished_at: 2026-07-30T12:51:43.056334+00:00
-- elapsed: 749ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e389-0004-7d833f39574a
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'RPT_TOP_PRODUCTS_BY_REVENUE';
-- created_at: 2026-07-30T12:51:42.314646+00:00
-- finished_at: 2026-07-30T12:51:43.057372+00:00
-- elapsed: 742ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e389-0004-7d833f39574e
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'RPT_DAILY_SALES_SUMMARY';
-- created_at: 2026-07-30T12:51:42.269429+00:00
-- finished_at: 2026-07-30T12:51:43.057373+00:00
-- elapsed: 787ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-ee4d-0004-7d833f393a1a
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'RPT_TOP_PRODUCTS_BY_REVENUE';
-- created_at: 2026-07-30T12:51:42.390375+00:00
-- finished_at: 2026-07-30T12:51:43.091732+00:00
-- elapsed: 701ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f17e-0004-7d833f3947fe
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'RPT_DAILY_SALES_SUMMARY';
-- created_at: 2026-07-30T12:51:42.333141+00:00
-- finished_at: 2026-07-30T12:51:43.095345+00:00
-- elapsed: 762ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e778-0004-7d833f390ea6
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'RPT_DAILY_SALES_SUMMARY';
-- created_at: 2026-07-30T12:51:42.360925+00:00
-- finished_at: 2026-07-30T12:51:43.099832+00:00
-- elapsed: 738ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f17e-0004-7d833f3947fa
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'RPT_DAILY_SALES_SUMMARY';
-- created_at: 2026-07-30T12:51:41.776822+00:00
-- finished_at: 2026-07-30T12:51:43.127928+00:00
-- elapsed: 1.4s
-- outcome: success
-- dialect: snowflake
-- node_id: model.retail_dw.rpt_customer_ltv
-- query_id: 01c60e03-090c-eee0-0004-7d833f392ada
-- desc: execute adapter call
create or replace transient  table analytics.dbt_cbuckley_dev.rpt_customer_ltv
    
    
    
    
    as (with order_spend as (
    select
        orders.customer_id,
        orders.order_id,
        orders.order_date,
        round(orders.grand_total * rates.usd_rate, 4) as grand_usd
    from analytics.dbt_cbuckley_dev.fct_orders as orders
    inner join analytics.dbt_cbuckley_dev.int_order_usd_rates as rates
        on rates.order_id = orders.order_id
    where orders.status not in ('CANCELLED', 'NEW')
),

agg as (
    select
        customer_id,
        min(order_date) as first_order_date,
        max(order_date) as last_order_date,
        count(*) as order_count,
        sum(grand_usd) as total_net_spend
    from order_spend
    group by customer_id
)

select
    customer_id,
    first_order_date,
    last_order_date,
    order_count,
    total_net_spend,
    total_net_spend / nullif(order_count, 0) as avg_order_value,
    round(
        total_net_spend
        * case when datediff(day, last_order_date, current_date()) > 365 then 0.5 else 1.0 end,
        2
    ) as ltv_score,
    case
        when total_net_spend >= 12000 then 'VIP'
        when datediff(day, last_order_date, current_date()) > 365 then 'LAPSED'
        when order_count = 1 then 'NEW'
        else 'REGULAR'
    end as segment
from agg
    )

/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "model.retail_dw.rpt_customer_ltv", "profile_name": "default", "target_name": "dev"} */;
-- created_at: 2026-07-30T12:51:43.279604+00:00
-- finished_at: 2026-07-30T12:51:43.901929+00:00
-- elapsed: 622ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-ee4d-0004-7d833f393a1e
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RPT_CUSTOMER_LTV"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:43.279706+00:00
-- finished_at: 2026-07-30T12:51:43.978091+00:00
-- elapsed: 698ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f0cd-0004-7d833f391dca
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RPT_CUSTOMER_LTV"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:43.279817+00:00
-- finished_at: 2026-07-30T12:51:43.998316+00:00
-- elapsed: 718ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f17e-0004-7d833f394802
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."RPT_CUSTOMER_LTV"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:44.127861+00:00
-- finished_at: 2026-07-30T12:51:44.422017+00:00
-- elapsed: 294ms
-- outcome: success
-- dialect: snowflake
-- node_id: test.retail_dw.not_null_rpt_customer_ltv_customer_id.f41ab00a86
-- query_id: 01c60e03-090c-eee0-0004-7d833f392ae6
-- desc: execute adapter call
select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select customer_id
from analytics.dbt_cbuckley_dev.rpt_customer_ltv
where customer_id is null



  
  
      
    ) dbt_internal_test
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "test.retail_dw.not_null_rpt_customer_ltv_customer_id.f41ab00a86", "profile_name": "default", "target_name": "dev"} */;
-- created_at: 2026-07-30T12:51:44.159981+00:00
-- finished_at: 2026-07-30T12:51:44.446487+00:00
-- elapsed: 286ms
-- outcome: success
-- dialect: snowflake
-- node_id: test.retail_dw.accepted_values_rpt_customer_ltv_segment__VIP__REGULAR__LAPSED__NEW.024fda3937
-- query_id: 01c60e03-090c-f0cd-0004-7d833f391dd6
-- desc: execute adapter call
select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        segment as value_field,
        count(*) as n_records

    from analytics.dbt_cbuckley_dev.rpt_customer_ltv
    group by segment

)

select *
from all_values
where value_field not in (
    'VIP','REGULAR','LAPSED','NEW'
)



  
  
      
    ) dbt_internal_test
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "test.retail_dw.accepted_values_rpt_customer_ltv_segment__VIP__REGULAR__LAPSED__NEW.024fda3937", "profile_name": "default", "target_name": "dev"} */;
-- created_at: 2026-07-30T12:51:44.181735+00:00
-- finished_at: 2026-07-30T12:51:44.499018+00:00
-- elapsed: 317ms
-- outcome: success
-- dialect: snowflake
-- node_id: test.retail_dw.unique_rpt_customer_ltv_customer_id.10e36c56f6
-- query_id: 01c60e03-090c-ee4d-0004-7d833f393a2a
-- desc: execute adapter call
select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    customer_id as unique_field,
    count(*) as n_records

from analytics.dbt_cbuckley_dev.rpt_customer_ltv
where customer_id is not null
group by customer_id
having count(*) > 1



  
  
      
    ) dbt_internal_test
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "test.retail_dw.unique_rpt_customer_ltv_customer_id.10e36c56f6", "profile_name": "default", "target_name": "dev"} */;
-- created_at: 2026-07-30T12:51:42.580460+00:00
-- finished_at: 2026-07-30T12:51:45.036186+00:00
-- elapsed: 2.5s
-- outcome: success
-- dialect: snowflake
-- node_id: model.retail_dw.fct_sales_journal_lines
-- query_id: 01c60e03-090c-f0cd-0004-7d833f391dc6
-- desc: execute adapter call
create or replace transient  table analytics.dbt_cbuckley_dev.fct_sales_journal_lines
    
    
    
    
    as (with order_amounts as (
    select
        orders.order_date as entry_date,
        round(sum(orders.grand_total * rates.usd_rate), 4) as total_grand,
        round(sum((orders.subtotal - orders.discount_total) * rates.usd_rate), 4) as total_net,
        round(sum(orders.tax_total * rates.usd_rate), 4) as total_tax
    from analytics.dbt_cbuckley_dev.fct_orders as orders
    inner join analytics.dbt_cbuckley_dev.int_order_usd_rates as rates
        on rates.order_id = orders.order_id
    where orders.status in ('PAID', 'SHIPPED', 'COMPLETED', 'CONFIRMED')
    group by orders.order_date
),

cogs as (
    select
        orders.order_date as entry_date,
        round(sum(lines.qty * coalesce(product.unit_cost, 0)), 4) as cogs_amount
    from analytics.dbt_cbuckley_dev.fct_orders as orders
    inner join analytics.dbt_cbuckley_dev.fct_order_lines as lines
        on lines.order_id = orders.order_id
    inner join analytics.dbt_cbuckley_dev.int_product_master as product
        on product.product_id = lines.product_id
    where orders.status in ('PAID', 'SHIPPED', 'COMPLETED', 'CONFIRMED')
    group by orders.order_date
),

daily as (
    select
        order_amounts.entry_date,
        order_amounts.total_grand,
        order_amounts.total_net,
        order_amounts.total_tax,
        coalesce(cogs.cogs_amount, 0) as cogs_amount,
        order_amounts.total_grand - (order_amounts.total_net + order_amounts.total_tax) as ar_plug
    from order_amounts
    left join cogs
        on cogs.entry_date = order_amounts.entry_date
    where order_amounts.total_grand <> 0
       or coalesce(cogs.cogs_amount, 0) <> 0
),

journal_lines as (
    select entry_date, 'SALES' as source, 'Daily sales' as description, '1200' as account_code, total_grand as debit_amount, 0 as credit_amount from daily
    union all
    select entry_date, 'SALES', 'Daily sales', '4000', 0, total_net from daily
    union all
    select entry_date, 'SALES', 'Daily sales', '2200', 0, total_tax from daily
    union all
    select entry_date, 'SALES', 'Daily sales', '9999', iff(ar_plug < 0, abs(ar_plug), 0), iff(ar_plug > 0, ar_plug, 0) from daily
    union all
    select entry_date, 'SALES', 'Daily sales', '5000', cogs_amount, 0 from daily
    union all
    select entry_date, 'SALES', 'Daily sales', '1300', 0, cogs_amount from daily
)

select
    md5(journal_lines.entry_date::varchar || '-' || journal_lines.source || '-' || journal_lines.account_code || '-' || journal_lines.debit_amount::varchar || '-' || journal_lines.credit_amount::varchar) as journal_line_key,
    journal_lines.entry_date,
    journal_lines.source,
    journal_lines.description,
    account.gl_account_id,
    journal_lines.account_code,
    journal_lines.debit_amount,
    journal_lines.credit_amount
from journal_lines
left join analytics.dbt_cbuckley_dev.stg_gl_accounts as account
    on account.account_code = journal_lines.account_code
where debit_amount <> 0
   or credit_amount <> 0
    )

/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "model.retail_dw.fct_sales_journal_lines", "profile_name": "default", "target_name": "dev"} */;
-- created_at: 2026-07-30T12:51:45.185403+00:00
-- finished_at: 2026-07-30T12:51:45.860313+00:00
-- elapsed: 674ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f0cd-0004-7d833f391dda
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."FCT_SALES_JOURNAL_LINES"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:45.185882+00:00
-- finished_at: 2026-07-30T12:51:45.892334+00:00
-- elapsed: 706ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e389-0004-7d833f395752
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."FCT_SALES_JOURNAL_LINES"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:45.185554+00:00
-- finished_at: 2026-07-30T12:51:45.905110+00:00
-- elapsed: 719ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f17e-0004-7d833f39480e
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."FCT_SALES_JOURNAL_LINES"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:45.185873+00:00
-- finished_at: 2026-07-30T12:51:45.906638+00:00
-- elapsed: 720ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e778-0004-7d833f390eaa
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."FCT_SALES_JOURNAL_LINES"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:46.068546+00:00
-- finished_at: 2026-07-30T12:51:46.369485+00:00
-- elapsed: 300ms
-- outcome: success
-- dialect: snowflake
-- node_id: test.retail_dw.not_null_fct_sales_journal_lines_entry_date.86eb4715cc
-- query_id: 01c60e03-090c-eee0-0004-7d833f392aea
-- desc: execute adapter call
select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select entry_date
from analytics.dbt_cbuckley_dev.fct_sales_journal_lines
where entry_date is null



  
  
      
    ) dbt_internal_test
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "test.retail_dw.not_null_fct_sales_journal_lines_entry_date.86eb4715cc", "profile_name": "default", "target_name": "dev"} */;
-- created_at: 2026-07-30T12:51:46.095039+00:00
-- finished_at: 2026-07-30T12:51:46.396032+00:00
-- elapsed: 300ms
-- outcome: success
-- dialect: snowflake
-- node_id: test.retail_dw.not_null_fct_sales_journal_lines_journal_line_key.a65a691ab1
-- query_id: 01c60e03-090c-e389-0004-7d833f39575e
-- desc: execute adapter call
select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select journal_line_key
from analytics.dbt_cbuckley_dev.fct_sales_journal_lines
where journal_line_key is null



  
  
      
    ) dbt_internal_test
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "test.retail_dw.not_null_fct_sales_journal_lines_journal_line_key.a65a691ab1", "profile_name": "default", "target_name": "dev"} */;
-- created_at: 2026-07-30T12:51:46.093578+00:00
-- finished_at: 2026-07-30T12:51:46.396727+00:00
-- elapsed: 303ms
-- outcome: success
-- dialect: snowflake
-- node_id: test.retail_dw.unique_fct_sales_journal_lines_journal_line_key.6c455a50c5
-- query_id: 01c60e03-090c-e778-0004-7d833f390eb6
-- desc: execute adapter call
select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    journal_line_key as unique_field,
    count(*) as n_records

from analytics.dbt_cbuckley_dev.fct_sales_journal_lines
where journal_line_key is not null
group by journal_line_key
having count(*) > 1



  
  
      
    ) dbt_internal_test
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "test.retail_dw.unique_fct_sales_journal_lines_journal_line_key.6c455a50c5", "profile_name": "default", "target_name": "dev"} */;
-- created_at: 2026-07-30T12:51:46.197926+00:00
-- finished_at: 2026-07-30T12:51:46.435011+00:00
-- elapsed: 237ms
-- outcome: success
-- dialect: snowflake
-- node_id: test.retail_dw.not_null_fct_sales_journal_lines_account_code.147734462b
-- query_id: 01c60e03-090c-e778-0004-7d833f390eba
-- desc: execute adapter call
select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select account_code
from analytics.dbt_cbuckley_dev.fct_sales_journal_lines
where account_code is null



  
  
      
    ) dbt_internal_test
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "test.retail_dw.not_null_fct_sales_journal_lines_account_code.147734462b", "profile_name": "default", "target_name": "dev"} */;
-- created_at: 2026-07-30T12:51:46.762111+00:00
-- finished_at: 2026-07-30T12:51:47.409509+00:00
-- elapsed: 647ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e389-0004-7d833f395762
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."FCT_JOURNAL_BALANCE"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:46.761273+00:00
-- finished_at: 2026-07-30T12:51:47.429673+00:00
-- elapsed: 668ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e389-0004-7d833f395766
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."FCT_JOURNAL_BALANCE"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:46.762798+00:00
-- finished_at: 2026-07-30T12:51:47.447098+00:00
-- elapsed: 684ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-ee4d-0004-7d833f393a2e
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."FCT_JOURNAL_BALANCE"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:46.763354+00:00
-- finished_at: 2026-07-30T12:51:47.449641+00:00
-- elapsed: 686ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e778-0004-7d833f390ec6
-- desc: Fetch view definitions
EXECUTE IMMEDIATE $$
begin
    let objects array := array_construct(
        '"ANALYTICS"."DBT_CBUCKLEY_DEV"."FCT_JOURNAL_BALANCE"'
    );

    let i integer := 0;
    let results array := array_construct();

    while (i < array_size(objects)) do
        let obj_name string := objects[i]::string;

        begin
            let ddl_text string := (select get_ddl('VIEW', :obj_name));

            results := array_append(results, object_construct(
                'OBJECT_NAME', :obj_name,
                'DEFINITION', :ddl_text,
                'ERROR', null
            ));

        exception
            when other then
                results := array_append(results, object_construct(
                    'OBJECT_NAME', :obj_name,
                    'DEFINITION', null,
                    'ERROR', :sqlerrm
                ));
        end;

        i := i + 1;
    end while;

    let rs resultset := (
        select
            f.value['OBJECT_NAME']::string as fqn,
            f.value['DEFINITION']::string as view_definition,
            f.value['ERROR']::string as error
        from table(flatten(input => :results)) f
        order by 1
    );

    return table(rs);
end;$$;
-- created_at: 2026-07-30T12:51:47.447362+00:00
-- finished_at: 2026-07-30T12:51:48.178911+00:00
-- elapsed: 731ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e778-0004-7d833f390ed6
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'FCT_JOURNAL_BALANCE';
-- created_at: 2026-07-30T12:51:47.409737+00:00
-- finished_at: 2026-07-30T12:51:48.185482+00:00
-- elapsed: 775ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-e778-0004-7d833f390ed2
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'FCT_JOURNAL_BALANCE';
-- created_at: 2026-07-30T12:51:47.449773+00:00
-- finished_at: 2026-07-30T12:51:48.297056+00:00
-- elapsed: 847ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f17e-0004-7d833f39481e
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'FCT_JOURNAL_BALANCE';
-- created_at: 2026-07-30T12:51:47.429898+00:00
-- finished_at: 2026-07-30T12:51:48.297562+00:00
-- elapsed: 867ms
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c60e03-090c-f17e-0004-7d833f39481a
-- desc: Extracting freshness from information schema
SELECT
                table_schema,
                table_name,
                last_altered,
                (table_type = 'VIEW' OR table_type = 'MATERIALIZED VIEW') AS is_view
             FROM "ANALYTICS".INFORMATION_SCHEMA.TABLES
             WHERE table_schema = 'DBT_CBUCKLEY_DEV' and table_name = 'FCT_JOURNAL_BALANCE';

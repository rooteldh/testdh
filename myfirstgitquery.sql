-- Rebuild vs Reorganize

-- Rowstore INDEX
-- > 5% 및 < = 30%   ALTER INDEX REORGANIZE
-- > 30%   ALTER INDEX REBUILD WITH (ONLINE = ON)

    SELECT CASE WHEN avg_fragmentation_in_percent > 5 AND avg_fragmentation_in_percent <= 30 THEN 'REORGANIZE'
                WHEN avg_fragmentation_in_percent > 30 THEN 'REBUILD'
                ELSE '' END AS 'REBUILD/REORGANIZE'
        , object_name(A.object_id) AS TableName
        , A.object_id
        , name AS IndedxName
        , A.index_id
        , avg_fragmentation_in_percent -- 논리적 조각화(인덱스에서 순서가 잘못된 페이지) 비율
        --, fragment_count               -- 인덱스의 조각(물리적으로 연속되는 리프 페이지) 수
        --, avg_fragment_size_in_pages   -- 인덱스 한 조각의 평균 페이지 수
    FROM sys.dm_db_index_physical_stats 
    (DB_ID(N'AdventureWorks2019'), OBJECT_ID(N'Person.Address'), NULL, NULL , NULL) AS A
        LEFT OUTER JOIN SYS.indexes AS B
            ON A.object_id = B.object_id
        AND A.index_id  = B.index_id
    --WHERE avg_fragmentation_in_percent > 5 AND avg_fragmentation_in_percent <= 30 -- 5% < avg_fragmentation_in_percent <= 30%, ALTER INDEX REORGANIZE
    --WHERE avg_fragmentation_in_percent > 30                                       -- avg_fragmentation_in_percent > 30&, ALTER INDEX REBUILD WITH (ONLINE = ON)
    ORDER BY A.avg_fragmentation_in_percent DESC

-- 조각난 인덱스 다시 구성 (Rowstore INDEX)
ALTER INDEX IX_Address_StateProvinceID
    ON Person.Address
    REORGANIZE;

-- 조각난 인덱스를 다시 작성
ALTER INDEX [IX_Address_StateProvinceID] ON Person.Address
REBUILD

-- Columnstore INDEX
-- 계산된 조각화(백분율) 값                  버전에 적용                             수정문
--         > = 20%            SQL Server 2012(11.x) 및 SQL Server 2014(12.x)   ALTER INDEX REBUILD
--         > = 20%            SQL Server 2016(13.x)로 시작                     ALTER INDEX REORGANIZE
--      (> 5% 및 < 20%) 이 맞지 않을까? - REORGANIZE
  
    SELECT CASE WHEN 100*(ISNULL(SUM(CSRowGroups.deleted_rows),0))/NULLIF(SUM(CSRowGroups.total_rows),0) >= 20 THEN 'REBUILD/REORGANIZE'
        ELSE '' END AS 'REBUILD/REORGANIZE'
        , I.object_id
        , object_name(I.object_id) AS TableName
        , I.index_id
        , I.name AS IndexName
        , 100*(ISNULL(SUM(CSRowGroups.deleted_rows),0))/NULLIF(SUM(CSRowGroups.total_rows),0) AS 'Fragmentation'
        FROM sys.indexes AS I  
        INNER JOIN sys.dm_db_column_store_row_group_physical_stats AS CSRowGroups
            ON I.object_id = CSRowGroups.object_id
            AND I.index_id = CSRowGroups.index_id
        WHERE object_name(I.object_id) = 'CreditCardCL'
        GROUP BY I.object_id, I.index_id, I.name
        ORDER BY object_name(I.object_id), I.name;

-- 조각난 인덱스 다시 구성 (Columnstore INDEX)
-- This command will force all CLOSED and OPEN rowgroups into the columnstore.
ALTER INDEX [ClusteredColumnStoreIndex-20200917-135849]
    ON [Sales].[CreditCardCL]
    REORGANIZE WITH (COMPRESS_ALL_ROW_GROUPS = ON);

-- 테이블의 모든 인덱스를 다시 구성
ALTER INDEX ALL ON [Sales].[CreditCardCL]
   REORGANIZE;

-- 조각난 인덱스를 다시 작성
ALTER INDEX [ClusteredColumnStoreIndex-20200917-135849] ON [Sales].[CreditCardnonCL]
REBUILD
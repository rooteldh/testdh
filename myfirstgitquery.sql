-- Rebuild vs Reorganize

-- Rowstore INDEX
-- > 5% �� < = 30%   ALTER INDEX REORGANIZE
-- > 30%   ALTER INDEX REBUILD WITH (ONLINE = ON)

    SELECT CASE WHEN avg_fragmentation_in_percent > 5 AND avg_fragmentation_in_percent <= 30 THEN 'REORGANIZE'
                WHEN avg_fragmentation_in_percent > 30 THEN 'REBUILD'
                ELSE '' END AS 'REBUILD/REORGANIZE'
        , object_name(A.object_id) AS TableName
        , A.object_id
        , name AS IndedxName
        , A.index_id
        , avg_fragmentation_in_percent -- ���� ����ȭ(�ε������� ������ �߸��� ������) ����
        --, fragment_count               -- �ε����� ����(���������� ���ӵǴ� ���� ������) ��
        --, avg_fragment_size_in_pages   -- �ε��� �� ������ ��� ������ ��
    FROM sys.dm_db_index_physical_stats 
    (DB_ID(N'AdventureWorks2019'), OBJECT_ID(N'Person.Address'), NULL, NULL , NULL) AS A
        LEFT OUTER JOIN SYS.indexes AS B
            ON A.object_id = B.object_id
        AND A.index_id  = B.index_id
    --WHERE avg_fragmentation_in_percent > 5 AND avg_fragmentation_in_percent <= 30 -- 5% < avg_fragmentation_in_percent <= 30%, ALTER INDEX REORGANIZE
    --WHERE avg_fragmentation_in_percent > 30                                       -- avg_fragmentation_in_percent > 30&, ALTER INDEX REBUILD WITH (ONLINE = ON)
    ORDER BY A.avg_fragmentation_in_percent DESC

-- ������ �ε��� �ٽ� ���� (Rowstore INDEX)
ALTER INDEX IX_Address_StateProvinceID
    ON Person.Address
    REORGANIZE;

-- ������ �ε����� �ٽ� �ۼ�
ALTER INDEX [IX_Address_StateProvinceID] ON Person.Address
REBUILD

-- Columnstore INDEX
-- ���� ����ȭ(�����) ��                  ������ ����                             ������
--         > = 20%            SQL Server 2012(11.x) �� SQL Server 2014(12.x)   ALTER INDEX REBUILD
--         > = 20%            SQL Server 2016(13.x)�� ����                     ALTER INDEX REORGANIZE
--      (> 5% �� < 20%) �� ���� ������? - REORGANIZE
  
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

-- ������ �ε��� �ٽ� ���� (Columnstore INDEX)
-- This command will force all CLOSED and OPEN rowgroups into the columnstore.
ALTER INDEX [ClusteredColumnStoreIndex-20200917-135849]
    ON [Sales].[CreditCardCL]
    REORGANIZE WITH (COMPRESS_ALL_ROW_GROUPS = ON);

-- ���̺��� ��� �ε����� �ٽ� ����
ALTER INDEX ALL ON [Sales].[CreditCardCL]
   REORGANIZE;

-- ������ �ε����� �ٽ� �ۼ�
ALTER INDEX [ClusteredColumnStoreIndex-20200917-135849] ON [Sales].[CreditCardnonCL]
REBUILD
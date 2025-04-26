DECLARE @StoreId INT =
(
    SELECT 
        StoreId
    FROM 
        Store
) -- Change if MultiStore 

DECLARE @LogNumber INT =
(
    SELECT 
        MAX(LogNumber)
    FROM 
        FirearmLog
    WHERE 
        StoreId = @StoreId
)
    
-- Gathering a List of Firearms with Missing Log Entries
IF OBJECT_ID(N'tempdb..#MissingLogEntries', N'U') IS NOT NULL
BEGIN
    DROP TABLE #MissingLogEntries;
END

SELECT 
    ii.*
INTO #MissingLogEntries
FROM 
    InventoryItem II
INNER JOIN ItemType it
    ON ii.ItemTypeId = it.ItemTypeId 
INNER JOIN ItemCategory ic 
    ON it.ItemCategoryId = ic.ItemCategoryId 
LEFT JOIN Log g
    ON ii.InventoryItemId = g.InventoryItemId
WHERE 
    ii.StoreId = @StoreId
    AND ic.ItemCategoryName = 'Firearm'
    AND it.IsLogged = 1
    AND g.LogId IS NULL;

-- Inserting missing log entries
INSERT INTO [dbo].[FirearmLog]
    ([InventoryItemId]
    ,[StoreId]
    ,[LogNumber]
    ,[PickDate]
    ,[IsCurrentLog]
    ,[IsPlacedInHoldPeriod]
    ,[ATFNumber]
    ,[NICSNumber]
    ,[Comments1]
    ,[Comments2]
    ,[CreatedDate]
    ,[CreatedBy])
SELECT 
    InventoryItemId
    ,@StoreId StoreId
    ,ROW_NUMBER() OVER (ORDER BY InventoryItemId) + @LogNumber LogNumber
    ,NULL PickDate
    ,1 IsCurrentLog
    ,0 IsPlacedInHoldPeriod
    ,NULL ATFNumber
    ,NULL NICSNumber
    ,NULL Comments1
    ,NULL Comments2
    ,CreatedDate
    ,CreatedBy
FROM 
    #MissingLogEntries;

-- Inserting into firearm log entity table
INSERT INTO [dbo].[FirearmLogEntity]
    ([LogId]
    ,[ReceiptEntityId]
    ,[ReceiptEntitySourceId]
    ,[ReceiptFirstName]
    ,[ReceiptMiddleName]
    ,[ReceiptLastName]
    ,[ReceiptAddressLine1]
    ,[ReceiptAddressLine2]
    ,[ReceiptCity]
    ,[ReceiptState]
    ,[ReceiptZipCode]
    ,[ReceiptCountry]
    ,[ReceiptIDType]
    ,[ReceiptNumber]
    ,[ReceiptDate]
    ,[CreatedDate]
    ,[CreatedBy]
    ,[ItemTypeId]
    ,[FirearmImporterId]
    ,[ItemTypeBrandId]
    ,[FirearmCaliberGaugeId]
    ,[FirearmActionId]
    ,[FirearmCondition]
    ,[Model]
    ,[SerialNumber]
    ,[IsInventoryEdited])
SELECT 
    g.LogId
    ,InventoryItemTypeSourceId
    ,InventoryItemSourceId
    ,ISNULL(c.FirstName,'')
    ,ISNULL(c.MiddleName,'')
    ,ISNULL(c.LastName,s.StoreName)
    ,ISNULL(c.AddressLine1,s.Address1)
    ,ISNULL(c.AddressLine2,s.Address2)
    ,ISNULL(c.City,s.City)
    ,ISNULL(c.State,s.State)
    ,ISNULL(c.ZipCode,s.ZipCode)
    ,ISNULL(c.Country,s.Country)
    ,ISNULL(lv.Value,'FFL NUMBER')
    ,ISNULL(c.ID1Number,'')
    ,mge.CreatedDate
    ,mge.CreatedDate
    ,mge.CreatedBy
    ,mge.ItemTypeId
    ,mge.FirearmImporterId
    ,mge.ItemTypeBrandId
    ,mge.FirearmCaliberGaugeId
    ,mge.FirearmActionId
    ,mge.FirearmCondition
    ,mge.Model
    ,mge.SerialNumber
    ,0
FROM 
    #MissingLogEntries mge
INNER JOIN FirearmLog g 
    ON mge.InventoryItemId = g.InventoryItemId
LEFT JOIN FirearmLogEntity ge 
    ON g.LogId = ge.LogId
LEFT JOIN Customer c 
    ON mge.InventoryItemSourceId = c.CustomerId and mge.InventoryItemTypeSourceId = 1
LEFT JOIN Vendor v 
    ON mge.InventoryItemSourceId = v.VendorId and mge.InventoryItemTypeSourceId = 3
LEFT JOIN Store s 
    ON s.StoreId = mge.StoreId
LEFT JOIN LookupValue lv
    ON c.ID1TypeID = lv.LookupValueId 
LEFT JOIN LookupType lt 
    ON lv.LookupTypeId = lt.LookupTypeId
    AND lt.LookupTypeName = 'ID Type'
WHERE 
    ge.LogId IS NULL;

-- Dropping Temporary Tables if they exist
DROP TABLE IF EXISTS #ItemInventory;

-- Creating a new table to store inventory items
CREATE TABLE #ItemInventory
(
    InventoryItemID INT,
    StoreID INT,
    InventoryNumber NVARCHAR(50)
);

-- Inserting distinct inventory items into #ItemInventory
INSERT INTO #ItemInventory (InventoryItemID, StoreID, InventoryNumber) 
SELECT DISTINCT 
    InventoryItemId, 
    StoreId, 
    InventoryNumber
FROM dbo.InventoryItemVersion
UNION ALL
SELECT DISTINCT 
    IISV.InventoryItemId,
    StoreId,
    InventoryNumber
FROM dbo.InventoryItemStoneVersion AS IISV
INNER JOIN dbo.InventoryItemVersion AS IIV
    ON IISV.InventoryItemID = IIV.InventoryItemID;

-- Declare variable for inventory number
DECLARE @InventoryNumber VARCHAR(30);

-- Dropping any previous temporary tables
DROP TABLE IF EXISTS #InventoryChange;
DROP TABLE IF EXISTS #LotModifications;
DROP TABLE IF EXISTS #StoneModifications;
DROP TABLE IF EXISTS #StoneVersion;
DROP TABLE IF EXISTS #Stores;

-- Creating index on LookupValue table for better performance
DROP INDEX IF EXISTS [IDX01] ON [dbo].[LookupValue];
CREATE NONCLUSTERED INDEX [IDX01]
    ON [dbo].[LookupValue]([Value])
    INCLUDE ([LookupTypeId]);

-- Declare table to store action logs
DECLARE @ActionLog TABLE
(
    InventoryNumber NVARCHAR(MAX),
    ActionDate DATETIME,
    PerformedBy VARCHAR(100),
    Action NVARCHAR(MAX),
    StoreID VARCHAR(500),
    InventoryItemID VARCHAR(500),
    ChangedField VARCHAR(500),
    PreviousValue VARCHAR(500),
    NewValue NVARCHAR(MAX),
    Quantity VARCHAR(500),
    CreatedBy VARCHAR(500),
    TransactionID NVARCHAR(50),
    JewelryWeightUnitID NVARCHAR(50),
    PoliceConfiscateID VARCHAR(500),
    EforoItemId VARCHAR(500),
    HistoryChangeSourceId INT
);

-- Fetch store details for time zone adjustments
SELECT 
    Timezoneid,
    Isdstobserved
INTO #Stores
FROM Store;

DECLARE @TimeZoneId NVARCHAR(50);
DECLARE @DST INT;

-- Set TimeZone and DST
SET @TimeZoneId = (SELECT TOP 1 Timezoneid FROM #Stores);
SET @DST = (SELECT TOP 1 isdstobserved FROM #Stores);

-- Fetch Inventory Item Lot Modifications
DROP TABLE IF EXISTS #LotModifications;

SELECT 
    I.InventoryItemID,
    I.StoreID,
    IILM.*
INTO #LotModifications
FROM [InventoryItemLot] AS IIL
JOIN [InventoryItemLotModification] AS IILM
    ON IILM.InventoryItemLotId = IIL.InventoryItemLotId
INNER JOIN #ItemInventory AS I
    ON IIL.InventoryItemID = I.InventoryItemID;

-- Fetch Inventory Item Stone Modifications
DROP TABLE IF EXISTS #StoneVersion;

SELECT 
    IISV.*
INTO #StoneVersion
FROM [InventoryItemStoneVersion] AS IISV
INNER JOIN #ItemInventory AS I
    ON IISV.InventoryItemID = I.InventoryItemID;

-- Number distinct stones
SELECT DISTINCT 
    StoneNumber = ROW_NUMBER() OVER(ORDER BY InventoryItemStoneId ASC),
    InventoryItemStoneId
INTO #StoneModifications
FROM [InventoryItemStone] AS IIS
INNER JOIN #ItemInventory AS I
    ON IIS.InventoryItemID = I.InventoryItemID;

-- Creating table for inventory changes log
DROP TABLE IF EXISTS #InventoryChange;

CREATE TABLE #InventoryChange
(
    CreatedDate DATETIME NOT NULL,
    InventoryNumber NVARCHAR(50) NULL,
    InventoryItemId NVARCHAR(50) NOT NULL,
    CreatedBy NVARCHAR(201) NULL,
    OldIsNewItem NVARCHAR(50) NULL,
    IsNewItem NVARCHAR(50) NULL,
    OldIsConsignment NVARCHAR(50) NULL,
    IsConsignment NVARCHAR(50) NOT NULL,
    OldIsSalesTaxExempt NVARCHAR(50) NULL,
    IsSalesTaxExempt NVARCHAR(50) NULL,
    OldAllowProtectionPlan NVARCHAR(50) NULL,
    AllowProtectionPlan NVARCHAR(50) NOT NULL,
    OldIsBulkItem NVARCHAR(50) NULL,
    IsBulkItem NVARCHAR(50) NULL,
    OldMaxQuantity NVARCHAR(50) NULL,
    MaxQuantity NVARCHAR(50) NULL,
    OldUPC NVARCHAR(14) NULL,
    UPC NVARCHAR(14) NULL,
    OldReOrderLevel NVARCHAR(50) NULL,
    ReOrderLevel NVARCHAR(50) NULL,
    OldFireArmImporterId NVARCHAR(50) NULL,
    FireArmImporterId NVARCHAR(50) NULL,
    OldItemTypeBrandId NVARCHAR(50) NULL,
    ItemTypeBrandId NVARCHAR(50) NULL,
    OldModel NVARCHAR(30) NULL,
    Model NVARCHAR(30) NULL,
    OldSerialNumber NVARCHAR(50) NULL,
    SerialNumber NVARCHAR(50) NULL,
    OldItemColorId NVARCHAR(50) NULL,
    ItemColorId NVARCHAR(50) NULL,
    OldItemConditionId NVARCHAR(50) NULL,
    ItemConditionId NVARCHAR(50) NULL,
    OldOwnerNumber NVARCHAR(50) NULL,
    OwnerNumber NVARCHAR(50) NULL,
    OldBinNumberId NVARCHAR(50) NULL,
    BinNumberId NVARCHAR(50) NULL,
    OldCost DECIMAL(12, 3) NULL,
    Cost DECIMAL(12, 3) NULL,
    OldResale NVARCHAR(50) NULL,
    Resale NVARCHAR(50) NULL,
    OldMin NVARCHAR(50) NULL,
    Min NVARCHAR(50) NULL,
    OldReplace NVARCHAR(50) NULL,
    Replace NVARCHAR(50) NULL,
    OldQuantity NVARCHAR(50) NULL,
    Quantity NVARCHAR(50) NULL,
    OldComment NVARCHAR(500) NULL,
    Comment NVARCHAR(500) NULL,
    OldMetalId NVARCHAR(50) NULL,
    MetalId NVARCHAR(50) NULL,
    OldKaratId NVARCHAR(50) NULL,
    KaratId NVARCHAR(50) NULL,
    OldJewelryWeight NVARCHAR(50) NULL,
    JewelryWeight NVARCHAR(50) NULL,
    OldJewelryWeightUnitId NVARCHAR(50) NULL,
    JewelryWeightUnitId NVARCHAR(50) NULL,
    OldJewelryGenderId NVARCHAR(50) NULL,
    JewelryGenderId NVARCHAR(50) NULL,
    OldJewelryStyleId NVARCHAR(50) NULL,
    JewelryStyleId NVARCHAR(50) NULL,
    OldJewelrySizeLengthId NVARCHAR(50) NULL,
    JewelrySizeLengthId NVARCHAR(50) NULL,
    OldFirearmActionId NVARCHAR(50) NULL,
    FirearmActionId NVARCHAR(50) NULL,
    OldFirearmFinishId NVARCHAR(50) NULL,
    FirearmFinishId NVARCHAR(50) NULL,
    OldFirearmBarrelsNumberId NVARCHAR(50) NULL,
    FirearmBarrelsNumberId NVARCHAR(50) NULL,
    OldFirearmLength NVARCHAR(20) NULL,
    FirearmLength NVARCHAR(20) NULL,
    OldFirearmCaliberGaugeID NVARCHAR(50) NULL,
    FirearmCaliberGaugeID NVARCHAR(50) NULL,
    OldFirearmCondition NVARCHAR(50) NULL,
    FirearmCondition NVARCHAR(50) NULL,
    OldFirearmBuyDate DATETIME NULL,
    FirearmBuyDate DATETIME NULL,
    OldStoneQuantity NVARCHAR(50) NULL,
    StoneQuantity NVARCHAR(50) NULL,
    OldStoneTypeId NVARCHAR(50) NULL,
    StoneTypeId NVARCHAR(50) NULL,
    OldStoneShapeId NVARCHAR(50) NULL,
    StoneShapeId NVARCHAR(50) NULL,
    OldCarat NVARCHAR(50) NULL,
    Carat NVARCHAR(50) NULL,
    OldStoneColorId NVARCHAR(50) NULL,
    StoneColorId NVARCHAR(50) NULL,
    OldWeight NVARCHAR(50) NULL,
    Weight NVARCHAR(50) NULL,
    OldLength NVARCHAR(50) NULL,
    Length NVARCHAR(50) NULL,
    OldWidth NVARCHAR(50) NULL,
    Width NVARCHAR(50) NULL,
    OldStoneClarityId NVARCHAR(50) NULL,
    StoneClarityId NVARCHAR(50) NULL,
    StoreId NVARCHAR(50) NULL
);

-- Populating #InventoryChange with actual changes
INSERT INTO #InventoryChange
SELECT 
    IIV.CreatedDate,
    (SELECT TOP 1 InventoryNumber FROM [dbo].[InventoryItem] WHERE InventoryItemID = I.InventoryItemID) AS InventoryNumber,
    IIV.InventoryItemId,
    U.UserId AS CreatedBy,
    LAG(IsNewItem, 1) OVER(ORDER BY IIV.CreatedDate) AS OldIsNewItem,
    IsNewItem AS IsNewItem,
    -- Include all other necessary columns
FROM InventoryItemVersion AS IIV
INNER JOIN #ItemInventory AS I ON IIV.InventoryItemID = I.InventoryItemID
-- Add JOINs and WHERE conditions for the changes and filtering criteria
;

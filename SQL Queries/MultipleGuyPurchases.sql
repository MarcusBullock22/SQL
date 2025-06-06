
Declare
    @StoreId INT = NULL,
    @DateFrom DATETIME = NULL,
    @DateTo DATETIME = NULL

BEGIN
    -- Adjust end date
    SET @DateTo = DATEADD(DAY, 1, @DateTo);

    -- Declare FFL number
    DECLARE @FFLNumber VARCHAR(100) = 
    (
        SELECT ISNULL(sso.SystemOptionValue, '')
        FROM StoreSystemOption AS sso
        LEFT JOIN SystemOption AS so ON sso.SystemOptionId = so.SystemOptionId
        WHERE SystemOptionKey = 'FIREARMS_FEDERAL' 
        AND sso.StoreId = @StoreId
    );

    -- Main query to fetch firearms data
    SELECT 
        II.StoreId,
        S.TimeZoneId,
        @FFLNumber AS FFLNumber,
        II.InventoryItemId,
        II.InventoryNumber,
        dbo.fnGetDateTimeByTimeZone(s.TimeZoneId, ISNULL(gle.ReceiptDate, gl.CreatedDate), S.IsDstObserved) AS AcqDate,
        IIF(ety.EntityName = 'Vendor', ISNULL(gle.ReceiptLastName, 'Vendor'), RTRIM(ISNULL(gle.ReceiptFirstName, '')) + ' ' + 
            IIF(ISNULL(gle.ReceiptMiddleName, '') = '', '', LTRIM(RTRIM(gle.ReceiptMiddleName)) + ' ') + ISNULL(gle.ReceiptLastName, 'Customer')) AS 'AcquisitionName',
        LV.Value AS Manufacturer,
        II.Model,
        IT.Value AS GunlogType,
        II.SerialNumber,
        ISNULL(LTRIM(RTRIM(ISNULL(LVCG.Value, ''))), '') AS FirearmCaliberGauge,
        ISNULL(LTRIM(RTRIM(ISNULL(LVFA.Value, ''))), '') AS FirearmAction,
        ISNULL(LTRIM(RTRIM(ISNULL(LVFI.Value, ''))), '') AS FirearmImporter,
        GL.LogNumber
    FROM 
        InventoryItem AS II
    LEFT JOIN 
        Store AS S ON II.StoreId = S.StoreId
    LEFT JOIN 
        ItemType AS IT ON IT.ItemTypeId = II.ItemTypeId
    LEFT JOIN 
        dbo.StoreItemTypeValue AS STV ON STV.ItemTypeId = IT.ItemTypeId AND STV.StoreId = II.StoreId
    LEFT JOIN 
        ItemType AS ITP ON ITP.ItemTypeId = IT.ParentItemTypeId
    LEFT JOIN 
        dbo.StoreItemTypeValue AS STVP ON STVP.ItemTypeId = ITP.ItemTypeId AND STVP.StoreId = II.StoreId
    LEFT JOIN 
        ItemType AS ITPP ON ITPP.ItemTypeId = ITP.ParentItemTypeId
    LEFT JOIN 
        dbo.StoreItemTypeValue AS STVPP ON STVPP.ItemTypeId = ITPP.ItemTypeId AND STVPP.StoreId = II.StoreId
    LEFT JOIN 
        ItemType AS ITPPP ON ITPPP.ItemTypeId = ITPP.ParentItemTypeId
    LEFT JOIN 
        dbo.StoreItemTypeValue AS STVPPP ON STVPPP.ItemTypeId = ITPPP.ItemTypeId AND STVPPP.StoreId = II.StoreId
    LEFT JOIN 
        ItemTypeBrand AS ITB ON ITB.ItemTypeBrandId = II.ItemTypeBrandId
    LEFT JOIN 
        LookupValue AS LV ON ITB.BrandId = LV.LookupValueId
    LEFT JOIN 
        LookupValue AS LVCG ON LVCG.LookupValueId = II.FirearmCaliberGaugeId
    LEFT JOIN 
        LookupValue AS LVFA ON LVFA.LookupValueId = II.FirearmActionId
    LEFT JOIN 
        LookupValue AS LVFI ON LVFI.LookupValueId = II.FirearmImporterId
    INNER JOIN
    (
        SELECT 
            GL.GunLogId, GL.InventoryItemId, GL.StoreId, GL.LogNumber, GL.PickDate, GL.IsCurrentGunLog,
            GL.IsPlaceInHoldPeriod, GL.ATFNumber, GL.NICSNumber, GL.Comments1, GL.Comments2, GL.CreatedDate, 
            GL.CreatedBy, GL.UpdatedDate, GL.UpdatedBy, ROW_NUMBER() OVER(PARTITION BY GL.InventoryItemId ORDER BY GL.GunLogId) AS Rn
        FROM 
            dbo.GunLog AS GL
        LEFT JOIN 
            TransactionItem AS ti ON GL.InventoryItemId = ti.InventoryItemId
        WHERE 
            ti.StatusId <> 6
    ) AS GL ON GL.InventoryItemId = II.InventoryItemId AND GL.Rn = 1
    LEFT JOIN 
        dbo.GunLogEntity AS gle ON GL.GunLogId = gle.GunLogId
    LEFT JOIN 
        Entity AS ety ON gle.ReceiptEntityId = ety.EntityID
    WHERE
        II.StoreId = @StoreId
        AND dbo.fnGetDateTimeByTimeZone(s.TimeZoneId, ISNULL(gle.ReceiptDate, gl.CreatedDate), S.IsDstObserved) BETWEEN @DateFrom AND @DateTo
        AND ISNULL(II.IsDeleted, 0) = 0
        AND II.FirearmCondition != 'NEW'
        AND (
            IT.ItemTypeId = 8 OR ITP.ItemTypeId = 8 OR ITPP.ItemTypeId = 8 OR ITPPP.ItemTypeId = 8
        )
        AND (
            ISNULL(IT.IsPostToGunLog, 0) = 1 OR ISNULL(ITP.IsPostToGunLog, 0) = 1 OR ISNULL(ITPP.IsPostToGunLog, 0) = 1
            OR ISNULL(ITPPP.IsPostToGunLog, 0) = 1 OR ISNULL(STV.IsPostToGunLog, 0) = 1 OR ISNULL(STVP.IsPostToGunLog, 0) = 1
            OR ISNULL(STVPP.IsPostToGunLog, 0) = 1 OR ISNULL(STVPPP.IsPostToGunLog, 0) = 1
        )
    ORDER BY 
        AcqDate
    OPTION (RECOMPILE);

END;

SELECT 
    T.TransactionId,
    TI.TransactionItemId,
    II.InventoryItemId,
    II.InventoryNumber,
    TI.Cost,
    TI.Quantity,
    IT.ItemTypeName,
    LV.Value AS ItemTypeBrandId,
    II.Model,
    II.SerialNumber,
    LVI.Value AS ItemColorId,
    LVIC.Value AS ItemConditionId,
    II.OwnerNumber,
    II.BinNumber,
    II.Resale,
    II.Min,
    II.Replace,
    II.Comment AS ItemDescription,
    LVM.Value AS MetalId,
    LVK.Value AS KaratId,
    II.JewelryWeight,
    LVJWU.Value AS JewelryWeightUnitId,
    LVJG.Value AS JewelryGenderId,
    LVJS.Value AS JewelryStyleId,
    LVJSL.Value AS JewelrySizeLengthId,
    LVFA.Value AS FirearmActionId,
    LVFI.Value AS FirearmFinishId,
    LVFB.Value AS FirearmBarrelsNumberId,
    II.FirearmLength,
    LVC.Value AS FirearmCaliberGaugeId,
    II.FirearmCondition,
    II.FirearmImporterId,
    II.FireArmBuyDate,
    S.StatusName AS StatusId,
    II.IsNewItem,
    II.IsSalesTaxExempt,
    II.InventoryItemTypeSourceId,
    II.UPC,
    II.MaxQuantity,
    II.ReOrderLevel,
    II.CreatedDate,
    II.UpdatedDate,
    II.StoreId,
    II.IsInventoryItem,
    II.ReasonForDelete,
    II.Barcode,
    LVBIN.Value AS BinNumberId,
    II.IsReused,
    II.SourceSplittedInventoryItemId,
    II.IsForfeit,
    II.RowVersion,
    II.SourceInventoryNumber,
    II.ContainRepairs,
    II.IsEforoItem,
    II.ReusedId,
    II.IsBulkItem,
    II.IsDeleted,
    II.AllowProtectionPlan
FROM ItemInventory II
LEFT JOIN TransactionItem TI ON TI.InventoryItemId = II.InventoryItemId
LEFT JOIN Transaction T ON T.TransactionId = TI.TransactionId
LEFT JOIN ItemLot IIL ON IIL.InventoryItemId = II.InventoryItemId
LEFT JOIN ItemType IT ON IT.ItemTypeId = II.ItemTypeId
LEFT JOIN Status S ON S.StatusId = II.StatusId
LEFT JOIN LookupValue LVI ON LVI.LookupValueId = II.ItemColorId
LEFT JOIN LookupValue LVIC ON LVIC.LookupValueId = II.ItemConditionId
LEFT JOIN LookupValue LVJSL ON LVJSL.LookupValueId = II.JewelrySizeLengthId
LEFT JOIN LookupValue LVK ON LVK.LookupValueId = II.KaratId
LEFT JOIN LookupValue LVJWU ON LVJWU.LookupValueId = II.JewelryWeightUnitId
LEFT JOIN LookupValue LVJG ON LVJG.LookupValueId = II.JewelryGenderId
LEFT JOIN LookupValue LVJS ON LVJS.LookupValueId = II.JewelryStyleId
LEFT JOIN LookupValue LVM ON LVM.LookupValueId = II.MetalId
LEFT JOIN LookupValue LVC ON LVC.LookupValueId = II.FirearmCaliberGaugeId
LEFT JOIN LookupValue LVFA ON LVFA.LookupValueId = II.FirearmActionId
LEFT JOIN LookupValue LVFI ON LVFI.LookupValueId = II.FirearmFinishId
LEFT JOIN LookupValue LVFB ON LVFB.LookupValueId = II.FirearmBarrelsNumberId
LEFT JOIN ItemTypeBrand ITB ON ITB.ItemTypeBrandId = II.ItemTypeBrandId
LEFT JOIN LookupValue LV ON LV.LookupValueId = ITB.BrandId
LEFT JOIN LookupValue LVBin ON LVBin.LookupValueId = II.BinNumberId
WHERE TI.StatusId IN (1,2)
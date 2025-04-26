SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



DECLARE
    @FromDate DATE = '07/01/2022',
    @ToDate DATE = '07/02/2022',
    @StoreId INT = 1;

BEGIN
    SET NOCOUNT ON;

    DROP TABLE IF EXISTS #TransactionSummary, #TransactionPayments, #DrawerTransactions, #FinalSums;

    DECLARE 
        @TotalCostSales DECIMAL(18, 2), @TotalCostLayaway DECIMAL(18, 2), @TotalCostRepair DECIMAL(18, 2),
        @Sale DECIMAL(18, 2), @ExemptSale DECIMAL(18, 2), @Layaway DECIMAL(18, 2), @ExemptLayaway DECIMAL(18, 2),
        @Repair DECIMAL(18, 2), @ExemptRepair DECIMAL(18, 2), @OverriddenServiceCharges DECIMAL(18, 2),
        @OverriddenRedemptions DECIMAL(18, 2), @RewrittenPawnAmount DECIMAL(18, 2), 
        @FromBank MONEY, @ToBank MONEY, @ShortOverTotal MONEY;


    DECLARE @TimeZoneId VARCHAR(MAX) = (SELECT TimeZoneId FROM Store WHERE StoreId = @StoreId);
    DECLARE @IsDstObserved BIT = (SELECT IsDstObserved FROM Store WHERE StoreId = @StoreId);

    -- Convert from local time to UTC
    DECLARE @FromDateUTC DATETIME = dbo.fnGetUTCTimeByTimeZone(@TimeZoneId, CAST(@FromDate AS DATE), @IsDstObserved);
    DECLARE @EndDateUTC DATETIME = dbo.fnGetUTCTimeByTimeZone(@TimeZoneId, CAST(DATEADD(DAY, 1, @ToDate) AS DATE), @IsDstObserved);

    -- Create the temporary table to store summary values
    CREATE TABLE #FinalSums (
        IsTaxExempt BIT,
        TransactionTypeId TINYINT,
        TotalCost MONEY,
        TotalResale MONEY
    );

    -- 1. Drawer Transactions - Get drawer transaction data
    SELECT 
        CASE 
            WHEN IsCashIn = 1 THEN -1
            WHEN IsCashOut = 1 THEN -2
            WHEN IsDrawerBalance = 1 THEN -3
            WHEN IsBankToDrawer = 1 THEN -4
            WHEN IsDrawerToBank = 1 THEN -5
            WHEN IsDrawerToDrawer = 1 THEN -6
            WHEN IsEmployeeAdded = 1 THEN -7
        END 'TransactionTypeId',
        CASE 
            WHEN IsBankToDrawer = 1 OR IsDrawerToBank = 1 OR IsDrawerToDrawer = 1 THEN MovedAmount
            WHEN IsDrawerBalance = 1 THEN OverShortAmount
            WHEN IsEmployeeAdded = 1 THEN NULL
            ELSE VWCDM.Amount
        END 'TransactionAmount',
        OverShortAmount
    INTO #DrawerTransactions
    FROM CashDrawerMaintenance AS VWCDM
    LEFT JOIN CashInOut AS CIO ON VWCDM.CashInOutId = CIO.CashInOutId
    AND ISNULL(CIO.CreatedDate, VWCDM.CreatedDate) BETWEEN @FromDateUTC AND @EndDateUTC
    WHERE VWCDM.StoreId = @StoreId AND (CIO.CashInOutId IS NOT NULL OR IsEmployeeAdded = 1);

    -- Populate Totals for drawer transactions
    SELECT 
        @FromBank = SUM(CASE WHEN TransactionTypeId = -4 THEN TransactionAmount ELSE 0 END),
        @ToBank = SUM(CASE WHEN TransactionTypeId = -5 THEN TransactionAmount ELSE 0 END),
        @ShortOverTotal = SUM(OverShortAmount)
    FROM #DrawerTransactions;


    SELECT 
        @OverriddenServiceCharges = SUM(CASE WHEN PaymentTypeId = 4 THEN OverriddenAmount * SIGN(Amount) ELSE 0 END),
        @OverriddenRedemptions = SUM(CASE WHEN PaymentTypeId = 9 THEN OverriddenAmount * SIGN(Amount) ELSE 0 END),
        @RewrittenPawnAmount = SUM(CASE WHEN PaymentTypeId = 17 THEN PrincipalPaid ELSE 0 END)
    FROM TransactionPaymentDetails
    WHERE CreatedDate BETWEEN @FromDateUTC AND @EndDateUTC
    AND StoreId = @StoreId
    AND PaymentTypeId IN (4, 9, 17);


    INSERT INTO #FinalSums
    SELECT 
        TI.IsTaxExempt,
        T.TransactionTypeId,
        TI.Quantity * TI.Cost AS TotalCost,
        TI.Quantity * TI.Resale AS TotalResale
    FROM TransactionItemDetails TI
    INNER JOIN Transactions T ON TI.TransactionId = T.TransactionId
    INNER JOIN TransactionCheckoutBatch TCB ON T.TransactionId = TCB.TransactionId
    WHERE T.StoreId = @StoreId
    AND (TI.StatusId = 20 OR TI.StatusId = 19)
    AND T.TransactionTypeId = 3
    AND TCB.TransactionAmount >= 0
    AND T.InDate BETWEEN @FromDateUTC AND @EndDateUTC;


    INSERT INTO #FinalSums
    SELECT 
        TI.IsTaxExempt,
        T.TransactionTypeId,
        TI.Quantity * TI.Cost AS TotalCost,
        TI.Quantity * TI.Resale AS TotalResale
    FROM TransactionItemDetails TI
    INNER JOIN Transactions T ON TI.TransactionId = T.TransactionId
    INNER JOIN TransactionPaymentDetails Pickup ON T.TransactionId = Pickup.TransactionId AND Pickup.PaymentTypeId = 35
    LEFT JOIN (
        SELECT TransactionId AS SoldLayawayTransactionId
        FROM TransactionVersion AS tv
        WHERE tv.TransactionTypeId = 5 AND tv.StatusId = 2
        AND tv.StoreId = @StoreId
        GROUP BY TransactionId
    ) AS SLWY ON T.TransactionId = SLWY.SoldLayawayTransactionId
    WHERE T.TransactionTypeId = 5
    AND T.StoreId = @StoreId
    AND T.UpdatedDate BETWEEN @FromDateUTC AND @EndDateUTC;


    INSERT INTO #FinalSums
    SELECT 
        TI.IsTaxExempt,
        T.TransactionTypeId,
        TI.Quantity * TI.Cost AS TotalCost,
        TI.Quantity * TI.Resale AS TotalResale
    FROM TransactionItemDetails TI
    INNER JOIN Transactions T ON TI.TransactionId = T.TransactionId
    INNER JOIN TransactionRepairDetails TR ON T.TransactionId = TR.TransactionId
    INNER JOIN TransactionPaymentDetails Pickup ON T.TransactionId = Pickup.TransactionId
    WHERE T.TransactionTypeId = 8
    AND T.StoreId = @StoreId
    AND Pickup.PaymentTypeId = 35
    AND T.IsQueued = 0
    AND T.InDate BETWEEN @FromDateUTC AND @EndDateUTC;

    -- Final Results - Calculate totals for the report
    SELECT 
        ISNULL(@TotalCostSales, 0) AS CostSales,
        ISNULL(@TotalCostLayaway, 0) AS CostLayaway,
        ISNULL(@TotalCostRepair, 0) AS CostRepair,
        ISNULL(@Sale, 0) AS Sale,
        ISNULL(@ExemptSale, 0) AS ExemptSale,
        ISNULL(@Layaway, 0) AS Layaway,
        ISNULL(@ExemptLayaway, 0) AS ExemptLayaway,
        ISNULL(@Repair, 0) AS Repair,
        ISNULL(@ExemptRepair, 0) AS ExemptRepair,
        ISNULL(@OverriddenServiceCharges, 0) AS OverrideSVCHG,
        ISNULL(@OverriddenRedemptions, 0) AS OverrideRedemption,
        ISNULL(@RewrittenPawnAmount, 0) AS RewrittenAmount,
        ISNULL(@FromBank, 0) AS FromBank,
        ISNULL(@ToBank, 0) AS ToBank,
        ISNULL(@ShortOverTotal, 0) AS OverShort,
        ISNULL(CAST(
            (ISNULL(@Sale, 0) + ISNULL(@ExemptSale, 0) + ISNULL(@Layaway, 0) + ISNULL(@ExemptLayaway, 0) + ISNULL(@Repair, 0) + ISNULL(@ExemptRepair, 0) -
            (ISNULL(@TotalCostSales, 0) + ISNULL(@TotalCostLayaway, 0) + ISNULL(@TotalCostRepair, 0))
        ) / NULLIF(ISNULL(@Sale, 0) + ISNULL(@ExemptSale, 0) + ISNULL(@Layaway, 0) + ISNULL(@ExemptLayaway, 0) + ISNULL(@Repair, 0) + ISNULL(@ExemptRepair, 0), 0) * 100 AS DECIMAL(16, 2)), 0) AS ProfitMargin;

END;

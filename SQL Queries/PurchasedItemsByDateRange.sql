ALTER PROCEDURE [dbo].[rpt_ItemsInPawn]
(
    @FromDate DATETIME = NULL,
    @EndDate DATETIME = NULL,
    @FromTicket INT = NULL,
    @ToTicket INT = NULL,
    @CustomerFrom NVARCHAR(10) = NULL,
    @ToCustomer NVARCHAR(10) = NULL,
    @INVENTORY_ITEM_TYPE_ID INT = -1,
    @INVENTORY_ITEM_LEVEL2_ID INT = -1,
    @INVENTORY_ITEM_LEVEL3_ID INT = -1,
    @INVENTORY_ITEM_LEVEL4_ID INT = -1,
    @BinNumber NVARCHAR(30) = NULL,
    @PawnAmount DECIMAL(12, 2) = NULL,
    @StoreId INT = NULL,
    @ReportType NVARCHAR(100) = '',
    @ExcludeFireArm BIT = 0
)
AS
BEGIN
    -- Drop temporary tables if they exist
    DROP TABLE IF EXISTS #PawnReportData, #tempPayments;

    -- Declare necessary variables
    DECLARE @CurrentUTCDatetime DATETIME = GETUTCDATE(),
            @TimeZoneId VARCHAR(100),
            @IsDstObserved BIT,
            @FromDateUTC DATETIME,
            @EndDateUTC DATETIME;

    -- Retrieve TimeZoneId and IsDstObserved for the given store
    SELECT @TimeZoneId = TimeZoneId, @IsDstObserved = IsDstObserved
    FROM Store
    WHERE StoreId = @StoreId;

    -- Normalize parameters for further use
    SELECT 
        @FromTicket = ISNULL(@FromTicket, -1),
        @ToTicket = ISNULL(@ToTicket, 2147483647),
        @CustomerFrom = ISNULL(@CustomerFrom, ''),
        @ToCustomer = ISNULL(@ToCustomer, ''),
        @INVENTORY_ITEM_TYPE_ID = ISNULL(@INVENTORY_ITEM_TYPE_ID, -1),
        @INVENTORY_ITEM_LEVEL2_ID = ISNULL(@INVENTORY_ITEM_LEVEL2_ID, -1),
        @INVENTORY_ITEM_LEVEL3_ID = ISNULL(@INVENTORY_ITEM_LEVEL3_ID, -1),
        @INVENTORY_ITEM_LEVEL4_ID = ISNULL(@INVENTORY_ITEM_LEVEL4_ID, -1),
        @BinNumber = ISNULL(@BinNumber, ''),
        @PawnAmount = ISNULL(@PawnAmount, 0),
        @ExcludeFireArm = ISNULL(@ExcludeFireArm, 0),
        @FromDateUTC = dbo.fnGetUTCTimeByTimeZone(@TimeZoneId, CAST(@FromDate AS DATE), @IsDstObserved),
        @EndDateUTC = dbo.fnGetUTCTimeByTimeZone(@TimeZoneId, CAST(DATEADD(DAY, 1, @EndDate) AS DATE), @IsDstObserved);

    -- Adjust parameters for specific report types
    IF @ReportType != 'CustomerWise'
    BEGIN
        SET @CustomerFrom = '', @ToCustomer = '';
    END;
    
    IF @ReportType != 'TicketNumber'
    BEGIN
        SET @FromTicket = -1, @ToTicket = 2147483647;
    END;

    IF @ReportType != 'DateRange'
    BEGIN
        SET @FromDateUTC = dbo.fnGetUTCTimeByTimeZone(@TimeZoneId, '1900-01-01', @IsDstObserved),
            @EndDateUTC = dbo.fnGetUTCTimeByTimeZone(@TimeZoneId, CAST(DATEADD(DAY, 1, GETDATE()) AS DATE), @IsDstObserved);
    END;

    -- Create #tempPayments table
    SELECT 
        tp.TransactionId,
        ISNULL(PeriodDate, PaymentDate) AS PeriodDate,
        ToPaid,
        ROW_NUMBER() OVER (PARTITION BY tp.TransactionId ORDER BY PaymentDate DESC) AS Rns
    INTO #tempPayments
    FROM TransactionPayment AS tp
    LEFT JOIN (
        SELECT 
            SUM(tp.Amount) AS ToPaid, 
            tp.TransactionId
        FROM TransactionPayment AS TP
        LEFT JOIN [Transaction] AS T ON T.TransactionId = TP.TransactionId
        WHERE T.StoreId = @StoreId
        GROUP BY tp.TransactionId, t.StoreId
    ) AS tp2 ON TP.TransactionId = TP2.TransactionId
    LEFT JOIN [Transaction] AS T ON T.TransactionId = TP.TransactionId
    WHERE PaymentTypeId NOT IN (3, 14, 9, 17) 
        AND TP.Amount > 0
        AND T.StoreId = @StoreId
    ORDER BY PaymentDate DESC;

    -- Gathering all Active Loans into #PawnReportData table
    SELECT 
        S.StoreId, 
        S.StoreName, 
        T.TransactionId, 
        T.TicketNumber,
        T.InDate AS 'InDate',
        T.OutDate AS 'OutDate',
        CONVERT(DECIMAL(16, 2), 0) AS 'CurrentServiceCharges',
        VI.BinNumber, 
        C.FirstName, 
        C.MiddleName, 
        C.LastName,
        REPLACE(ISNULL(C.FirstName, '') + ' ' + RTRIM(LTRIM(ISNULL(C.MiddleName, ''))) + ' ' + ISNULL(C.LastName, ''), '  ', ' ') AS 'CustomerName',
        T.Amount, 
        VI.Resale, 
        TI.Cost, 
        TI.Quantity, 
        CONVERT(INT, CASE
                        WHEN RF.NumDefaulted + RF.NumRedeemed > 0
                            THEN (CAST(RF.NumRedeemed AS FLOAT) / (RF.NumDefaulted + RF.NumRedeemed)) * 100
                        ELSE 0
                    END) AS 'RedemptionRatio',
        REPLACE(REPLACE(SUBSTRING(VI.ItemDescription, 1, 250), CHAR(13), ' '), CHAR(10), '') AS 'ItemDescription',
        u.UserName, 
        CASE 
            WHEN DATEDIFF(DAY, T.OutDate, @CurrentUTCDatetime) > 0 
                THEN DATEDIFF(DAY, T.OutDate, @CurrentUTCDatetime)
            ELSE 0 
        END AS 'DaysOverDue',
        CASE 
            WHEN tp.ToPaid = 0 
                AND DATEDIFF(DAY, T.InDate, @CurrentUTCDatetime) > 0 
                THEN DATEDIFF(DAY, T.InDate, @CurrentUTCDatetime)
            WHEN DATEDIFF(DAY, ISNULL(TP.PeriodDate, T.InDate), @CurrentUTCDatetime) > 0
                AND T.StatusID <> 14
                THEN DATEDIFF(DAY, ISNULL(TP.PeriodDate, T.InDate), @CurrentUTCDatetime)
            ELSE 0 
        END AS 'PaymentUpto',
        TI.StatusId AS 'TransItemStatusID',
        T.StatusID,
        ISNULL(
            (SELECT TOP 1 PeriodDate
             FROM #tempPayments
             WHERE TransactionId = t.TransactionId
             AND Rns = 1), T.InDate) AS LayPaymentToDate,
        0 AS LoanPeriod,
        CAST(NULL AS DATETIME) AS PeriodDate,
        t.RateTableId, 
        CAST(0.00 AS DECIMAL(18, 2)) AS MPR,
        s.TimezoneId,
        sso.IsProrating,
        sso.ProrateDays,
        sso.IsServChrgPro,
        sso.StartProrating
    INTO #PawnReportData
    FROM [Transaction] AS T
    INNER JOIN Store AS S ON T.StoreId = S.StoreId
    JOIN TransactionItem AS TI ON T.TransactionId = TI.TransactionId
    JOIN vwItem AS VI ON TI.InventoryItemId = VI.InventoryItemId
    JOIN Customer AS C ON T.CustomerId = C.CustomerId
    JOIN [USER] AS u ON T.CreatedBy = U.UserId
    LEFT JOIN #tempPayments AS tp ON T.TransactionId = tp.TransactionID AND Rns = 1
    LEFT JOIN (
        SELECT 
            StoreId, 
            IIF(PAWN_PRORATING_DAILY_PRORATE = 'True', 1, 0) AS 'IsProrating',
            IIF(PAWN_PRORATING_NUMBER_DAYS IS NOT NULL, PAWN_PRORATING_NUMBER_DAYS, 30) AS 'ProrateDays',
            IIF(PAWN_PRORATING_SVC_CHARGES = 'True', 1, 0) AS 'IsServChrgPro',
            IIF(PAWN_PRORATING_SVC_CHARGES_START_PERIOD IS NOT NULL, PAWN_PRORATING_SVC_CHARGES_START_PERIOD, 1) AS 'StartProrating'
        FROM (
            SELECT 
                SSO.StoreId, 
                so.SystemOptionKey, 
                sso.SystemOptionValue
            FROM StoreSystemOption AS sso
            INNER JOIN SystemOption AS so ON SSO.SystemOptionId = so.SystemOptionId
            WHERE SSO.StoreId = @StoreId
              AND so.SystemOptionKey IN('PAWN_PRORATING_DAILY_PRORATE', 'PAWN_PRORATING_NUMBER_DAYS', 'PAWN_PRORATING_SVC_CHARGES', 'PAWN_PRORATING_SVC_CHARGES_START_PERIOD')
        ) AS SystemOption 
        PIVOT(MAX(SystemOptionValue) FOR SystemOptionKey IN (
            [PAWN_PRORATING_DAILY_PRORATE], 
            [PAWN_PRORATING_NUMBER_DAYS], 
            [PAWN_PRORATING_SVC_CHARGES], 
            [PAWN_PRORATING_SVC_CHARGES_START_PERIOD]
        )) AS PivotSysOption
    ) AS sso ON sso.StoreId = s.StoreId
    LEFT JOIN (
        SELECT 
            SUM(CASE WHEN StatusId = 5 THEN 1 ELSE 0 END) AS 'NumRedeemed', 
            SUM(CASE WHEN StatusId = 22 THEN 1 ELSE 0 END) AS 'NumDefaulted', 
            CustomerId
        FROM [Transaction]
        WHERE TransactionTypeId = 1
          AND StoreId = @StoreId
          AND StatusId IN (5, 22)
        GROUP BY CustomerId
    ) AS RF ON T.CustomerId = RF.CustomerId
    WHERE 
        T.StoreId = @StoreId 
        AND T.TransactionTypeId = 1 
        AND T.StatusId IN (23, 14)
        AND (
            (@FromDateUTC IS NULL AND @EndDateUTC IS NOT NULL AND T.InDate <= @EndDateUTC) 
            OR (@FromDateUTC IS NOT NULL AND @EndDateUTC IS NOT NULL AND T.InDate BETWEEN @FromDateUTC AND @EndDateUTC)
            OR (@FromDateUTC IS NOT NULL AND @EndDateUTC IS NULL AND T.InDate >= @FromDateUTC)
        )
        AND t.TicketNumber BETWEEN @FromTicket AND @ToTicket
        AND T.Amount >= @PawnAmount
        AND (
            @INVENTORY_ITEM_TYPE_ID = -1 OR vi.LEVEL1ID = @INVENTORY_ITEM_TYPE_ID
        )
        AND (
            @INVENTORY_ITEM_LEVEL2_ID = -1 OR vi.LEVEL2ID = @INVENTORY_ITEM_LEVEL2_ID
        )
        AND (
            @INVENTORY_ITEM_LEVEL3_ID = -1 OR vi.LEVEL3ID = @INVENTORY_ITEM_LEVEL3_ID
        )
        AND (
            @INVENTORY_ITEM_LEVEL4_ID = -1 OR vi.LEVEL4ID = @INVENTORY_ITEM_LEVEL4_ID
        )
        AND (
            @BinNumber = '' OR vi.BinNumber = @BinNumber
        )
        AND (
            @ExcludeFireArm = 0 
            OR (VI.IsFirearm = 0 AND VI.IsJewelry = 0)
        )
        AND (
            @CustomerFrom = '' 
            OR SUBSTRING(c.LastName, 1, LEN(RTRIM(LTRIM(@CustomerFrom)))) >= RTRIM(LTRIM(@CustomerFrom))
        )
        AND (
            @ToCustomer = '' 
            OR SUBSTRING(c.LastName, 1, LEN(RTRIM(LTRIM(@ToCustomer)))) <= RTRIM(LTRIM(@ToCustomer))
        );

    -- Further operations
    -- (Calculation, Final Results etc.)

END;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



Declare
    @TransactionId          INT = NULL,
    @StoreId                INT = NULL,
    @PageNumber             INT = 1,
    @NumItemsPerPage        INT = NULL,
    @LongItemDescriptOrShort BIT = 0 


BEGIN

    -- Drop temp tables if they exist
    IF OBJECT_ID(N'tempdb..#RateTableTemp', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #RateTableTemp;
    END;
    IF OBJECT_ID(N'tempdb..#TempData', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #TempData;
    END;

    -- Declare necessary variables
    DECLARE @TotalRows INT;
    DECLARE @Remainder INT;
    DECLARE @NumPages INT;
    DECLARE @NextPageRows INT;
    SET @TotalRows = 0;
    DECLARE @PeriodPercent DECIMAL(18, 14);
    DECLARE @AmountPercent DECIMAL(18, 10);
    DECLARE @FireArmCount INT;
    DECLARE @ItemCost DECIMAL(18, 2);
    DECLARE @PawnInDate DATE;
    DECLARE @DayDifference INT;
    DECLARE @CurrentDate DATE;
    DECLARE @OutDate DATE;
    DECLARE @FirearmFeeIncludedInAPR BIT;
    DECLARE @FirearmFee DECIMAL(18, 2) = 0.00;
    DECLARE @PawnProratingDailyProrate BIT;
    DECLARE @PawnProratingTexasMinimum DECIMAL(18, 2) = 0.00;
    DECLARE @PawnBuyDurationServiceChargeIsMonthly BIT;
    DECLARE @PawnBuyDurationServiceChargePeriod INT;
    DECLARE @ServiceCharges DECIMAL(18, 2);
    DECLARE @ServiceChargesDays INT = 0;
    DECLARE @PawnTaxAmount DECIMAL(30, 14) = 0.00;
    DECLARE @PawnTotalCost DECIMAL(30, 14) = 0.00;
    DECLARE @APRAmount DECIMAL(18, 2);
    DECLARE @ItemDescription VARCHAR(MAX);
    DECLARE @OneTimeFeeOnly DECIMAL(18, 2) = 0.00;
    DECLARE @StorageFee DECIMAL(18, 2) = 0.00;
    DECLARE @LostTicketFee DECIMAL(18, 2) = 0.00;
    DECLARE @RateServiceFee DECIMAL(18, 2) = 0.00;
    DECLARE @RateInterest DECIMAL(18, 2) = 0.00;
    DECLARE @RateOneTimeFee DECIMAL(18, 2) = 0.00;
    DECLARE @PawnBuyOtherFeeReminderFee DECIMAL(18, 2) = 0.00;
    DECLARE @RatePeriodFee DECIMAL(18, 2) = 0.00;
    DECLARE @Divider DECIMAL(18, 12);
    DECLARE @OnlyCurrentServiceCharge DECIMAL(18, 2);
    DECLARE @PawnBuyFeeOneTimeFeeAsPercentage BIT;
    DECLARE @State NVARCHAR(MAX);
    DECLARE @PawnBuyOtherFeeOneTimeFeeIncludeInAPR BIT;
    DECLARE @PawnBuyOtherFeeOneTimeFeeAbilityToChange BIT;
    DECLARE @PawnBuyOtherFeeOneTimeFeeAsPercentage BIT;
    DECLARE @PawnBuyFeeFeePerPeriodAsPercentage BIT;
    DECLARE @PawnBuyOtherFeesStorageFeeMonthly BIT;
    DECLARE @PawnBuyFeeOneTimeFeeIncludedInAPR BIT;
    DECLARE @PawnBuyFeeFeePerPeriodIncludedInAPR BIT;
    DECLARE @OriginalTicketNumber INT;
    DECLARE @TimeZoneId VARCHAR(100);
    DECLARE @PoliceLawEnforcementAgency VARCHAR(100);

    -- Get system options and other values
    SELECT 
        @FirearmFeeIncludedInAPR = sso.SystemOptionValue
    FROM SystemOption AS so
    LEFT JOIN StoreSystemOption AS sso
        ON so.SystemOptionId = sso.SystemOptionId
    WHERE so.SystemOptionKey = 'PAWNBUY_OTHER_FEE_FIREARM_IS_INCLUDED'
        AND sso.StoreId = @StoreId;

    -- More system option fetches (renamed variables for clarity)
    SELECT 
        @PawnProratingDailyProrate = sso.SystemOptionValue
    FROM SystemOption AS so
    LEFT JOIN StoreSystemOption AS sso
        ON so.SystemOptionId = sso.SystemOptionId
    WHERE so.SystemOptionKey = 'PAWN_PRORATING_DAILY_PRORATE'
        AND sso.StoreId = @StoreId;

    -- Repeat similar queries to fetch all necessary system options...
    -- (All queries here follow the same pattern of fetching options)

    -- Get store time zone and state
    SELECT 
        @State = LTRIM(RTRIM([State])),
        @TimeZoneId = TimeZoneId
    FROM Store
    WHERE StoreId = @StoreId;

    -- Get pawn-in date and original ticket number
    SELECT 
        @PawnInDate = CAST(dbo.fnGetDateTimeByTimeZone (@TimeZoneId, InDate, 1) AS DATE)
    FROM Transactions
    WHERE TransactionId = @TransactionId;

    SET @OriginalTicketNumber =
    (
        SELECT 
            TicketNumber
        FROM Transactions AS T
        INNER JOIN
        (
            SELECT TOP 1 
                ISNULL(rh.OriginalTransactionId, OT.TransactionId) AS OriginalTransactionId
            FROM Transactions AS OT
            LEFT JOIN RewriteHistory AS rh
                ON OT.TransactionId = rh.TransactionId
            WHERE OT.TransactionId = @TransactionId
        ) AS OG
        ON T.TransactionId = OG.OriginalTransactionId
    );


    SELECT 
        ROW_NUMBER() OVER (ORDER BY TRI.TransactionId) AS InvoiceRow,
        CONVERT(VARCHAR(10), TR.TicketNumber) AS TicketNumber,
        CAST(TRI.TransactionId AS VARCHAR(MAX)) AS TransactionId,
        CONVERT(VARCHAR(12), TRI.Quantity) AS ItemQuantity,
        CAST(TRI.Cost AS DECIMAL(18, 2)) AS ItemCost,
        CAST(@ItemCost AS DECIMAL(18, 2)) AS TotalCost,
        CONVERT(VARCHAR(12), dbo.fnGetDateTimeByTimeZone (@TimeZoneId, Tr.OutDate, 1), 101) AS OutDate,
        ISNULL(LTRIM(RTRIM(CUS.FirstName)), '') + ' ' + LTRIM(RTRIM(CUS.LastName)) AS PledgorName,
    INTO 
        #TempData
    FROM Transactions AS TR
    LEFT JOIN Customers AS CUS ON TR.CustomerId = CUS.CustomerId
    LEFT JOIN TransactionItems AS TRI ON TRI.TransactionId = TR.TransactionId


    SELECT 
        * 
    FROM #TempData;

    -- Cursor setup for pagination
    DECLARE @Tid INT;
    DECLARE db_cursor CURSOR
    FOR SELECT 
            T.TransactionId
        FROM Transactions AS T
        LEFT JOIN TransactionItems AS TI
            ON TI.TransactionId = T.TransactionId
        WHERE T.TransactionId = @TransactionId;

    OPEN db_cursor;
    FETCH NEXT FROM db_cursor INTO @Tid;

    WHILE @@Fetch_Status = 0
    BEGIN

        -- Logic for calculating page number and inserting into temp table
        SET @Sum = CASE
                       WHEN @Sum_count % @NumItemsPerPage = 0
                           THEN @Sum + 1
                       ELSE @Sum
                   END;

        SET @Sum_count = @Sum_count + 1;

        INSERT INTO @TempData
               SELECT 
                   @Sum AS counters
                 , InvoiceRow
                 , TicketNumber
                 , TransactionId
                 , ItemQuantity
                 , ItemCost
                 , OneTimeFeeOnly
                 , RateInterest
                 , RateOneTimeFee
                 , RateFeePerPeriod
                 , RateServiceCharges
                 , StorageFee
                 , isMonthlyStorage
                 , ItemTotalCost
                 , InDate
                 , StatusCode
                 , IDType1
                 , IDNum1
                 , CustomerNumber
                 , BirthDate
                 , CustomerFingerPrint
                 , TransactionSignature
                 , ItemTypeId
                 , ItemTypeName
                 , ItemDescription
                 , InventoryNumber
                 , Bin
                 , ItemCategory
                 , PawnTax
                 , PawnTotalAmount
                 , TotalCost
                 , OutDate
                 , APR
                 , PledgorName
                 , City
                 , State
                 , ZipCode
                 , Sex
                 , Height
                 , Eyes
                 , Hair
                 , CustomerAddress
                 , CustomerAddress1
                 , CustomerAddress2
                 , Features
                 , EmpIn
                 , EmpOut
                 , Amount
                 , CustomerPhone
                 , CellPhone
                 , CusRace
                 , CustWeight
                 , CustomerSex
                 , ItemDesc
                 , APR1
                 , APR2
                 , APR3
                 , Barcode
                 , JewelryWeight
                 , PeriodStartDate
                 , PeriodEndDate
                 , PeriodStartDate2
                 , PeriodEndDate2
                 , ServiceCharges2
                 , Redemption2
                 , PeriodStartDate3
                 , PeriodEndDate3
                 , ServiceCharges3
                 , Redemption3
                 , PeriodStartDate4
                 , PeriodEndDate4
                 , ServiceCharges4
                 , Redemption4
                 , PeriodStartDate5
                 , PeriodEndDate5
                 , ServiceCharges5
                 , Redemption5
                 , PawnTotalAmount - OneTimeFeeOnly
                 , CusIdentification
                 , LostTicketFee
                 , OriginalTicketNumber
                 , GunProcessingFee
                 , ID1ExpiryDate
                 , ID1StateIssueID
                 , FirstName
                 , MiddleName
                 , LastName
                 , PoliceStation
                 , ReminderFee 
               FROM #TempData
               WHERE InvoiceRow = @Sum_count;

        FETCH NEXT FROM db_cursor INTO @Tid;
    END;

    CLOSE db_cursor;
    DEALLOCATE db_cursor;

    SELECT 
        * 
      , CEILING(@Sum_count * 1.0 / @NumItemsPerPage) AS TotalPages
    FROM @TempData
    WHERE counters = @PageNumber;

END;

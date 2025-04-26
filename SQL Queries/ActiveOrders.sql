Select 
T.OrderId,
TT.OrdertypeDesc,
T.LocationId,
ClientId,
OrderNumber,
Duration,
Period,
InDate,
OutDate,
TotalAmount,
PricingId,
OrderNote,
IsOrderActive,
T.IsOrderDeleted,
IsOrderQueued,
T.DateCreated,
U.CreatedByUser as CreatedBy,
T.DateUpdated,
S.statusname,
T.OrderMessage,
T.OrderVoidDescription,
T.IsTaxApplied,
T.IsCreditApplied,
T.OrderBiometricSample,
T.ProcessingFee,
T.LastReminderSentDate,
T.IsSpecialRateApplied,
T.OrderSignature
from [transaction] T
LEFT JOIN [OrderType] TT on TT.OrderTypeId = T.OrderTypeId 
LEFT JOIN [Status] S on S.StatusId = T.StatusId
LEFT JOIN [User] U on U.UserId = T.CreatedByUser
WHERE TT.OrdertypeDesc = 'Layaway'
    AND S.OrderStatus = 'Layaway'

-- Use this to grab all active pawns
-- TT.OrdertypeDesc = 'Pawn' 
--     AND S.OrderStatus = 'Pawn'

-- Use this to grab all active Buys
-- TT.OrdertypeDesc = 'Buy'
-- AND S.OrderStatus = 'Bought'


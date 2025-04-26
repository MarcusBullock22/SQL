WITH CTE_ItemLevel
AS
(
	SELECT ItemTypeId
		 , CONVERT(NVARCHAR(500),ItemTypeName) [RecursiveDescription] 
	  FROM ItemType
	 WHERE ParentItemTypeId IS NULL
	 UNION ALL 
	SELECT IT.ItemTypeId
		 , CONVERT(NVARCHAR(500),IT.ItemTypeName + ' ' +  CIL.[RecursiveDescription])
	  FROM ItemType IT
	 INNER JOIN CTE_ItemLevel CIL
		ON CIL.ItemTypeId = IT.ParentItemTypeId
)

SELECT *
FROM CTE_ItemLevel
WHERE ItemTypeId = @InputVariable
-- CCG and Prov

SELECT [UniqMonthID]
      ,[ReportingPeriodEnd]
      ,[ProvName]
	  ,[OrgIDProv]
      ,[CCGName]
	  ,[OrgIDCCGRes]
      ,SUM([MeasureValue]) AS [Total accessed (first contact)]
  FROM [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_IPS_rebuild]
  WHERE MeasureName = 'TotalAccessed' -- Total accessed (first contact) on dashboard
  GROUP BY OrgIDProv, ProvName, OrgIDCCGRes, CCGName, UniqMonthID, ReportingPeriodEnd
  ORDER BY CCGName, ProvName, ReportingPeriodEnd

-- Just prov

SELECT [UniqMonthID]
      ,[ReportingPeriodEnd]
      ,[ProvName]
	  ,[OrgIDProv]
      ,SUM([MeasureValue]) AS [Total accessed (first contact)]
  FROM [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_IPS_rebuild]
  WHERE MeasureName = 'TotalAccessed' -- Total accessed (first contact) on dashboard
  GROUP BY OrgIDProv, ProvName, UniqMonthID, ReportingPeriodEnd
  ORDER BY ProvName, ReportingPeriodEnd

-- Just CCG

SELECT [UniqMonthID]
      ,[ReportingPeriodEnd]
      ,[CCGName]
	  ,[OrgIDCCGRes]
      ,SUM([MeasureValue]) AS [Total accessed (first contact)]
  FROM [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_IPS_rebuild]
  WHERE MeasureName = 'TotalAccessed' -- Total accessed (first contact) on dashboard
  GROUP BY OrgIDCCGRes, CCGName, UniqMonthID, ReportingPeriodEnd
  ORDER BY CCGName, ReportingPeriodEnd

----- Code to pull figures for 72 Hour Follow Up and OAPs measures from the published data

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_PublishedDataFollowUp') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_PublishedDataFollowUp

SELECT s.[REPORTING_PERIOD_START] AS [ReportingPeriodStartDate]
      ,s.[REPORTING_PERIOD_END] AS [ReportingPeriodEndDate]
      ,s.[STATUS] -- kept for checking
      ,s.[BREAKDOWN] -- kept for checking
      ,s.[SECONDARY_LEVEL] AS [Provider code]
      ,p.Organisation_Name AS [Provider name]
      ,s.[PRIMARY_LEVEL] -- kept for checking
	  ,CASE WHEN s.PRIMARY_LEVEL = 'UNKNOWN' THEN 'Missing/Invalid' ELSE COALESCE(cc.New_Code, s.PRIMARY_LEVEL) END AS [subICB code]
	  ,CASE WHEN s.PRIMARY_LEVEL = 'UNKNOWN' THEN 'Missing/Invalid' ELSE c.Organisation_Name END AS [subICB name]
	  ,CASE WHEN s.PRIMARY_LEVEL = 'UNKNOWN' THEN 'Missing/Invalid' ELSE c.STP_Code END AS [ICB code]
	  ,CASE WHEN s.PRIMARY_LEVEL = 'UNKNOWN' THEN 'Missing/Invalid' ELSE c.STP_Name END AS [ICB Name]
	  ,CASE WHEN s.PRIMARY_LEVEL = 'UNKNOWN' THEN 'Missing/Invalid' ELSE c.Region_Code END AS [Region code]
	  ,CASE WHEN s.PRIMARY_LEVEL = 'UNKNOWN' THEN 'Missing/Invalid' ELSE c.Region_Name END AS [Region Name]
      ,s.[MEASURE_ID]
      ,s.[MEASURE_VALUE]
INTO MHDInternal.Temp_AcuteDash_PublishedDataFollowUp
FROM [MHDInternal].[STAGING_MH_UnsuppressedMHSDSPublicationFiles] s
LEFT JOIN Reporting_UKHD_ODS.Provider_Hierarchies p ON s.SECONDARY_LEVEL = p.Organisation_Code
LEFT JOIN Internal_Reference.ComCodeChanges cc ON s.PRIMARY_LEVEL = cc.Org_Code
LEFT JOIN Reporting_UKHD_ODS.Commissioner_Hierarchies c ON COALESCE(cc.New_Code, s.PRIMARY_LEVEL) = c.Organisation_Code
WHERE s.[MEASURE_ID] IN ('MHS78', 'MHS79') AND s.BREAKDOWN IN ('Sub ICB - GP Practice or Residence; Provider of Responsibility', 'CCG - GP Practice or Residence; Provider of Responsibility')

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_PublishedDataFollowUpAggs') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_PublishedDataFollowUpAggs

SELECT [ReportingPeriodStartDate]
	  ,[ReportingPeriodEndDate] 
	  ,[Provider code]
	  ,[Provider name] 
	  ,[subICB code]
	  ,[subICB name] 
	  ,[ICB code]
	  ,[ICB Name] 
	  ,[Region code]
	  ,[Region Name] 
	  ,'-' AS OrganisationType
	  ,'-' AS OrganisationName
	  ,'-' AS Breakdown
	  ,'-' AS BreakdownDescription
	  ,'72_Hour_Follow_Up' AS MeasureName
	  ,SUM(CASE WHEN [MEASURE_ID] = 'MHS79' THEN [MEASURE_VALUE] ELSE Null END) AS MeasureValue  
	  ,SUM(CASE WHEN [MEASURE_ID] = 'MHS78' THEN [MEASURE_VALUE] ELSE Null END) AS Denominator
	  ,Null AS MeasureProportion
INTO MHDInternal.Temp_AcuteDash_PublishedDataFollowUpAggs
FROM MHDInternal.Temp_AcuteDash_PublishedDataFollowUp
GROUP BY [ReportingPeriodStartDate], [ReportingPeriodEndDate], [Provider code], [Provider name], 
[subICB code], [subICB name], [ICB code], [ICB Name], [Region code], [Region Name]

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_PublishedDataOAPsValues') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_PublishedDataOAPsValues

SELECT s.REPORTING_PERIOD_START 
	  ,s.REPORTING_PERIOD_END
	  ,s.MEASURE_ID
	  ,s.BREAKDOWN
	  ,s.PRIMARY_LEVEL
	  ,s.SECONDARY_LEVEL
	  ,s.PRIMARY_LEVEL_DESCRIPTION
	  ,s.SECONDARY_LEVEL_DESCRIPTION
	  ,s.MEASURE_VALUE
INTO MHDInternal.Temp_AcuteDash_PublishedDataOAPsValues
FROM [MHDInternal].[STAGING_MH_UnsuppressedMHSDSPublicationFiles] s
WHERE s.MEASURE_ID IN ('OAP01a', 'OAP02a', 'OAP03a', 'OAP04a') AND DATEDIFF(M, s.REPORTING_PERIOD_START, s.REPORTING_PERIOD_END) = 0 AND s.BREAKDOWN != 'Receiving Provider'

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_PublishedDataOAPsProportions') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_PublishedDataOAPsProportions

SELECT s.REPORTING_PERIOD_START 
	  ,s.REPORTING_PERIOD_END
	  ,CASE WHEN MEASURE_ID = 'OAP08a' THEN 'OAP01a'
			WHEN MEASURE_ID = 'OAP09a' THEN 'OAP02a'
			WHEN MEASURE_ID = 'OAP10a' THEN 'OAP03a'
			WHEN MEASURE_ID = 'OAP11a' THEN 'OAP04a'
			ELSE Null END AS MEASURE_ID_link
	  ,s.BREAKDOWN
	  ,s.PRIMARY_LEVEL
	  ,s.SECONDARY_LEVEL
	  ,s.PRIMARY_LEVEL_DESCRIPTION
	  ,s.SECONDARY_LEVEL_DESCRIPTION
	  ,s.MEASURE_VALUE AS MEASURE_PROPORTION
INTO MHDInternal.Temp_AcuteDash_PublishedDataOAPsProportions
FROM [MHDInternal].[STAGING_MH_UnsuppressedMHSDSPublicationFiles] s
WHERE s.MEASURE_ID IN ('OAP08a', 'OAP09a', 'OAP10a', 'OAP11a') AND DATEDIFF(M, s.REPORTING_PERIOD_START, s.REPORTING_PERIOD_END) = 0 AND s.BREAKDOWN != 'Receiving Provider'

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_PublishedDataOAPsJoin') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_PublishedDataOAPsJoin

SELECT s.* 
	  ,x.MEASURE_PROPORTION
INTO MHDInternal.Temp_AcuteDash_PublishedDataOAPsJoin
FROM MHDInternal.Temp_AcuteDash_PublishedDataOAPsValues s
LEFT JOIN MHDInternal.Temp_AcuteDash_PublishedDataOAPsProportions x ON x.REPORTING_PERIOD_END = s.REPORTING_PERIOD_END
AND x.MEASURE_ID_link = s.MEASURE_ID
AND x.BREAKDOWN = s.BREAKDOWN
AND x.PRIMARY_LEVEL = s.PRIMARY_LEVEL
AND x.SECONDARY_LEVEL = s.SECONDARY_LEVEL

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_PublishedDataOAPs') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_PublishedDataOAPs

SELECT s.[REPORTING_PERIOD_START] AS [ReportingPeriodStartDate]
	  ,s.[REPORTING_PERIOD_END] AS [ReportingPeriodEndDate]
	  ,s.[BREAKDOWN] AS BreakdownOld -- kept for checking and joining
	  ,CASE WHEN BREAKDOWN IN ('Age Group', 'Bed Type', 'Ethnicity', 'Gender', 'IMD', 'Primary reason for referral', 
							   'England', 'England; Age Band', 'England; Bed Type', 'England; Ethnicity', 'England; Gender', 'England; IMD Decile', 'England; Primary reason for referral', 'England; Upper Ethnicity') THEN 'England'
			WHEN BREAKDOWN IN ('Region', 'Commissioning Region', 'Commissioning Region; Age Band', 'Region; Age Group', 'Commissioning Region; Bed Type', 'Region; Bed Type', 
							   'Commissioning Region; Ethnicity', 'Region; Ethnicity', 'Commissioning Region; Gender', 'Region; Gender', 'Commissioning Region; IMD Decile', 'Region; IMD',
							   'Commissioning Region; Primary reason for referral', 'Region; Primary reason for referral', 'Commissioning Region; Receiving Provider', 'Region; Receiving Provider',
							   'Commissioning Region; Upper Ethnicity') THEN 'Region'
			WHEN BREAKDOWN IN ('ICB', 'ICB of GP Practice or Residence') THEN 'ICB'
			WHEN BREAKDOWN IN ('Sub ICB Location - GP Practice or Residence', 'Sub ICB of GP Practice or Residence') THEN 'Sub ICB'
			WHEN BREAKDOWN IN ('Sending Provider', 'Sending Provider; Receiving Provider') THEN 'Sending Provider'							
			ELSE 'None' END AS OrganisationType
	  ,CASE WHEN BREAKDOWN IN ('Age Group', 'Bed Type', 'Ethnicity', 'Gender', 'IMD', 'Primary reason for referral', 
							   'England', 'England; Age Band', 'England; Bed Type', 'England; Ethnicity', 'England; Gender', 'England; IMD Decile', 'England; Primary reason for referral', 'England; Upper Ethnicity') THEN 'England'
	        ELSE s.PRIMARY_LEVEL_DESCRIPTION END AS OrganisationName
	  ,CASE WHEN BREAKDOWN IN ('England', 'Region', 'Commissioning Region', 'ICB', 'ICB of GP Practice or Residence', 'Sub ICB Location - GP Practice or Residence', 'Sub ICB of GP Practice or Residence', 'Sending Provider') THEN 'None'
	        WHEN BREAKDOWN IN ('Age Group', 'England; Age Band', 'Commissioning Region; Age Band', 'Region; Age Group') THEN 'Age Group'
	        WHEN BREAKDOWN IN ('Bed Type', 'England; Bed Type', 'Commissioning Region; Bed Type', 'Region; Bed Type') THEN 'Bed Type'
	        WHEN BREAKDOWN IN ('Ethnicity', 'England; Ethnicity', 'Commissioning Region; Ethnicity', 'Region; Ethnicity') THEN 'Ethnicity'
	        WHEN BREAKDOWN IN ('Gender', 'England; Gender', 'Commissioning Region; Gender', 'Region; Gender') THEN 'Gender'
	        WHEN BREAKDOWN IN ('IMD', 'England; IMD Decile', 'Commissioning Region; IMD Decile', 'Region; IMD') THEN 'IMD Decile'
	        WHEN BREAKDOWN IN ('Primary reason for referral', 'England; Primary reason for referral', 'Commissioning Region; Primary reason for referral', 'Region; Primary reason for referral') THEN 'Primary reason for referral'
	        WHEN BREAKDOWN IN ('Commissioning Region; Receiving Provider', 'Region; Receiving Provider', 'Sending Provider; Receiving Provider') THEN 'Receiving Provider'
	        WHEN BREAKDOWN IN ('England; Upper Ethnicity', 'Commissioning Region; Upper Ethnicity') THEN 'Upper Ethnicity'
	        ELSE 'None' END AS Breakdown
 	  ,CASE WHEN BREAKDOWN IN ('England', 'Region', 'Commissioning Region', 'ICB', 'ICB of GP Practice or Residence', 'Sub ICB Location - GP Practice or Residence', 'Sub ICB of GP Practice or Residence', 
	 						   'Sending Provider') THEN 'None'
	  	    WHEN BREAKDOWN IN ('Age Group', 'Bed Type', 'Ethnicity', 'Gender', 'IMD', 'Primary reason for referral', 'England; Age Band', 'England; Bed Type', 'England; Ethnicity', 'England; Gender', 'England; IMD Decile', 
							   'England; Primary reason for referral', 'England; Upper Ethnicity') THEN s.PRIMARY_LEVEL_DESCRIPTION
 		    WHEN BREAKDOWN IN ('Commissioning Region; Age Band', 'Region; Age Group', 'Commissioning Region; Bed Type', 'Region; Bed Type', 'Commissioning Region; Ethnicity', 'Region; Ethnicity', 'Commissioning Region; Gender', 
							   'Region; Gender', 'Commissioning Region; IMD Decile', 'Region; IMD', 'Commissioning Region; Primary reason for referral', 'Region; Primary reason for referral', 'Commissioning Region; Receiving Provider', 
							   'Region; Receiving Provider', 'Sending Provider; Receiving Provider', 'Commissioning Region; Upper Ethnicity') THEN s.SECONDARY_LEVEL_DESCRIPTION
	        ELSE 'None' END AS BreakdownDescription
	  ,s.MEASURE_ID
	  ,s.MEASURE_VALUE
	  ,s.MEASURE_PROPORTION
INTO MHDInternal.Temp_AcuteDash_PublishedDataOAPs
FROM MHDInternal.Temp_AcuteDash_PublishedDataOAPsJoin s

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_PublishedDataOAPsAggs') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_PublishedDataOAPsAggs

SELECT [ReportingPeriodStartDate] 
      ,[ReportingPeriodEndDate]
      ,'-' AS [Provider code]
      ,'-' AS [Provider name]
      ,'-' AS [subICB code]
      ,'-' AS [subICB name] 
      ,'-' AS [ICB code]
      ,'-' AS [ICB Name] 
      ,'-' AS [Region code]
      ,'-' AS [Region Name]  
      ,OrganisationType
      ,OrganisationName 
      ,Breakdown
      ,CASE WHEN BreakdownDescription = 'UNKNOWN' THEN 'Missing/Invalid' 
			WHEN BreakdownDescription = '65 plus' THEN '65 or over' 
		    ELSE BreakdownDescription END AS BreakdownDescription
      ,'OAPs in Adult Acute Beds - Starting' AS MeasureName
      ,SUM(CASE WHEN [MEASURE_ID] = 'OAP01a' THEN [MEASURE_VALUE] ELSE Null END) AS MeasureValue
	  ,Null AS Denominator
      ,SUM(CASE WHEN [MEASURE_ID] = 'OAP01a' THEN [MEASURE_PROPORTION] ELSE Null END) AS MeasureProportion
INTO MHDInternal.Temp_AcuteDash_PublishedDataOAPsAggs
FROM MHDInternal.Temp_AcuteDash_PublishedDataOAPs
GROUP BY [ReportingPeriodStartDate], [ReportingPeriodEndDate], OrganisationType,
OrganisationName, Breakdown, BreakdownDescription

UNION ALL

SELECT [ReportingPeriodStartDate] 
      ,[ReportingPeriodEndDate]
      ,'-' AS [Provider code]
      ,'-' AS [Provider name] 
      ,'-' AS [subICB code]
      ,'-' AS [subICB name] 
      ,'-' AS [ICB code]
      ,'-' AS [ICB Name] 
      ,'-' AS [Region code]
      ,'-' AS [Region Name] 
      ,OrganisationType
      ,OrganisationName 
      ,Breakdown
      ,CASE WHEN BreakdownDescription = 'UNKNOWN' THEN 'Missing/Invalid' 
			WHEN BreakdownDescription = '65 plus' THEN '65 or over' 
		    ELSE BreakdownDescription END AS BreakdownDescription
      ,'OAPs in Adult Acute Beds - Bed Days' AS MeasureName
      ,SUM(CASE WHEN [MEASURE_ID] = 'OAP02a' THEN [MEASURE_VALUE] ELSE Null END) AS MeasureValue
	  ,Null AS Denominator
      ,SUM(CASE WHEN [MEASURE_ID] = 'OAP02a' THEN [MEASURE_PROPORTION] ELSE Null END) AS MeasureProportion
FROM MHDInternal.Temp_AcuteDash_PublishedDataOAPs
GROUP BY [ReportingPeriodStartDate], [ReportingPeriodEndDate], OrganisationType,
OrganisationName, Breakdown, BreakdownDescription

UNION ALL

SELECT [ReportingPeriodStartDate] 
      ,[ReportingPeriodEndDate]
      ,'-' AS [Provider code]
      ,'-' AS [Provider name] 
      ,'-' AS [subICB code]
      ,'-' AS [subICB name] 
      ,'-' AS [ICB code]
      ,'-' AS [ICB Name] 
      ,'-' AS [Region code]
      ,'-' AS [Region Name] 
      ,OrganisationType
      ,OrganisationName 
      ,Breakdown
      ,CASE WHEN BreakdownDescription = 'UNKNOWN' THEN 'Missing/Invalid' 
			WHEN BreakdownDescription = '65 plus' THEN '65 or over' 
		    ELSE BreakdownDescription END AS BreakdownDescription
      ,'OAPs in Adult Acute Beds - Active At Period End' AS MeasureName
      ,SUM(CASE WHEN [MEASURE_ID] = 'OAP03a' THEN [MEASURE_VALUE] ELSE Null END) AS MeasureValue
	  ,Null AS Denominator
      ,SUM(CASE WHEN [MEASURE_ID] = 'OAP03a' THEN [MEASURE_PROPORTION] ELSE Null END) AS MeasureProportion
FROM MHDInternal.Temp_AcuteDash_PublishedDataOAPs
GROUP BY [ReportingPeriodStartDate], [ReportingPeriodEndDate], OrganisationType,
OrganisationName, Breakdown, BreakdownDescription

UNION ALL

SELECT [ReportingPeriodStartDate] 
      ,[ReportingPeriodEndDate]
      ,'-' AS [Provider code]
      ,'-' AS [Provider name] 
      ,'-' AS [subICB code]
      ,'-' AS [subICB name] 
      ,'-' AS [ICB code]
      ,'-' AS [ICB Name] 
      ,'-' AS [Region code]
      ,'-' AS [Region Name] 
      ,OrganisationType
      ,OrganisationName 
      ,Breakdown
      ,CASE WHEN BreakdownDescription = 'UNKNOWN' THEN 'Missing/Invalid' 
			WHEN BreakdownDescription = '65 plus' THEN '65 or over' 
		    ELSE BreakdownDescription END AS BreakdownDescription
      ,'OAPs in Adult Acute Beds - Ending' AS MeasureName
      ,SUM(CASE WHEN [MEASURE_ID] = 'OAP04a' THEN [MEASURE_VALUE] ELSE Null END) AS MeasureValue
	  ,Null AS Denominator
      ,SUM(CASE WHEN [MEASURE_ID] = 'OAP04a' THEN [MEASURE_PROPORTION] ELSE Null END) AS MeasureProportion
FROM MHDInternal.Temp_AcuteDash_PublishedDataOAPs
GROUP BY [ReportingPeriodStartDate], [ReportingPeriodEndDate], OrganisationType,
OrganisationName, Breakdown, BreakdownDescription

IF OBJECT_ID ('MHDInternal.Dashboard_MH_InpatientDashboard_PublishedData') IS NOT NULL
DROP TABLE MHDInternal.Dashboard_MH_InpatientDashboard_PublishedData

SELECT * 
INTO MHDInternal.Dashboard_MH_InpatientDashboard_PublishedData
FROM MHDInternal.Temp_AcuteDash_PublishedDataOAPsAggs

UNION ALL 
SELECT * 
FROM MHDInternal.Temp_AcuteDash_PublishedDataFollowUpAggs

DROP TABLE MHDInternal.Temp_AcuteDash_PublishedDataOAPsAggs
DROP TABLE MHDInternal.Temp_AcuteDash_PublishedDataOAPs
DROP TABLE MHDInternal.Temp_AcuteDash_PublishedDataFollowUpAggs
DROP TABLE MHDInternal.Temp_AcuteDash_PublishedDataFollowUp

/* 
-- NOT NEEDED IF JUST USING MONTHLY DATA AS ONE ROW / STATUS PER MONTH PER BREAKDOWN

SELECT 
REPORTING_PERIOD_START,
CASE WHEN SUM(CASE WHEN STATUS = 'Final' THEN 1 ELSE 0 END) > 0 THEN 'Final' ELSE 'Performance' END AS STATUS2
INTO #OAPSDataCut
FROM [MHDInternal].[STAGING_MH_UnsuppressedMHSDSPublicationFiles]
WHERE [MEASURE_ID] IN ('OAP01a') --, 'OAP02a', 'OAP3a', 'OAP4a') -- AND BREAKDOWN IN ('Sub ICB - GP Practice or Residence; Provider of Responsibility', 'CCG - GP Practice or Residence; Provider of Responsibility')
GROUP BY REPORTING_PERIOD_START
ORDER BY [REPORTING_PERIOD_START] ASC
*/

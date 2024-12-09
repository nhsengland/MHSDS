/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CODE FOR CORE DATA PACK (CDP)

Check latest available data before running code 
on CDP dashboard tables

CREATED BY Kirsty Walker 12/05/23
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

SELECT 
	   'STAGING_CDP_A_ECDS' as Script_Name,
	   EOMONTH(DATEADD(MONTH,-1,MAX(monthyear))) as Latest_Date --we minus a month because the dashboard includes provisional data (that they like to call "primary")

  INTO MHDInternal.[CDP_LATESTDATACHECKS]

  FROM MHDInternal.[Dashboard_UEC_ECDS]

UNION

SELECT 
	   'STAGING_CDP_B_NHS_Talking_Therapies_Monthly' as Script_Name,
	   EOMONTH(DATEADD(MONTH,0,MAX([ReportingPeriodEndDate]))) as Latest_Date --we minus a month because the collection includes provisional data which we don't report on in CDP
  FROM [mesh_IAPT].[IDS000header]


UNION
--Dementia Data requires a second update after the first core data pack refresh as the data is released late.
SELECT 
	   'STAGING_CDP_D_Dementia' as Script_Name,
	   MAX(Effective_Snapshot_Date) as Latest_Date
  FROM [UKHF_Primary_Care_Dementia].[Diag_Rate_By_NHS_Org_65Plus1]

UNION

SELECT 
	   'STAGING_CDP_I_IPS' as Script_Name,
	   EOMONTH(DATEADD(MONTH, 0,MAX(ReportingPeriodEnd))) as Latest_Date --we minus a month because the dashboard includes provisional data (that they like to call "primary")
  FROM [MHDInternal].[Dashboard_IPS_rebuild]

UNION

SELECT 
	   'STAGING_CDP_M_MHSDS_Published' as Script_Name,
	   MAX(REPORTING_PERIOD_END) as Latest_Date
  FROM [MHDInternal].[STAGING_MH_UnsuppressedMHSDSPublicationFiles]

UNION

SELECT 
	   'STAGING_CDP_N_Inpatient_No_Contact' as Script_Name, -- For white and BME patient level, main indicator in unsuppressed MHSDS table
	   MAX(ReportingPeriodEndDate)
  FROM [MHDInternal].[PreProc_Header]

UNION

SELECT 
	   'STAGING_CDP_O_OAPs' as Script_Name,
	   MAX(Publication_Period_End) as Latest_Date
  FROM [MHDInternal].[Dashboard_MH_Perinatal_Access]

UNION

SELECT 
	   'STAGING_CDP_P_Perinatal' as Script_Name, -- Access YTD, Rolling 12 month in unsuppressed MHSDS table
	   EOMONTH(DATEADD(MONTH, 0,MAX(ReportingPeriodEndDate))) as Latest_Date --we minus a month because the dashboard includes provisional data (that they like to call "primary")
  FROM [MHDInternal].[Dashboard_MH_Perinatal_Access]
 WHERE MeasureName = 'YTD Access'

UNION

SELECT 
	   'STAGING_CDP_Q_Data_Quality' as Script_Name,
	   MAX(ReportingPeriodEndDate)
  FROM MHDInternal.[STAGING_Data_Quality_Master_Table]

UNION 

SELECT 
	   'STAGING_CDP_T_CMH' as Script_Name, --CYP in unsuppressed MHSDS table
	   EOMONTH(DATEADD(MONTH, 0, MAX(ReportingPeriodEndDate))) as Latest_Date --we minus a month because the dashboard includes provisional data (that they like to call "primary")
  FROM [MHDInternal].[Dashboard_MH_CMHWaitsAccess]
 WHERE Der_AccessType = 'Second - PCN rolling'

UNION
--Quarterly - Updates in FEB, MAY, AUG & NOV
SELECT 
	   'STAGING_CDP_S_PH_SMI' as Script_Name,
	   MAX(Effective_Snapshot_Date) as Latest_Date
  FROM [UKHF_Physical_Health_Checks_Severe_Mental_Illness].[Data1]

UNION
--Quarterly - Updates in MAR, JUN, SEP & DEC
SELECT
	   'STAGING_CDP_F_NHS_Talking_Therapies_Quarterly' as Script_Name, -- updates quarterly in March, June, September, December
	   MAX(Effective_Snapshot_Date) as Latest_Date
  FROM [UKHF_IAPT].[Activity_Data_Qtr1]
  
UNION
--Annually - Updates usually at start of new FY.
SELECT 
	   'STAGING_CDP_E_EIP' as Script_Name, --updates annually from manual table load
	   MAX(Month) as Latest_Date
  FROM [MHDInternal].[Reference_EIPLevelsManual]

----------------------------- RETIRED ---------------------------------------
--UNION
--SELECT
--	   'STAGING_CDP_C_CYP_ED_Prov' as Script_Name,
--	   MAX(Effective_Snapshot_Date) as Latest_Date 
--  FROM [NHSE_UKHF].[Mental_Health].[vw_CYP_With_Eating_Disorder_Waiting_Times_Prov1] 

--UNION

--SELECT
--	   'STAGING_CDP_C_CYP_ED_SubICB' as Script_Name,
--	   MAX(Effective_Snapshot_Date) as Latest_Date
--  FROM [NHSE_UKHF].[Mental_Health].[vw_CYP_With_Eating_Disorder_Waiting_Times_Comm1]

--UNION

--SELECT
--	   'STAGING_CDP_C_CYP_ED_ICB' as Script_Name,
--	   MAX(Effective_Snapshot_Date) as Latest_Date 
--  FROM [NHSE_UKHF].[Mental_Health].[vw_CYP_With_Eating_Disorder_Waiting_Times_STP1]

--UNION

--SELECT
--	   'STAGING_CDP_C_CYP_ED_Region' as Script_Name,
--	   MAX(Effective_Snapshot_Date) as Latest_Date 
--  FROM [NHSE_UKHF].[Mental_Health].[vw_CYP_With_Eating_Disorder_Waiting_Times_Region1]

--UNION

--SELECT 
--	   'STAGING_CDP_Dementia_Historic' as Script_Name, --don't need data past Sep-22 as we moved to the new collection
--	   MAX(Effective_Snapshot_Date) as Latest_Date
--  FROM [NHSE_UKHF].[Rec_Dementia_Diag].[vw_Diag_Rate_By_NHS_Org_65Plus1]

--UNION

--SELECT 
--	   'STAGING_CDP_Length_of_Stay_Historic' as Script_Name, -- don't need data past Jul-21 as we moved to the publish metric
--	   MAX(ReportingPeriodEndDate)
--  FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header]
-- WHERE ReportingPeriodEndDate<='2021-07-31'

--- OUTPUT ----
SELECT *
  FROM MHDInternal.[CDP_LATESTDATACHECKS]

--DROP TABLES
DROP TABLE MHDInternal.[CDP_LATESTDATACHECKS]

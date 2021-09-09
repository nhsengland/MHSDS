/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PERINATAL DASHBOARD V8.2 (INCLUDES ACCESS CALCULATION STEP)

V1 - CREATED BY CARL MONEY 12/11/19

V2 AMENDED BY LOUISE SHUTTLEWORTH 24/01/20 - CHANGED TO ROLLING EXTRACT AND ADDED IN CASELOAD MEASURES - 
	V2.1 - ADDED MISSING AGE GROUP
V3 - ADDED IN CCG/STP AMBITIONS AND DQ FLAGS 

V4 10/06/20 - ADDED IN CODE TO BRING THROUGH THE ONS 2016 BIRTHS AND CALCULATE ACCESS RATES AND TARGET BIRTHS

V5 09/07/20 - AMENDED VARIABLES TO INCLUDE PRIMARY DATA IN EXTRACT

V6 09/09/20 - ADDED IN REFERRAL SOURCES FOR CASELOAD AND NEW REFERRALS
	V6.1 07/10/20 - ADDED IN BOTH REFERRAL SOURCE %S AND NUMBERS TO FINAL EXTRACT. AMENDED CASELOAD DEFINITION TO COUNT WHERE SERVICE DISCHARGE DATE IS NULL.

V7 23/10/20 - UPDATED TO QUERY FROM NHSE_MHSDS TABLES. EXTRACTS MSWM DATA FOR MONTHS IN 19/20, FROM MARCH 20 AND ONWARDS (INCLUDING 20/21 ROLLING 12 MONTH FIGURES). MONTHS IN 20/21 ARE KEPT AS PERFORMANCE CUT.

V8 01/05/21 - ADD IN PIVOT STEPS TO PRODUCE A FLAT OUTPUT FILE FOR TABLEAU

V8.1 05/07/21 - ADD IN Der_FY TO THE EXTRACT; RESTRUCTURE #Targets STEP; UPDATE TO QUERY FROM PRE_PROC TABLES 

V8.2 07/09/21 - REMOVED DUDLEY FROM PROVIDER FIGURES; REMOVED ICS BREAKDOWN FROM CODE
				THIS CODE CALCULATES ROLLING ACCESS IN THE #ROLLING STEP, RATHER THAN INCORPORATING NHSD ACCESS FIGURES. USE THIS CODE TO RE-RUN ACCESS FOR HISTORIC DATA PRIOR TO NHSD ACCESS DATA (PRE 21/22 DATA) 

ASSET: MHSDS DATA TABLES 

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--SET VARIABLE


--WAITFOR TIME '17:00'

DECLARE @EndRP INT
DECLARE @FYStart INT
DECLARE @LatestPerformanceSub INT
DECLARE @StartRP INT
DECLARE @RPEndDate DATETIME
DECLARE @RPEndDatePerformance DATETIME

SET @FYStart = 
(SELECT MAX(UniqMonthID)
FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header]
WHERE Der_FYStart = 'Y')

SET @EndRP = 
(SELECT UniqMonthID
FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header]
WHERE Der_MostRecentFlag = 'P')

SET @LatestPerformanceSub = 
(SELECT UniqMonthID
FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header]
WHERE Der_MostRecentFlag = 'Y')

SET @StartRP = 1428 --= @LatestPerformanceSub - 11

SET @RPEndDate = (SELECT ReportingPeriodEndDate
       FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header]
       WHERE UniqMonthID = @EndRP)

SET @RPEndDatePerformance = (SELECT ReportingPeriodEndDate
       FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header]
       WHERE UniqMonthID = @LatestPerformanceSub)


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

CREATE DATA FOR PERINATAL MH DASHBOARD EXTRACT

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
IDENTIFY REFERRALS TO PERINATAL SERVICES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#refs') IS NOT NULL
DROP TABLE #refs

SELECT
	CASE 
		WHEN r.UniqMonthID = @EndRP THEN 'Primary'
		WHEN r.UniqMonthID = @LatestPerformanceSub THEN 'Performance'
		ELSE 'Previous months' END AS SubmissionType, 
	r.UniqMonthID,
	h.Der_FY,
	r.RecordNumber,
	r.Person_ID,
	r.UniqServReqID,
	r.OrgIDProv,
	CASE 
		WHEN r.OrgIDCCGRes = 'X98' THEN 'Missing / Invalid'
		ELSE COALESCE(cc.New_Code,r.OrgIDCCGRes,'Missing / Invalid') 
		END AS OrgIDCCGRes,
	COALESCE(c.STP_Code,'Missing / Invalid') AS STP_Code,	
	COALESCE(c.Region_Code,'Missing / Invalid') AS Region_Code,
	r.LSOA2011,
	d.IMD_Decile,
	r.EthnicCategory,
	CASE 
		WHEN e.Category IS NULL THEN  'Missing / invalid'
		WHEN e.Category = '' THEN 'Missing / invalid'
		ELSE CONCAT(e.[Category],' - ',e.[Main_Description_60_Chars])
	END AS Ethnicity,
	r.AgeServReferRecDate,
	r.UniqCareProfTeamID,
	r.ServDischDate,
	r.ReferralRequestReceivedDate,
	r.SourceOfReferralMH,
	CASE WHEN r.ServDischDate IS NULL THEN 1 ELSE 0 END AS Caseload,
	CASE WHEN r.ReferralRequestReceivedDate BETWEEN h.ReportingPeriodStartDate AND h.ReportingPeriodEndDate THEN 1 ELSE 0 END AS NewReferrals,
	CASE WHEN r.ServDischDate BETWEEN h.ReportingPeriodStartDate AND h.ReportingPeriodEndDate THEN 1 ELSE 0 END AS ClosedReferrals,
	h.ReportingPeriodStartDate,
	h.ReportingPeriodEndDate

INTO #Refs

FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Referral r

INNER JOIN [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header] h ON r.UniqMonthID = h.UniqMonthID
	AND r.UniqMonthID BETWEEN @StartRP AND @EndRP 
	AND r.Gender = '2' -- limit to Female patients only
	AND r.ServTeamTypeRefToMH = 'C02' -- limit to referrals to Community Perinatal MH Team type
	AND (r.LADistrictAuth IS NULL OR r.LADistrictAuth LIKE ('E%'))  -- limit to those people whose commissioner is an English organisation

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges] cc ON r.OrgIDCCGRes = cc.Org_Code

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Commissioner_Hierarchies c ON COALESCE(cc.New_Code,r.OrgIDCCGRes) = c.Organisation_Code

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_Deprivation_By_LSOA] AS d ON r.LSOA2011 = d.LSOA_Code AND d.Effective_Snapshot_Date  = '2019-12-31'  

LEFT JOIN [NHSE_UKHF].[Data_Dictionary].[vw_Ethnic_Category_Code_SCD] e ON r.EthnicCategory = e.[Main_Code_Text] COLLATE DATABASE_DEFAULT AND e.Is_Latest = 1


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ATTENDED, F2F/VC CARE CONTACTS WITH PERINATAL MH SERVICES OVER THE REPORTING PERIOD 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Conts') IS NOT NULL
DROP TABLE #Conts

SELECT
	   r.UniqMonthID,
       r.Person_ID,
       r.RecordNumber,
       r.OrgIDProv,
       r.OrgIDCCGRes,
       r.UniqServReqID,
       c.UniqCareContID,
	   c.Der_ContactDate,
       r.STP_Code,
       r.Region_Code

INTO #Conts

FROM #Refs r

INNER JOIN [NHSE_Sandbox_MentalHealth].dbo.PreProc_Activity c ON r.RecordNumber = c.RecordNumber 
       AND r.UniqServReqID = c.UniqServReqID 
       AND c.Der_FacetoFaceContactOrder IS NOT NULL -- to limit to attended, Face to Face or Videoconferencing Perinatal contacts only 
	   AND c.UniqMonthID BETWEEN @StartRP AND @EndRP



/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
IDENTIFYING FIRST ACTIVITY IN THE FINANCIAL YEAR, FOR EACH PID/REFERRAL IN EACH ORGANISATION
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#contYTD') IS NOT NULL
DROP TABLE #contYTD

SELECT
	   c.UniqMonthID,
       c.Person_ID,
       c.RecordNumber,
       c.OrgIDProv,
       c.OrgIDCCGRes,
       c.UniqServReqID,
       c.UniqCareContID,
       ROW_NUMBER () OVER(PARTITION BY c.Person_ID, c.OrgIDCCGRes ORDER BY c.UniqMonthID ASC, c.Der_ContactDate ASC, c.UniqCareContID ASC) AS 'FYAccessCCGRN', -- flags a woman's first contact of financial year at CCG level
       ROW_NUMBER () OVER(PARTITION BY c.Person_ID, c.OrgIDProv ORDER BY c.UniqMonthID ASC, c.Der_ContactDate ASC, c.UniqCareContID ASC) AS 'FYAccessRN', -- flags a woman's first contact of financial year at Provider level
       ROW_NUMBER () OVER(PARTITION BY c.Person_ID ORDER BY c.UniqMonthID ASC, c.Der_ContactDate ASC, c.UniqCareContID ASC) AS 'FYAccessEngRN', -- flags a woman's first contact of financial year at England level
       ROW_NUMBER () OVER(PARTITION BY c.Person_ID, c.STP_Code ORDER BY c.UniqMonthID ASC, c.Der_ContactDate ASC, c.UniqCareContID ASC) AS 'FYAccessSTPRN', -- flags a woman's first contact of financial year at STP level
       ROW_NUMBER () OVER(PARTITION BY c.Person_ID, c.Region_Code ORDER BY c.UniqMonthID ASC, c.Der_ContactDate ASC, c.UniqCareContID ASC) AS 'FYAccessRegionRN' -- flags a woman's first contact of financial year at Region level

INTO #ContYTD

FROM #Conts c

WHERE c.UniqMonthID BETWEEN @FYStart AND @EndRP -- to identify a woman's first attended, face to face contact with Perinatla services in this Financial year 



/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
LINK CONTACTS TO REFERRAL - ADD IN CASELOAD DEMOGRAPHIC AND REFERRAL SOURCE FLAGS 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Master') IS NOT NULL
DROP TABLE #Master

SELECT DISTINCT
		r.SubmissionType,
		r.UniqMonthID,
		r.Der_FY,
		r.Person_ID,
		r.UniqServReqID,
		r.OrgIDProv,
		r.OrgIDCCGRes,
		r.STP_Code,
		r.Region_Code,
		
		--Deprivation flag
		CASE WHEN r.ServDischDate IS NULL AND r.IMD_Decile IN (1,2) THEN 1 ELSE 0 END AS Caseload_IMDQuintile1,

		--Ethnicity flags
		CASE WHEN r.ServDischDate IS NULL AND r.Ethnicity IN ('White - British','White - Irish')THEN 1 ELSE 0 END AS Caseload_Ethnicity_WhiteBritishIrish,
		CASE WHEN r.ServDischDate IS NULL AND r.Ethnicity = 'White - Any other white background' THEN 1 ELSE 0 END AS Caseload_Ethnicity_OtherWhite,
		CASE WHEN r.ServDischDate IS NULL AND r.Ethnicity IN ('Mixed - White and Black Caribbean','Mixed - White and Black African','Mixed - White and Asian','Mixed - Any other mixed background') 
		THEN 1 ELSE 0 END AS Caseload_Ethnicity_Mixed,
		CASE WHEN r.ServDischDate IS NULL AND r.Ethnicity IN ('Asian or Asian British - Indian','Asian or Asian British - Pakistani','Asian or Asian British - Bangladeshi',
		'Asian or Asian British - Any other Asian background') THEN 1 ELSE 0 END AS Caseload_Ethnicity_AsianAsianBritish,
		CASE WHEN r.ServDischDate IS NULL AND r.Ethnicity IN ('Black or Black British - Caribbean','Black or Black British - African','Black or Black British - Any other Black background') THEN 1 ELSE 0 END AS Caseload_Ethnicity_BlackBlackBritish,
		CASE WHEN r.ServDischDate IS NULL AND r.Ethnicity IN ('Other ethnic groups - Chinese','Other ethnic groups - Any other ethnic group') THEN 1 ELSE 0 END AS Caseload_Ethnicity_OtherEthnicGroups,
		CASE WHEN r.ServDischDate IS NULL AND r.Ethnicity = 'Other ethnic groups - Not stated' THEN 1 ELSE 0 END AS Caseload_Ethnicity_EthnicityNotStated,
		CASE WHEN r.ServDischDate IS NULL AND r.Ethnicity = 'Missing / invalid' THEN 1 ELSE 0 END AS Caseload_Ethnicity_EthnicityMissingInvalid,

		--Age flags
		CASE WHEN r.ServDischDate IS NULL AND r.AgeServReferRecDate BETWEEN 16 AND 20 THEN 1 ELSE 0 END AS Caseload_Age_16to20,
		CASE WHEN r.ServDischDate IS NULL AND r.AgeServReferRecDate BETWEEN 21 AND 25 THEN 1 ELSE 0 END AS Caseload_Age_21to25,
		CASE WHEN r.ServDischDate IS NULL AND r.AgeServReferRecDate BETWEEN 26 AND 39 THEN 1 ELSE 0 END AS Caseload_Age_26to39,
		CASE WHEN r.ServDischDate IS NULL AND r.AgeServReferRecDate BETWEEN 40 AND 60 THEN 1 ELSE 0 END AS Caseload_Age_40Plus,

		--Open caseload referral source flags
		CASE WHEN r.ServDischDate IS NULL AND r.SourceOfReferralMH = 'A1' THEN 1 ELSE 0 END AS Caseload_Referral_GP,
		CASE WHEN r.ServDischDate IS NULL AND r.SourceOfReferralMH = 'A3' THEN 1 ELSE 0 END AS Caseload_Referral_OtherPrimaryCare,
		CASE WHEN r.ServDischDate IS NULL AND r.SourceOfReferralMH = 'A2' THEN 1 ELSE 0 END AS Caseload_Referral_PrimaryCareHealthVisitor,
		CASE WHEN r.ServDischDate IS NULL AND r.SourceOfReferralMH = 'A4' THEN 1 ELSE 0 END AS Caseload_Referral_PrimaryCareMaternityService,
		CASE WHEN r.ServDischDate IS NULL AND r.SourceOfReferralMH IN ('P1','H2') THEN 1 ELSE 0 END AS Caseload_Referral_SecondaryCare,
		CASE WHEN r.ServDischDate IS NULL AND r.SourceOfReferralMH IN ('B1','B2') THEN 1 ELSE 0 END AS Caseload_Referral_SelfReferral,
		CASE WHEN r.ServDischDate IS NULL AND r.SourceOfReferralMH IN ('D1','M6','I2','M7','H1','M3','N3','C1','G3','C2','E2','F3','I1','F1','E1','F2','G4','M2','M4','E3','E4','E5','G1','M1','C3','D2','E6','G2','M5')
			THEN 1 ELSE 0 END AS Caseload_Referral_OtherReferralSource,
		CASE WHEN r.ServDischDate IS NULL AND (r.SourceOfReferralMH NOT IN ('A1','A2','A3','A4','B1','B2','C1','C2','C3','D1','D2','E1','E2','E3','E4','E5','E6','F1','F2','F3','G1','G2','G3','G4','H1','H2','I1','I2','M1','M2','M3','M4','M5','M6','M7','N3','P1')
				OR r.SourceOfReferralMH IS NULL)
			THEN 1 ELSE 0 END AS Caseload_Referral_MissingInvalidReferralSource,

		--New referrals referral source flags
		CASE WHEN r.ReferralRequestReceivedDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate
			AND r.SourceOfReferralMH = 'A1' THEN 1 ELSE 0 END AS New_Referral_GP,
		CASE WHEN r.ReferralRequestReceivedDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate
			AND r.SourceOfReferralMH = 'A3' THEN 1 ELSE 0 END AS New_Referral_OtherPrimaryCare,
		CASE WHEN r.ReferralRequestReceivedDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate
			AND r.SourceOfReferralMH = 'A2' THEN 1 ELSE 0 END AS New_Referral_PrimaryCareHealthVisitor,
		CASE WHEN r.ReferralRequestReceivedDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate
			AND r.SourceOfReferralMH = 'A4' THEN 1 ELSE 0 END AS New_Referral_PrimaryCareMaternityService,
		CASE WHEN r.ReferralRequestReceivedDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate
			AND r.SourceOfReferralMH IN ('P1','H2') THEN 1 ELSE 0 END AS New_Referral_SecondaryCare,
		CASE WHEN r.ReferralRequestReceivedDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate
			AND r.SourceOfReferralMH IN ('B1','B2') THEN 1 ELSE 0 END AS New_Referral_SelfReferral,
		CASE WHEN r.ReferralRequestReceivedDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate
			AND r.SourceOfReferralMH IN ('D1','M6','I2','M7','H1','M3','N3','C1','G3','C2','E2','F3','I1','F1','E1','F2','G4','M2','M4','E3','E4','E5','G1','M1','C3','D2','E6','G2','M5')
		THEN 1 ELSE 0 END AS New_Referral_OtherReferralSource,
		CASE WHEN r.ReferralRequestReceivedDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate
			AND (r.SourceOfReferralMH NOT IN ('A1','A2','A3','A4','B1','B2','C1','C2','C3','D1','D2','E1','E2','E3','E4','E5','E6','F1','F2','F3','G1','G2','G3','G4','H1','H2','I1','I2','M1','M2','M3','M4','M5','M6','M7','N3','P1')
				OR r.SourceOfReferralMH IS NULL)
			THEN 1 ELSE 0 END AS New_Referral_MissingInvalidReferralSource,
		
		r.Caseload,
		r.NewReferrals,
		r.ClosedReferrals,

		--Access flags
		CASE WHEN c1.Contacts >0 THEN 1 ELSE NULL END AS AttendedContact,
		CASE WHEN c2.FYAccessRN = 1 THEN 1 ELSE NULL END AS InMonthAccess,
		CASE WHEN c2.FYAccessCCGRN = 1 THEN 1 ELSE NULL END AS InMonthAccessCCG,
		CASE WHEN c2.FYAccessSTPRN = 1 THEN 1 ELSE NULL END AS InMonthAccessSTP,
		CASE WHEN c2.FYAccessRegionRN = 1 THEN 1 ELSE NULL END AS InMonthAccessReg,
		CASE WHEN c2.FYAccessEngRN = 1 THEN 1 ELSE NULL END AS InMonthAccessEng

INTO #master

FROM #Refs r

-- Bring through attended contacts in the reporting period
LEFT JOIN 
       (SELECT
			 c.UniqMonthID,
             c.RecordNumber,
             c.UniqServReqID,
             COUNT(c.UniqCareContID) AS Contacts
       FROM #Conts c
       GROUP BY c.UniqMonthID, c.RecordNumber, c.UniqServReqID) c1
             ON r.RecordNumber = c1.RecordNumber
             AND r.UniqServReqID = c1.UniqServReqID

-- Bring through attended contacts since the start of the financial year
LEFT JOIN #ContYTD c2 
       ON r.RecordNumber = c2.RecordNumber
       AND r.UniqServReqID = c2.UniqServReqID
       AND (c2.FYAccessRN = 1 OR c2.FYAccessCCGRN = 1)


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET DISTINCT LIST OF DATES 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#AllDates') IS NOT NULL
DROP TABLE #AllDates

SELECT DISTINCT
	m.SubmissionType,
	m.UniqMonthID,
	CAST (d.ReportingPeriodEndDate AS datetime) AS ReportingPeriodEndDate,
	d.Der_FY

INTO #AllDates

FROM #master m

LEFT JOIN [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header] AS d ON m.UniqMonthID = d.UniqMonthID


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET DISTINCT LIST OF PROVIDER AND COMMISSIONER COMBINATIONS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#AllOrgs') IS NOT NULL
DROP TABLE #AllOrgs

SELECT DISTINCT
	OrgIDProv,
	OrgIDCCGRes,
	STP_Code,
	Region_Code

INTO #AllOrgs

FROM #master


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
COMBINE LIST OF DATES AND ORGS TO MAKE SURE ALL MONTHS ARE REPORTED AGAINST - PADDING FOR BASE MASTER
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Base') IS NOT NULL
DROP TABLE #Base

SELECT
	d.SubmissionType,
	d.UniqMonthID,
	d.ReportingPeriodEndDate,
	d.Der_FY,
	o.OrgIDProv,
	o.OrgIDCCGRes,
	o.STP_Code,
	o.Region_Code

INTO #Base

FROM #AllDates d, #AllOrgs o


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ASSIGN A VALUE TO EACH MONTH IN PADDED BASE TABLE, FOR EACH PROVIDER/CCG COMBINATION
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#BaseMaster') IS NOT NULL
DROP TABLE #BaseMaster

SELECT DISTINCT
	b.SubmissionType,
	b.UniqMonthID,
	b.ReportingPeriodEndDate,
	b.Der_FY,
	b.OrgIDProv,
	p.Organisation_Name AS [Provider name],
	b.OrgIDCCGRes,
	COALESCE(h.Organisation_Name,'Missing / Invalid') AS [CCG name],
	b.STP_Code,
	COALESCE(h.STP_Name,'Missing / Invalid') AS [STP name],	
	b.Region_Code,
	COALESCE(h.Region_Name,'Missing / Invalid') AS [Region name],

	COALESCE(p.Region_Code,'Missing / Invalid') AS [Provider region code],
	COALESCE(p.Region_Name,'Missing / Invalid') AS [Provider region name],

	-- Access flags
	SUM(m.InMonthAccess) AS InMonthAccess,
	SUM(m.InMonthAccessCCG) AS InMonthAccessCCG,
	SUM(m.InMonthAccessSTP) AS InMonthAccessSTP,
	SUM(m.InMonthAccessReg) AS InMonthAccessReg,
	SUM(m.InMonthAccessEng) AS InMonthAccessEng,

	--Deprivation flag
	SUM(m.Caseload_IMDQuintile1) AS [Caseload in IMD Quintile 1],

	-- Ethnicity flags
	SUM(m.Caseload_Ethnicity_WhiteBritishIrish) AS [Caseload ethnicity- White British or Irish],
	SUM(m.Caseload_Ethnicity_OtherWhite) AS [Caseload ethnicity - Other White],
	SUM(m.Caseload_Ethnicity_Mixed) AS [Caseload ethnicity - Mixed],
	SUM(m.Caseload_Ethnicity_AsianAsianBritish) AS [Caseload ethnicity - Asian or Asian British],
	SUM(m.Caseload_Ethnicity_BlackBlackBritish) AS [Caseload ethnicity - Black or Black British],
	SUM(m.Caseload_Ethnicity_OtherEthnicGroups) AS [Caseload ethnicity - Other Ethnic Groups],
	SUM(m.Caseload_Ethnicity_EthnicityNotStated) AS [Caseload ethnicity - Not stated],
	SUM(m.Caseload_Ethnicity_EthnicityMissingInvalid) AS [Caseload ethnicity - Missing],

	-- Age flags
	SUM(m.Caseload_Age_16to20) AS [Caseload aged 16 to 20],
	SUM(m.Caseload_Age_21to25) AS [Caseload aged 21 to 25],
	SUM(m.Caseload_Age_26to39) AS [Caseload aged 26 to 39],
	SUM(m.Caseload_Age_40Plus) AS [Caseload aged 40 plus],

	-- Caseload flags
	SUM(m.Caseload) AS [Caseload total],
	SUM(m.Caseload) AS [Caseload total 2],	-- duplicate measures for denominator in tableau
	SUM(m.NewReferrals) AS [New referrals],
	SUM(m.NewReferrals) AS [New referrals 2], -- duplicate measures for denominator in tableau
	SUM(m.ClosedReferrals) AS [Closed referrals],

	-- Caseload referral source flags
	SUM(m.Caseload_Referral_GP) AS [Caseload referred from GP],
	SUM(m.Caseload_Referral_OtherPrimaryCare) AS [Caseload referred from Other primary care],
	SUM(m.Caseload_Referral_PrimaryCareHealthVisitor) AS [Caseload referred from Primary care health visitor],
	SUM(m.Caseload_Referral_PrimaryCareMaternityService) AS [Caseload referred from Primary care Maternity service],
	SUM(m.Caseload_Referral_SecondaryCare) AS [Caseload referred from Secondary care],
	SUM(m.Caseload_Referral_SelfReferral) AS [Caseload referred from Self referral],
	SUM(m.Caseload_Referral_OtherReferralSource) AS [Caseload referred from Other referral sources],
	SUM(m.Caseload_Referral_MissingInvalidReferralSource) AS [Caseload referred from Missing or Invalid sources],

	-- New referrals referral source flags
	SUM(m.New_Referral_GP) AS [New Referrals from GP],
	SUM(m.New_Referral_OtherPrimaryCare) AS [New Referrals from Other primary care],
	SUM(m.New_Referral_PrimaryCareHealthVisitor) AS [New Referrals from Primary care health visitor],
	SUM(m.New_Referral_PrimaryCareMaternityService) AS [New Referrals from Primary care Maternity service],
	SUM(m.New_Referral_SecondaryCare) AS [New Referrals from Secondary care],
	SUM(m.New_Referral_SelfReferral) AS [New Referrals from Self referral],
	SUM(m.New_Referral_OtherReferralSource) AS [New Referrals from Other referral sources],
	SUM(m.New_Referral_MissingInvalidReferralSource) AS [New Referrals from Missing or Invalid sources]

INTO #BaseMaster

FROM #Base b 

LEFT JOIN #master m ON b.OrgIDProv = m.OrgIDProv AND b.OrgIDCCGRes = m.OrgIDCCGRes AND b.UniqMonthID = m.UniqMonthID

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies p ON b.OrgIDProv = p.Organisation_Code

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges] cc ON b.OrgIDCCGRes = cc.Org_Code

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Commissioner_Hierarchies h ON COALESCE(cc.New_Code,b.OrgIDCCGRes) = h.Organisation_Code


GROUP BY 
	b.SubmissionType,
	b.ReportingPeriodEndDate,
	b.Der_FY,
	b.UniqMonthID,
	b.OrgIDProv,
	p.Organisation_Name,
	b.OrgIDCCGRes,
	COALESCE(h.Organisation_Name,'Missing / Invalid'),
	b.STP_Code,
	COALESCE(h.STP_Name,'Missing / Invalid'),
	b.Region_Code,
	COALESCE(h.Region_Name,'Missing / Invalid'),
	COALESCE(p.Region_Code,'Missing / Invalid'),
	COALESCE(p.Region_Name,'Missing / Invalid')


	
/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

MONTHLY CASELOAD ACTIVITY EXTRACT

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
UNPIVOT AND CREATE MONTHLY ACTIVITY EXTRACT
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Pivot_Monthly_Extract') IS NOT NULL
DROP TABLE #Pivot_Monthly_Extract

	SELECT
		GETDATE() AS ImportDate,
		ReportingPeriodEndDate,
		SubmissionType,
		UniqMonthID,
		Der_FY,
		OrgIDProv,
		[Provider name],		
		OrgIDCCGRes,
		[CCG name],
		STP_Code,
		[STP name],
		Region_Code,
		[Region name],
		[Provider region name],
		CASE 
			WHEN MeasureName = 'Caseload in IMD Quintile 1' THEN 'Caseload deprivation'
		
			WHEN MeasureName IN 
			('Caseload ethnicity- White British or Irish','Caseload ethnicity - Other White','Caseload ethnicity - Mixed',
			'Caseload ethnicity - Asian or Asian British','Caseload ethnicity - Black or Black British','Caseload ethnicity - Other Ethnic Groups',
			'Caseload ethnicity - Not stated','Caseload ethnicity - Missing') 
			THEN 'Ethnicity'
			
			WHEN MeasureName IN 
			('Caseload aged 16 to 20', 'Caseload aged 21 to 25','Caseload aged 26 to 39','Caseload aged 40 plus') 
			THEN 'Caseload age'
			
			WHEN MeasureName IN 
			('Caseload referred from GP','Caseload referred from Other primary care','Caseload referred from Primary care health visitor','Caseload referred from Primary care Maternity service',
			'Caseload referred from Secondary care','Caseload referred from Self referral','Caseload referred from Other referral sources','Caseload referred from Missing or Invalid sources') 
			THEN 'Caseload referral source'
			
			WHEN MeasureName IN 
			('New Referrals from GP','New Referrals from Other primary care','New Referrals from Primary care health visitor','New Referrals from Primary care Maternity service','New Referrals from Secondary care',
			'New Referrals from Self referral','New Referrals from Other referral sources','New Referrals from Missing or Invalid sources') 
			THEN 'New referrals referral source'

			ELSE MeasureName END AS Categories,

		MeasureName,
		MeasureValue,

		CASE 
			WHEN MeasureName IN 
			('Caseload ethnicity- White British or Irish','Caseload ethnicity - Other White','Caseload ethnicity - Mixed',
			'Caseload ethnicity - Asian or Asian British','Caseload ethnicity - Black or Black British', 'Caseload ethnicity - Other Ethnic Groups','Caseload ethnicity - Not stated','Caseload ethnicity - Missing',
			'Caseload aged 16 to 20', 'Caseload aged 21 to 25','Caseload aged 26 to 39','Caseload aged 40 plus',
			'Caseload referred from GP','Caseload referred from Other primary care','Caseload referred from Primary care health visitor','Caseload referred from Primary care Maternity service',
			'Caseload referred from Secondary care','Caseload referred from Self referral','Caseload referred from Other referral sources','Caseload referred from Missing or Invalid sources',
			'Caseload in IMD Quintile 1') 
			THEN [Caseload total 2]
		
			WHEN MeasureName IN 
			('New Referrals from GP','New Referrals from Other primary care','New Referrals from Primary care health visitor','New Referrals from Primary care Maternity service','New Referrals from Secondary care',
			'New Referrals from Self referral','New Referrals from Other referral sources','New Referrals from Missing or Invalid sources') 
			THEN [New referrals 2]
			END AS Denominator -- bring through denominator for each category

	INTO #Pivot_Monthly_Extract
	
	FROM #BaseMaster

	UNPIVOT (MeasureValue FOR MeasureName IN 
				([Caseload in IMD Quintile 1],
				[Caseload ethnicity- White British or Irish],
				[Caseload ethnicity - Other White],
				[Caseload ethnicity - Mixed],
				[Caseload ethnicity - Asian or Asian British],
				[Caseload ethnicity - Black or Black British],
				[Caseload ethnicity - Other Ethnic Groups],
				[Caseload ethnicity - Not stated],
				[Caseload ethnicity - Missing],
				[Caseload aged 16 to 20],
				[Caseload aged 21 to 25],
				[Caseload aged 26 to 39],
				[Caseload aged 40 plus],
				[Caseload total],
				[New referrals],
				[Closed referrals],
				[Caseload referred from GP],
				[Caseload referred from Other primary care],
				[Caseload referred from Primary care health visitor],
				[Caseload referred from Primary care Maternity service],
				[Caseload referred from Secondary care],
				[Caseload referred from Self referral],
				[Caseload referred from Other referral sources],
				[Caseload referred from Missing or Invalid sources],
				[New Referrals from GP],
				[New Referrals from Other primary care],
				[New Referrals from Primary care health visitor],
				[New Referrals from Primary care Maternity service],
				[New Referrals from Secondary care],
				[New Referrals from Self referral],
				[New Referrals from Other referral sources],
				[New Referrals from Missing or Invalid sources])) U

	WHERE UniqMonthID >= @FYStart 

 


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

ACCESS EXTRACT 

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CALCULATES MONTHLY YEAR TO DATE ACCESS AT PROVIDER TO ENGLAND LEVELS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#YTD') IS NOT NULL
DROP TABLE #YTD

---- Provider Year to Date access 
SELECT DISTINCT
	b.SubmissionType,
	b.ReportingPeriodEndDate,
	b.UniqMonthID,
	b.Der_FY,
	'Provider' AS OrganisationType,
	b.OrgIDProv AS OrganisationCode,
	b.[Provider name] AS OrganisationName,
	SUM(ISNULL(b.InMonthAccess,0)) OVER (PARTITION BY b.OrgIDProv ORDER BY b.UniqMonthID) AS [YTD Access],
	b.[Provider region name] AS [Geographic benchmarking group]
	 
INTO #YTD

FROM #BaseMaster AS b

WHERE b.UniqMonthID BETWEEN @FYStart and @EndRP


UNION ALL


----- CCG Year to Date access
SELECT DISTINCT
	b.SubmissionType,
	b.ReportingPeriodEndDate,
	b.UniqMonthID,
	b.Der_FY,
	'CCG' AS OrganisationType,
	b.OrgIDCCGRes AS OrganisationCode,
	b.[CCG name] AS OrganisationName,	
	SUM(ISNULL(b.InMonthAccessCCG,0)) OVER (PARTITION BY b.OrgIDCCGRes ORDER BY B.UniqMonthID) AS [YTD Access],
	b.[Region name] AS [Geographic benchmarking group]

FROM #BaseMaster AS b

WHERE b.UniqMonthID BETWEEN @FYStart and @EndRP


UNION ALL


----- STP Year to Date access
SELECT DISTINCT
	b.SubmissionType,
	b.ReportingPeriodEndDate,
	b.UniqMonthID,
	b.Der_FY,
	'STP' AS OrganisationType,
	b.STP_Code AS OrganisationCode,
	b.[STP name] AS OrganisationName,
    SUM(ISNULL(b.InMonthAccessSTP,0)) OVER (PARTITION BY b.STP_Code ORDER BY b.UniqMonthID) AS [YTD Access],
	b.[Region name] AS [Geographic benchmarking group]

FROM #BaseMaster AS b

LEFT JOIN NHSE_Reference.dbo.[tbl_Ref_ODS_Commissioner_Hierarchies] map ON b.OrgIDCCGRes = map.Organisation_Code

WHERE b.UniqMonthID BETWEEN @FYStart and @EndRP


UNION ALL


----- Region Year to Date access
SELECT DISTINCT
	b.SubmissionType,
	b.ReportingPeriodEndDate,
	b.UniqMonthID,
	b.Der_FY,
	'Region' AS OrganisationType,
	b.Region_Code AS OrganisationCode,
	b.[Region name] AS OrganisationName,
	SUM(ISNULL(b.InMonthAccessReg,0)) OVER (PARTITION BY b.Region_Code ORDER BY b.UniqMonthID) AS [YTD Access],
	'N/A' AS [Geographic benchmarking group]


FROM #BaseMaster AS b

WHERE b.UniqMonthID BETWEEN @FYStart and @EndRP


UNION ALL


----- England Year to Date access
SELECT DISTINCT
	m.SubmissionType,
	d.ReportingPeriodEndDate,
	m.UniqMonthID,
	m.Der_FY,
	'England' AS OrganisationType,
	'ENG' AS OrganisationCode,
	'ENGLAND' AS OrganisationName,
	SUM(ISNULL(m.InMonthAccessEng,0)) OVER (ORDER BY m.UniqMonthID) AS [YTD Access],
	'N/A' AS [Geographic benchmarking group]

FROM #Master m

LEFT JOIN [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header] AS d ON m.UniqMonthID = d.UniqMonthID

WHERE m.UniqMonthID BETWEEN @FYStart and @EndRP



/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
BRINGS THROUGH FYFV/LTP TARGETS MAPPED TO CURRENT ORGANISATIONAL BOUNDARIES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Targets') IS NOT NULL
DROP TABLE #Targets

-- CCG targets mapped to latest codes
SELECT DISTINCT	
	t.FYear,
	'CCG' AS OrganisationType,
	COALESCE(cc.New_Code,t.Organisation_Code) AS OrganisationCode,
	SUM([Target]) AS Targets

INTO #Targets

FROM [NHSE_Sandbox_MentalHealth].[dbo].[Staging_PerinatalTargets_Totals] t

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges] cc ON t.Organisation_Code = cc.Org_Code

WHERE t.Organisation_Type = 'CCG' 

GROUP BY t.FYear, t.Organisation_Type, COALESCE(cc.New_Code,t.Organisation_Code)


UNION ALL


-- STP targets mapped to latest codes
SELECT 
	t.FYear,
	'STP' AS OrganisationType,
	map.STP_Code AS Organisation_Code,
	SUM([Target]) AS Targets

FROM [NHSE_Sandbox_MentalHealth].[dbo].[Staging_PerinatalTargets_Totals] t
	 
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges] cc ON t.Organisation_Code = cc.Org_Code 

LEFT JOIN NHSE_Reference.dbo.[tbl_Ref_ODS_Commissioner_Hierarchies] map ON COALESCE(cc.New_Code,t.Organisation_Code) = map.Organisation_Code

GROUP BY t.FYear, t.Organisation_Type, map.STP_Code


UNION ALL


-- Region targets 
SELECT 
	t.FYear,
	'Region' AS OrganisationType,
	map.Region_Code AS Organisation_Code,
	SUM([Target]) AS Targets

FROM [NHSE_Sandbox_MentalHealth].[dbo].[Staging_PerinatalTargets_Totals] t
	 
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges] cc ON t.Organisation_Code = cc.Org_Code 

LEFT JOIN NHSE_Reference.dbo.[tbl_Ref_ODS_Commissioner_Hierarchies] map ON COALESCE(cc.New_Code,t.Organisation_Code) = map.Organisation_Code

GROUP BY t.FYear, t.Organisation_Type, map.Region_Code


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
DUPLICATE RECORDS ACROSS NEXT 11 MONTHS TO CALCULATE ROLIING 12 MONTH DATA - TO BE REMOVED ONCE FIGURE OUT ICS ISSUE! 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Rolling') IS NOT NULL
DROP TABLE #Rolling

SELECT
	   m.UniqMonthID + (ROW_NUMBER() OVER(PARTITION BY m.UniqServReqID, m.UniqMonthID ORDER BY m.UniqMonthID ASC) -1) AS Der_MonthID,
	   m.UniqMonthID,
       m.Person_ID,
       m.UniqServReqID,
       m.OrgIDCCGRes,
       m.OrgIDProv,
	   m.STP_Code,
       m.Region_Code,
       m.AttendedContact AS RollingAccess

INTO #Rolling

FROM #master m

CROSS JOIN MASTER..spt_values AS n WHERE n.type = 'p' AND n.number BETWEEN m.UniqMonthID AND m.UniqMonthID + 11


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CALCULATES ROLLING AND IN MONTH ACCESS TOTALS AT PROVIDER TO ENGLAND LEVELS, AND BRINGS THROUGH ONS 2016 BIRTHS FOR USE AS DENOMINATOR IN ACCESS RATE CALCULATION
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#AccessTotals') IS NOT NULL
DROP TABLE #AccessTotals

---- Provider level access, mapped to ONS E-codes for Tableau map
SELECT DISTINCT
	m.ReportingPeriodEndDate,
	m.SubmissionType,
	m.UniqMonthID,
	m.Der_FY,
	'Provider' AS OrganisationType,
	m.OrgIDProv AS OrganisationCode,
	m.[Provider name] AS OrganisationName,
	CASE 
		WHEN prov.Region_Code = 'Y56' THEN 'E40000003'
		WHEN prov.Region_Code = 'Y59' THEN 'E40000005'
		WHEN prov.Region_Code = 'Y58' THEN 'E40000006'
		WHEN prov.Region_Code = 'Y61' THEN 'E40000007'
		WHEN prov.Region_Code = 'Y60' THEN 'E40000008'
		WHEN prov.Region_Code = 'Y63' THEN 'E40000009'
		WHEN prov.Region_Code = 'Y62' THEN 'E40000010'
	END AS nhser19cd_Prov,
	ISNULL(m1.Access,0) AS Access,
	ISNULL(m2.InMonthAccess,0) AS InMonthAccess,
	NULL AS [Live births 2016],
	NULL AS [Live births 2016 2], --duplicate for denominator in tableau
	m.[Provider region name] AS [Geographic benchmarking group]

INTO #AccessTotals

FROM #BaseMaster m

----Rolling 12 month access counts
LEFT JOIN 
	(SELECT 
		Der_MonthID,
		OrgIDProv,
		COUNT(DISTINCT CASE WHEN m1.RollingAccess = 1 THEN m1.Person_ID END) AS Access,
		COUNT(DISTINCT m1.Person_ID) AS People	
	FROM #Rolling AS m1
	GROUP BY Der_MonthID, OrgIDProv) m1 
	ON m.OrgIDProv = m1.OrgIDProv AND m.UniqMonthID = m1.Der_MonthID 


-- In month access counts
LEFT JOIN 
	(SELECT 
		UniqMonthID,
		OrgIDProv,
		COUNT(DISTINCT CASE WHEN m2.InMonthAccess = 1 THEN m2.Person_ID END) AS InMonthAccess
	FROM #master AS m2
	GROUP BY UniqMonthID, OrgIDProv) m2 
	ON m.OrgIDProv = m2.OrgIDProv AND m.UniqMonthID = m2.UniqMonthID 


LEFT JOIN NHSE_Reference.dbo.[tbl_Ref_ODS_Provider_Hierarchies] prov ON m.OrgIDProv = prov.Organisation_Code 


UNION ALL


---- CCG level acces and ONS births 
SELECT DISTINCT
	m.ReportingPeriodEndDate,
	m.SubmissionType,
	m.UniqMonthID,
	m.Der_FY,
	'CCG' AS OrganisationType,
	m.OrgIDCCGRes,
	m.[CCG name],
	NULL AS nhser19cd_Prov,
	ISNULL(m1.Access,0) AS Access,
	ISNULL(m2.InMonthAccess,0) AS InMonthAccess,
	b.[Live births 2016],
	b.[Live births 2016] AS [Live births 2016 2], --duplicate for denominator in tableau
	m.[Region name] AS [Geographic benchmarking group]

FROM #BaseMaster m

----Rolling 12 month access counts
LEFT JOIN 
	(SELECT 
		Der_MonthID,
		OrgIDCCGRes,
		COUNT(DISTINCT CASE WHEN m1.RollingAccess = 1 THEN m1.Person_ID END) AS Access,
		COUNT(DISTINCT m1.Person_ID) AS People	
	FROM #Rolling AS m1
	GROUP BY Der_MonthID, OrgIDCCGRes) m1 

	ON m.OrgIDCCGRes = m1.OrgIDCCGRes AND m.UniqMonthID = m1.Der_MonthID 

-- In month access counts
LEFT JOIN
	(SELECT 
		UniqMonthID,
		OrgIDCCGRes,
		COUNT(DISTINCT CASE WHEN m2.InMonthAccessCCG = 1 THEN m2.Person_ID END) AS InMonthAccess
	FROM #master AS m2
	GROUP BY UniqMonthID, OrgIDCCGRes) m2 

	ON m.OrgIDCCGRes = m2.OrgIDCCGRes AND m.UniqMonthID = m2.UniqMonthID 

-- ONS births
LEFT JOIN
	(SELECT DISTINCT
		d.UniqMonthID,
		o.Orgtype AS OrganisationType,
		COALESCE(cc.New_Code,o.OrgCode) AS OrganisationCode,
		SUM(o.LiveBirths2016) AS [Live births 2016]

	FROM #AllDates d, [NHSE_Sandbox_MentalHealth].[dbo].[Staging_PerinatalONSBirths2016] o

	LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges] cc ON o.OrgCode = cc.Org_Code

	WHERE o.OrgType = 'CCG' 

	GROUP BY d.UniqMonthID, o.Orgtype, COALESCE(cc.New_Code,o.OrgCode)) b

	ON m.OrgIDCCGRes = b.OrganisationCode AND m.UniqMonthID = b.UniqMonthID


UNION ALL


---- STP level access and ONS births
SELECT DISTINCT
	m.ReportingPeriodEndDate,
	m.SubmissionType,
	m.UniqMonthID,
	m.Der_FY,
    'STP' AS OrganisationType,
	m.STP_Code,
	m.[STP name],
	NULL AS nhser19cd_Prov,
	ISNULL(m1.Access,0) AS Access,
	ISNULL(m2.InMonthAccess,0) AS InMonthAccess,
	b.[Live births 2016],
	b.[Live births 2016] AS [Live births 2016 2], --duplicate for denominator in tableau
	m.[Region name] AS [Geographic benchmarking group]

FROM #BaseMaster m

---- Rolling 12 month access counts
LEFT JOIN 
	(SELECT 
		Der_MonthID,
		STP_Code,
		COUNT(DISTINCT CASE WHEN m1.RollingAccess = 1 THEN m1.Person_ID END) AS Access,
		COUNT(DISTINCT m1.Person_ID) AS People
	FROM #Rolling AS m1
	GROUP BY Der_MonthID, STP_Code) m1 

	ON m.STP_Code = m1.STP_Code AND m.UniqMonthID = m1.Der_MonthID 

-- In month access counts
LEFT JOIN
	(SELECT 
		UniqMonthID,
		STP_Code,
		COUNT(DISTINCT CASE WHEN m2.InMonthAccessSTP = 1 THEN m2.Person_ID END) AS InMonthAccess
	FROM #master AS m2
	GROUP BY UniqMonthID, STP_Code) m2 

	ON m.STP_Code = m2.STP_Code AND m.UniqMonthID = m2.UniqMonthID 

-- ONS births
LEFT JOIN 
	(SELECT
		d.UniqMonthID,
		'STP' AS OrganisationType,
		map.STP_Code AS OrganisationCode,
		SUM(o.LiveBirths2016) AS [Live births 2016]

	FROM #AllDates d, [NHSE_Sandbox_MentalHealth].[dbo].[Staging_PerinatalONSBirths2016] o

	LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges] cc ON o.OrgCode = cc.Org_Code

	LEFT JOIN NHSE_Reference.dbo.[tbl_Ref_ODS_Commissioner_Hierarchies] map ON COALESCE(cc.New_Code,o.OrgCode) = map.Organisation_Code

	WHERE o.OrgType = 'CCG'		

	GROUP BY d.UniqMonthID, map.STP_Code) b

	ON m.STP_Code = b.OrganisationCode AND m.UniqMonthID = b.UniqMonthID


UNION ALL


---- Region level access and ONS births
SELECT DISTINCT
	m.ReportingPeriodEndDate,
	m.SubmissionType,
	m.UniqMonthID,
	m.Der_FY,
	'Region' AS OrganisationType,
	m.Region_Code,
	m.[Region name],
	NULL AS nhser19cd_Prov,
	ISNULL(m1.Access,0) AS Access,
	ISNULL(m2.InMonthAccess,0) AS InMonthAccess,
	b.[Live births 2016],
	b.[Live births 2016] AS [Live births 2016 2], --duplicate for denominator in tableau
	'N/A' AS [Geographic benchmarking group]

FROM #BaseMaster m

---- Rolling 12 month access counts
LEFT JOIN 
	(SELECT 
		Der_MonthID,
		Region_Code, 
		COUNT(DISTINCT CASE WHEN m1.RollingAccess = 1 THEN m1.Person_ID END) AS Access,
		COUNT(DISTINCT m1.Person_ID) AS People	
		FROM #Rolling AS m1
	GROUP BY Der_MonthID, Region_Code) m1 

	ON m.Region_Code = m1.Region_Code AND m.UniqMonthID = m1.Der_MonthID 

-- In month access counts
LEFT JOIN
	(SELECT 
		UniqMonthID,
		Region_Code,
		COUNT(DISTINCT CASE WHEN m2.InMonthAccessReg = 1 THEN m2.Person_ID END) AS InMonthAccess
		FROM #master AS m2
	GROUP BY UniqMonthID, Region_Code) m2 

	ON m.Region_Code = m2.Region_Code AND m.UniqMonthID = m2.UniqMonthID 

-- ONS births
LEFT JOIN
	(SELECT
		d.UniqMonthID,
		'Region' AS OrganisationType,
		map.Region_Code AS OrganisationCode,
		SUM(o.LiveBirths2016) AS [Live births 2016]

	FROM #AllDates d, [NHSE_Sandbox_MentalHealth].[dbo].[Staging_PerinatalONSBirths2016] o

	LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges] cc ON o.OrgCode = cc.Org_Code

	LEFT JOIN NHSE_Reference.dbo.[tbl_Ref_ODS_Commissioner_Hierarchies] map ON COALESCE(cc.New_Code,o.OrgCode) = map.Organisation_Code 

	WHERE o.OrgType = 'CCG'

	GROUP BY d.UniqMonthID, map.Region_Code) b
	
	ON m.Region_Code = b.OrganisationCode AND m.UniqMonthID = b.UniqMonthID


UNION ALL


---- England level access and ONS births
SELECT DISTINCT
	m.ReportingPeriodEndDate,
	m.SubmissionType,
	m.UniqMonthID,
	m.Der_FY,
	'England' AS OrganisationType,
	'ENG' AS OrganisationCode,
	'ENGLAND' AS OrganisationName,
	NULL AS nhser19cd_Prov,
	ISNULL(m1.Access,0) AS Access,
	ISNULL(m2.InMonthAccess,0) AS InMonthAccess,
	b.[Live births 2016], 
	b.[Live births 2016] AS [Live births 2016 2], --duplicate for denominator in tableau
	'N/A' AS [Geographic benchmarking group]

FROM #Base m

-- Rolling 12 month access counts
LEFT JOIN 
	(SELECT 
		Der_MonthID,
		COUNT(DISTINCT CASE WHEN m1.RollingAccess = 1 THEN m1.Person_ID END) AS Access,
		COUNT(DISTINCT m1.Person_ID) AS People
	FROM #Rolling AS m1
	GROUP BY Der_MonthID) m1 

	ON m.UniqMonthID = m1.Der_MonthID 

-- In month access counts
LEFT JOIN
	(SELECT 
		UniqMonthID,
		COUNT(DISTINCT CASE WHEN m2.InMonthAccessEng = 1 THEN m2.Person_ID END) AS InMonthAccess
	FROM #master AS m2
	GROUP BY UniqMonthID) m2 

	ON m.UniqMonthID = m2.UniqMonthID 

-- ONS births
LEFT JOIN
	(SELECT
		d.UniqMonthID,
		'England' AS OrganisationType,
		'ENG' AS OrganisationCode,
		'England' AS OrganisationName,
		SUM(o.LiveBirths2016) AS [Live births 2016]

	FROM #AllDates d, [NHSE_Sandbox_MentalHealth].[dbo].[Staging_PerinatalONSBirths2016] o

	WHERE o.OrgType = 'CCG'

	GROUP BY d.UniqMonthID) b
	
	ON m.UniqMonthID = b.UniqMonthID

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
DQ FLAGS UP TO LATEST PERFORMANCE DATA - FOR TABLEAU DQ MAP
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#ProviderDQ_Submissions_FYear') IS NOT NULL
DROP TABLE #ProviderDQ_Submissions_FYear

SELECT DISTINCT 
	@RPEndDatePerformance AS ReportingPeriodEndDate,
	'Performance' AS SubmissionType,
	@LatestPerformanceSub AS UniqMonthID,
	a.Der_FY,
	a.OrganisationType,
	a.OrganisationCode,
	a.OrganisationName,
	a.nhser19cd_Prov,
	SUM(CASE WHEN a.InMonthAccess IS NULL OR a.InMonthAccess = 0 THEN 1 ELSE 0 END) AS [YTD Missed submission flag], -- Flags missed submissions since start of Financial year
	SUM(CASE WHEN a.InMonthAccess BETWEEN 1 AND 5 THEN 1 ELSE 0 END) AS [YTD Suppressed submission flag], -- Flags suppressed submissions since start of Financial year
	SUM(CASE WHEN a.UniqMonthID = @LatestPerformanceSub AND (a.InMonthAccess IS NULL OR a.InMonthAccess = 0) THEN 1 ELSE 0 END) AS [Latest performance Missed submission flag], -- Flags missed submissions in latest Performance data
	SUM(CASE WHEN a.UniqMonthID = @LatestPerformanceSub AND a.InMonthAccess BETWEEN 1 AND 5 THEN 1 ELSE 0 END) AS [Latest performance Suppressed submission flag] -- Flags missed submissions in latest Performance data

INTO #ProviderDQ_Submissions_FYear
FROM #AccessTotals a

LEFT JOIN [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header] AS d ON a.UniqMonthID = d.UniqMonthID

WHERE a.OrganisationType = 'Provider' AND a.UniqMonthID BETWEEN @FYStart AND @LatestPerformanceSub

GROUP BY 
	a.Der_FY,
	a.OrganisationType,
	a.OrganisationCode,
	a.OrganisationName,
	a.nhser19cd_Prov


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
UNPIVOT ACCESS COUNTS FOR DASHBOARD EXTRACT
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Pivot_Access') IS NOT NULL
DROP TABLE #Pivot_Access

--Unpivot the Access measures
SELECT DISTINCT
	ReportingPeriodEndDate,
	SubmissionType,
	UniqMonthID,
	Der_FY,
	OrganisationType,
	OrganisationCode,
	OrganisationName,
	nhser19cd_Prov,
	MeasureName,
	MeasureValue,
	CASE WHEN MeasureName = 'Access' THEN [Live births 2016 2] ELSE NULL END AS [Denominator],
	[Geographic benchmarking group]
	
INTO #Pivot_Access 

FROM #AccessTotals 

UNPIVOT 
	(MeasureValue FOR MeasureName IN 
		(Access,
		InMonthAccess)) U

UNION ALL


--Unpivot the YTD Access data
SELECT DISTINCT
	ReportingPeriodEndDate,
	SubmissionType,
	UniqMonthID,
	Der_FY,
	OrganisationType,
	OrganisationCode,
	OrganisationName,
	NULL AS nhser19cd_Prov,
	MeasureName,
	MeasureValue,
	NULL AS [Denominator],
	[Geographic benchmarking group]

FROM #YTD

UNPIVOT 
	(MeasureValue FOR MeasureName IN 
			([YTD Access])) U


UNION ALL


--Unpivot the calculated provider DQ Flags 
SELECT DISTINCT
	ReportingPeriodEndDate,
	SubmissionType,
	UniqMonthID,
	Der_FY,
	OrganisationType,
	OrganisationCode,
	OrganisationName,
	nhser19cd_Prov,
	MeasureName,
	MeasureValue,
	NULL AS [Denominator],
	NULL AS [Geographic benchmarking group]

FROM #ProviderDQ_Submissions_FYear

UNPIVOT 
	(MeasureValue FOR MeasureName IN 
			([YTD Missed submission flag],
			[YTD Suppressed submission flag],
			[Latest performance Missed submission flag],
			[Latest performance Suppressed submission flag])) U


UNION ALL


--Sum up Caseload measures to organisation level for inclusion in the Data table - Provider
SELECT
	ReportingPeriodEndDate,
	SubmissionType,
	UniqMonthID,
	Der_FY,
	'Provider' AS OrganisationType,
	OrgIDProv AS OrganisationCode,
	[Provider name] AS OrganisationName,
	NULL AS nhser19cd_Prov,
	MeasureName,
	SUM(MeasureValue) AS MeasureValue,
	NULL AS [Denominator],
	[Provider region name] AS [Geographic benchmarking group]

	FROM #Pivot_Monthly_Extract
	
	WHERE MeasureName IN ('Caseload total','New referrals','Closed referrals')

	GROUP BY ReportingPeriodEndDate,
	SubmissionType,
	UniqMonthID,
	Der_FY,
	OrgIDProv,
	[Provider name],
	MeasureName,
	[Provider region name]


UNION ALL


--Sum up Caseload to organisation level for inclusion in the Data table - CCG
SELECT
	ReportingPeriodEndDate,
	SubmissionType,
	UniqMonthID,
	Der_FY,
	'CCG' AS OrganisationType,
	OrgIDCCGRes AS OrganisationCode,
	[CCG name] AS OrganisationName,
	NULL AS nhser19cd_Prov,
	MeasureName,
	SUM(MeasureValue) AS MeasureValue,
	NULL AS [Denominator],
	[Region name] AS [Geographic benchmarking group]

	FROM #Pivot_Monthly_Extract
	
	WHERE MeasureName IN ('Caseload total','New referrals','Closed referrals')

	GROUP BY ReportingPeriodEndDate,
	SubmissionType,
	UniqMonthID,
	Der_FY,
	OrgIDCCGRes,
	[CCG name],
	MeasureName,
	[Region name]


UNION ALL


--Sum up Caseload to organisation level for inclusion in the Data table - STP
SELECT
	ReportingPeriodEndDate,
	SubmissionType,
	UniqMonthID,
	Der_FY,
	'STP' AS OrganisationType,
	STP_Code AS OrganisationCode,
	[STP name] AS OrganisationName,
	NULL AS nhser19cd_Prov,
	MeasureName,
	SUM(MeasureValue) AS MeasureValue,
	NULL AS [Denominator],
	[Region name] AS [Geographic benchmarking group]

	FROM #Pivot_Monthly_Extract
	
	WHERE MeasureName IN ('Caseload total','New referrals','Closed referrals')

	GROUP BY ReportingPeriodEndDate,
	SubmissionType,
	UniqMonthID,
	Der_FY,
	STP_Code,
	[STP name],
	MeasureName,
	[Region name]


UNION ALL


--Sum up Caseload to organisation level for inclusion in the Data table - Region
SELECT
	ReportingPeriodEndDate,
	SubmissionType,
	UniqMonthID,
	Der_FY,
	'Region' AS OrganisationType,
	Region_Code AS OrganisationCode,
	[Region name] AS OrganisationName,
	NULL AS nhser19cd_Prov,
	MeasureName,
	SUM(MeasureValue) AS MeasureValue,
	NULL AS [Denominator],
	'N/A' AS [Geographic benchmarking group]

	FROM #Pivot_Monthly_Extract
	
	WHERE MeasureName IN ('Caseload total','New referrals','Closed referrals')

	GROUP BY ReportingPeriodEndDate,
	SubmissionType,
	UniqMonthID,
	Der_FY,
	Region_Code,
	[Region name],
	MeasureName


UNION ALL


--Sum up Caseload to organisation level for inclusion in the Data table - England
SELECT
	ReportingPeriodEndDate,
	SubmissionType,
	UniqMonthID,
	Der_FY,
	'England' AS OrganisationType,
	'ENG' AS OrganisationCode,
	'England' AS OrganisationName,
	NULL AS nhser19cd_Prov,
	MeasureName,
	SUM(MeasureValue) AS MeasureValue,
	NULL AS [Denominator],
	'N/A' AS [Geographic benchmarking group]

	FROM #Pivot_Monthly_Extract
	
	WHERE MeasureName IN ('Caseload total','New referrals','Closed referrals')

	GROUP BY ReportingPeriodEndDate,
	SubmissionType,
	UniqMonthID,
	Der_FY,
	MeasureName

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
UNPIVOTED ACCESS EXTRACT WITH DQ FLAGS BROUGH THROUGH FOR USE IN TABLEAU MAP
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Pivot_Access_Extract') IS NOT NULL
DROP TABLE #Pivot_Access_Extract

			SELECT DISTINCT
			GETDATE() AS ImportDate,
			a.ReportingPeriodEndDate,
			a.SubmissionType,
			a.UniqMonthID,
			a.Der_FY,
			a.OrganisationType,
			a.OrganisationCode,
			a.OrganisationName,
			a.nhser19cd_Prov,
			prov.Region_Name,
			a.MeasureName,
			a.MeasureValue,
			ISNULL(a.Denominator,0) AS Denominator,
			a.[Geographic benchmarking group],
			d.[YTD Missed submission flag],
			t.Targets
			
			INTO #Pivot_Access_Extract
			
			FROM #Pivot_Access a

			LEFT JOIN #ProviderDQ_Submissions_FYear d ON a.OrganisationCode = d.OrganisationCode AND a.OrganisationType = 'Provider'

			LEFT JOIN NHSE_Reference.dbo.[tbl_Ref_ODS_Provider_Hierarchies] prov ON a.OrganisationCode = prov.Organisation_Code AND a.OrganisationType = 'Provider'

			LEFT JOIN #Targets t ON a.OrganisationType = t.OrganisationType AND a.OrganisationCode = t.OrganisationCode AND a.Der_FY = t.Fyear AND a.MeasureName ='YTD Access'

			WHERE a.OrganisationCode != 'Missing / Invalid' AND a.OrganisationCode != 'RYK' -- Exclude DUDLEY INTEGRATED HEALTH AND CARE NHS TRUST (no longer submitting own PMH data) 



/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

UPDATE ACCESS AND MONTHLY SANDBOX TABLES WITH LATEST EXTRACT 

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

---- DELTETE DATA FROM CASELOAD ACTIVITY TABLE SINCE START OF FINANCIAL YEAR
--DELETE FROM NHSE_Sandbox_MentalHealth.dbo.Dashboard_Perinatal_Activity
--WHERE UniqMonthID >= @FYStart


---- UPDATE TABLE WITH LATEST DATA 
--INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Dashboard_Perinatal_Activity
--SELECT * FROM #Pivot_Monthly_Extract
--WHERE UniqMonthID >= @FYStart


---- DELTETE DATA FROM ACCESS TABLE SINCE START OF FINANCIAL YEAR
--DELETE FROM NHSE_Sandbox_MentalHealth.dbo.Dashboard_Perinatal_Access
--WHERE UniqMonthID >= @FYStart


---- UPDATE TABLE WITH LATEST DATA 
--INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Dashboard_Perinatal_Access
--SELECT * FROM #Pivot_Access_Extract
--WHERE UniqMonthID >= @FYStart


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

DATA EXTRACTS FOR SHARING WITH POLICY TEAM

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
EXTRACT 1 - MONTHLY PROVIDER ACCESS FIGURES SINCE START OF FINANCIAL YEAR (UP TO LATEST PERFORMANCE SUBMISSION)
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--SELECT * FROM   
--(
--    SELECT
--		OrganisationCode,
--		OrganisationName,
--		CASE WHEN MeasureValue < 5 THEN '*' ELSE ISNULL(CAST(ROUND(MeasureValue/5.0,0)*5 AS VARCHAR),'*') END AS InMonthAccess,
--		UniqMonthID
--	FROM NHSE_Sandbox_MentalHealth.dbo.Dashboard_Perinatal_Access
--	WHERE OrganisationType = 'Provider' AND MeasureName = 'InMonthAccess'
--	AND UniqMonthID >= @FYStart
--) t 

--PIVOT(
--    MAX(InMonthAccess) 
--    FOR UniqMonthID
	
--	IN (-- Need to manually update list of month IDs with UniqMonthIDs up to latest Performance submission
--		[1455],
--		[1454],
--		[1453])
--) AS pivot_table;



--/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
--EXTRACT 2 - YEAR TO DATE FIGURES PLUS END OF YEAR TARGETS, FOR THE MOST RECENT PERFORMANCE SUBMISSION
-->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--SELECT 
--	ReportingPeriodEndDate,
--	CASE WHEN [OrganisationType] = 'Region' THEN OrganisationName ELSE [Geographic benchmarking group] END AS Region ,
--	OrganisationType,
--	OrganisationCode,
--	OrganisationName,
--	CASE WHEN MeasureValue < 5 THEN '*' ELSE ISNULL(CAST(ROUND(MeasureValue/5.0,0)*5 AS VARCHAR),'*') END AS [YTD Access],
--	ISNULL((ROUND([Targets]/5.0,0)*5),0) AS [Target]

--	FROM NHSE_Sandbox_MentalHealth.dbo.Dashboard_Perinatal_Access

--	WHERE OrganisationType IN ('CCG','STP','Region') AND MeasureName = 'YTD Access'

--	AND UniqMonthID = @LatestPerformanceSub

--	ORDER BY 2, 4 DESC


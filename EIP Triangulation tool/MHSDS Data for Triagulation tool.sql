/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
MHSDS DATA FOR EIP TRIANGULATION TOOL

ASSET: PRE-PROCESSED TABLES

CREATED BY CARL MONEY 23/12/2020

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--SET VARIABLES

DECLARE @EndRP INT

SET @EndRP	= (SELECT UniqMonthID
FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header
WHERE Der_MostRecentFlag = 'P')

DECLARE @StartRP INT

SET @StartRP = 1428 --Mar 19

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
IDENTIFY REFERRALS TO EIP SERVICES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Ref') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Ref

SELECT
	r.ReportingPeriodStartDate,
	r.ReportingPeriodEndDate,
	r.UniqMonthID,
	r.OrgIDProv,
	r.Person_ID,
	r.RecordNumber,
	r.UniqServReqID,
	r.ReferralRequestReceivedDate,
	r.EthnicCategory,
	r.Gender,
	r.LSOA2011,
	r.OrgIDCCGRes,
	r.AgeServReferRecDate,
	r.ServDischDate,
	r.ReferClosReason,
	r.ReferRejectionDate,
	r.ReferRejectReason,
	RIGHT(r.UniqCareProfTeamID, LEN(r.UniqCareProfTeamID) - LEN(r.OrgIDProv)) AS CareProfTeamID, -- to remove org code from start of ID
	r.PrimReasonReferralMH

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Ref

FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Referral r

WHERE r.ServTeamTypeRefToMH = 'A14' AND (r.LADistrictAuth LIKE 'E%' OR r.LADistrictAuth IS NULL) AND UniqMonthID <= @EndRP

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET VALID, UNIQUE ASSESSMENTS FOR TOOLS WE'RE INTERESTED IN
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Ass') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Ass

SELECT 
	a.Person_ID,
	a.UniqMonthID,
	a.OrgIDProv,
	a.RecordNumber,
	e.UniqServReqID,
	a.Der_AssToolCompDate,
	a.Der_AssUniqID,
	a.Der_AssessmentToolName,
	a.Der_PreferredTermSNOMED,
	a.CodedAssToolType,
	a.PersScore,
	CASE WHEN a.Der_AssessmentToolName LIKE 'H%' THEN 'HoNOS' ELSE a.Der_AssessmentToolName END AS [Recoded Assessment Tool Name],
	a.Der_AssOrderAsc,
	a.Der_AssOrderDesc

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Ass 

FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Assessments] a

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Ref e ON e.RecordNumber = a.RecordNumber AND e.UniqServReqID = a.UniqServReqID

WHERE a.Der_AssOrderAsc IS NOT NULL AND (a.Der_AssessmentToolName LIKE 'HoNOS%' OR a.Der_AssessmentToolName IN ('DIALOG','Questionnaire about the Process of Recovery (QPR)'))

--/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
--GET DISTINCT ASSESSMENTS AND ORDER
-->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AssOrder') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AssOrder

SELECT DISTINCT
	r.Person_ID,
	r.UniqServReqID,
	r.[Recoded Assessment Tool Name],
	r.Der_AssToolCompDate,
	DENSE_RANK () OVER (PARTITION BY r.Person_ID, r.UniqServReqID, r.[Recoded Assessment Tool Name] ORDER BY r.Der_AssToolCompDate ASC) AS AssOrder

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AssOrder

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Ass r

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE ASSESSMENTS BY REFERRAL
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AssAgg') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AssAgg

SELECT
	r.ReportingPeriodEndDate,
	r.Person_ID,
	r.UniqServReqID,
	r.CareProfTeamID,
	SUM(CASE WHEN o.AssOrder = 1 AND o.[Recoded Assessment Tool Name] = 'HoNOS' AND o.Der_AssToolCompDate <= r.ReportingPeriodEndDate THEN 1 ELSE 0 END) AS 'HoNOSRecordedOnce',
	SUM(CASE WHEN o.AssOrder = 2 AND o.[Recoded Assessment Tool Name] = 'HoNOS' AND o.Der_AssToolCompDate <= r.ReportingPeriodEndDate THEN 1 ELSE 0 END) AS 'HoNOSRecordedMoreThanOnce',
	SUM(CASE WHEN o.AssOrder = 1 AND o.[Recoded Assessment Tool Name] = 'DIALOG' AND o.Der_AssToolCompDate <= r.ReportingPeriodEndDate THEN 1 ELSE 0 END) AS 'DIALOGRecordedOnce',
	SUM(CASE WHEN o.AssOrder = 2 AND o.[Recoded Assessment Tool Name] = 'DIALOG' AND o.Der_AssToolCompDate <= r.ReportingPeriodEndDate THEN 1 ELSE 0 END) AS 'DIALOGRecordedMoreThanOnce',
	SUM(CASE WHEN o.AssOrder = 1 AND o.[Recoded Assessment Tool Name] = 'Questionnaire about the Process of Recovery (QPR)' AND o.Der_AssToolCompDate <= r.ReportingPeriodEndDate THEN 1 ELSE 0 END) AS 'QPRRecordedOnce',
	SUM(CASE WHEN o.AssOrder = 2 AND o.[Recoded Assessment Tool Name] = 'Questionnaire about the Process of Recovery (QPR)' AND o.Der_AssToolCompDate <= r.ReportingPeriodEndDate THEN 1 ELSE 0 END) AS 'QPRRecordedMoreThanOnce',
	SUM(CASE WHEN o.AssOrder = 2 AND o.Der_AssToolCompDate <= r.ReportingPeriodEndDate THEN 1 ELSE 0 END) AS 'TwoMeasuresTwice'

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AssAgg

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Ref r 

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AssOrder o ON r.Person_ID = o.Person_ID AND r.UniqServReqID = o.UniqServReqID AND o.AssOrder <=2

GROUP BY r.ReportingPeriodEndDate, r.Person_ID, r.UniqServReqID, r.CareProfTeamID

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET HoNOS CHANGE PROFILE - IDENTIFY FIRST AND LAST
SCORES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_FandL') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_FandL

SELECT
	r.Person_ID,
	r.UniqServReqID,
	r.Der_AssToolCompDate,
	r.Der_AssessmentToolName,
	r.CodedAssToolType,
	CAST(CAST(r.PersScore AS NUMERIC(19,4)) AS INT) AS PersScore,
	r.Der_AssOrderAsc AS FirstScore,
	r.Der_AssOrderDesc AS LastScore

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_FandL

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Ass r

WHERE r.Der_AssessmentToolName IN ('DIALOG','Questionnaire about the Process of Recovery (QPR)','HoNOS Working Age Adults')

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ASSESSMENT CHANGE PROFILE - SCORE CHANGE BY REFERRAL
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Score') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Score

SELECT
	f.Person_ID,
	f.UniqServReqID,
	--HONOS INITIAL
	MAX(CASE WHEN f.CodedAssToolType = '979641000000103' THEN f.PersScore END) AS 'BEH_Ini',
	MAX(CASE WHEN f.CodedAssToolType = '979651000000100' THEN f.PersScore END) AS 'INJ_Ini',
	MAX(CASE WHEN f.CodedAssToolType = '979661000000102' THEN f.PersScore END) AS 'SUB_Ini',
	MAX(CASE WHEN f.CodedAssToolType = '979671000000109' THEN f.PersScore END) AS 'COG_Ini',
	MAX(CASE WHEN f.CodedAssToolType = '979681000000106' THEN f.PersScore END) AS 'ILL_Ini',
	MAX(CASE WHEN f.CodedAssToolType = '979691000000108' THEN f.PersScore END) AS 'HAL_Ini',
	MAX(CASE WHEN f.CodedAssToolType = '979701000000108' THEN f.PersScore END) AS 'DEP_Ini',
	MAX(CASE WHEN f.CodedAssToolType = '979711000000105' THEN f.PersScore END) AS 'OTH_Ini',
	MAX(CASE WHEN f.CodedAssToolType = '979721000000104' THEN f.PersScore END) AS 'REL_Ini',
	MAX(CASE WHEN f.CodedAssToolType = '979731000000102' THEN f.PersScore END) AS 'ADL_Ini',
	MAX(CASE WHEN f.CodedAssToolType = '979741000000106' THEN f.PersScore END) AS 'LIV_Ini',
	MAX(CASE WHEN f.CodedAssToolType = '979751000000109' THEN f.PersScore END) AS 'OCC_Ini',
	--DIALOG INITIAL
	MAX(CASE WHEN f.CodedAssToolType = '1037651000000100' THEN f.PersScore END) AS 'MEN_Ini',
	MAX(CASE WHEN f.CodedAssToolType = '1037661000000102' THEN f.PersScore END) AS 'PHY_Ini',
	MAX(CASE WHEN f.CodedAssToolType = '1037671000000109' THEN f.PersScore END) AS 'JOB_Ini',
	MAX(CASE WHEN f.CodedAssToolType = '1037681000000106' THEN f.PersScore END) AS 'ACC_Ini',
	MAX(CASE WHEN f.CodedAssToolType = '1037691000000108' THEN f.PersScore END) AS 'LEI_Ini',
	MAX(CASE WHEN f.CodedAssToolType = '1037701000000108' THEN f.PersScore END) AS 'FRD_Ini',
	MAX(CASE WHEN f.CodedAssToolType = '1037711000000105' THEN f.PersScore END) AS 'PRT_Ini',
	MAX(CASE WHEN f.CodedAssToolType = '1037721000000104' THEN f.PersScore END) AS 'SAF_Ini',
	MAX(CASE WHEN f.CodedAssToolType = '1037731000000102' THEN f.PersScore END) AS 'MED_Ini',
	MAX(CASE WHEN f.CodedAssToolType = '1037741000000106' THEN f.PersScore END) AS 'PRA_Ini',
	MAX(CASE WHEN f.CodedAssToolType = '1037751000000109' THEN f.PersScore END) AS 'CON_Ini',
	--QPR INITIAL
	MAX(CASE WHEN f.CodedAssToolType = '1035441000000106' THEN f.PersScore END) AS 'QPR_Ini',

	--HONOS FINAL
	MAX(CASE WHEN f2.CodedAssToolType = '979641000000103' THEN f2.PersScore END) AS 'BEH_Fin',
	MAX(CASE WHEN f2.CodedAssToolType = '979651000000100' THEN f2.PersScore END) AS 'INJ_Fin',
	MAX(CASE WHEN f2.CodedAssToolType = '979661000000102' THEN f2.PersScore END) AS 'SUB_Fin',
	MAX(CASE WHEN f2.CodedAssToolType = '979671000000109' THEN f2.PersScore END) AS 'COG_Fin',
	MAX(CASE WHEN f2.CodedAssToolType = '979681000000106' THEN f2.PersScore END) AS 'ILL_Fin',
	MAX(CASE WHEN f2.CodedAssToolType = '979691000000108' THEN f2.PersScore END) AS 'HAL_Fin',
	MAX(CASE WHEN f2.CodedAssToolType = '979701000000108' THEN f2.PersScore END) AS 'DEP_Fin',
	MAX(CASE WHEN f2.CodedAssToolType = '979711000000105' THEN f2.PersScore END) AS 'OTH_Fin',
	MAX(CASE WHEN f2.CodedAssToolType = '979721000000104' THEN f2.PersScore END) AS 'REL_Fin',
	MAX(CASE WHEN f2.CodedAssToolType = '979731000000102' THEN f2.PersScore END) AS 'ADL_Fin',
	MAX(CASE WHEN f2.CodedAssToolType = '979741000000106' THEN f2.PersScore END) AS 'LIV_Fin',
	MAX(CASE WHEN f2.CodedAssToolType = '979751000000109' THEN f2.PersScore END) AS 'OCC_Fin',
	--DIALOG FINAL
	MAX(CASE WHEN f2.CodedAssToolType = '1037651000000100' THEN f2.PersScore END) AS 'MEN_Fin',
	MAX(CASE WHEN f2.CodedAssToolType = '1037661000000102' THEN f2.PersScore END) AS 'PHY_Fin',
	MAX(CASE WHEN f2.CodedAssToolType = '1037671000000109' THEN f2.PersScore END) AS 'JOB_Fin',
	MAX(CASE WHEN f2.CodedAssToolType = '1037681000000106' THEN f2.PersScore END) AS 'ACC_Fin',
	MAX(CASE WHEN f2.CodedAssToolType = '1037691000000108' THEN f2.PersScore END) AS 'LEI_Fin',
	MAX(CASE WHEN f2.CodedAssToolType = '1037701000000108' THEN f2.PersScore END) AS 'FRD_Fin',
	MAX(CASE WHEN f2.CodedAssToolType = '1037711000000105' THEN f2.PersScore END) AS 'PRT_Fin',
	MAX(CASE WHEN f2.CodedAssToolType = '1037721000000104' THEN f2.PersScore END) AS 'SAF_Fin',
	MAX(CASE WHEN f2.CodedAssToolType = '1037731000000102' THEN f2.PersScore END) AS 'MED_Fin',
	MAX(CASE WHEN f2.CodedAssToolType = '1037741000000106' THEN f2.PersScore END) AS 'PRA_Fin',
	MAX(CASE WHEN f2.CodedAssToolType = '1037751000000109' THEN f2.PersScore END) AS 'CON_Fin',
	--QPR FINAL
	MAX(CASE WHEN f2.CodedAssToolType = '1035441000000106' THEN f2.PersScore END) AS 'QPR_Fin',
	--ASS COUNT
	SUM(CASE WHEN f2.Der_AssessmentToolName = 'DIALOG' THEN 1 ELSE 0 END) AS 'PairedDialog',
	SUM(CASE WHEN f2.Der_AssessmentToolName = 'Questionnaire about the Process of Recovery (QPR)' THEN 1 ELSE 0 END) AS 'PairedQPR',
	SUM(CASE WHEN f2.Der_AssessmentToolName = 'HoNOS Working Age Adults' THEN 1 ELSE 0 END) AS 'PairedHoNOS'

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Score

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_FandL f

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_FandL f2 ON f.Person_ID = f2.Person_ID AND f.UniqServReqID = f2.UniqServReqID AND f2.Der_AssToolCompDate > f.Der_AssToolCompDate AND f2.LastScore = 1

WHERE f.FirstScore = 1

GROUP BY f.Person_ID, f.UniqServReqID

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ALL BED DAYS IN ANY PROVIDER
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

if OBJECT_ID('NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_BedDays') is not null
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_BedDays

SELECT 
	e.RecordNumber,
	SUM(DATEDIFF(dd, (CASE WHEN i.StartDateHospProvSpell < e.ReportingPeriodStartDate THEN e.ReportingPeriodStartDate WHEN i.StartDateHospProvSpell < e.ReferralRequestReceivedDate THEN e.ReferralRequestReceivedDate ELSE i.StartDateHospProvSpell END), 
	COALESCE(e.ServDischDate,CASE WHEN i.DischDateHospProvSpell < e.ReportingPeriodEndDate THEN i.DischDateHospProvSpell ELSE e.ReportingPeriodEndDate END)) + 1) AS BedDays
	
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_BedDays

FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Inpatients] i

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Ref e ON e.Person_ID = i.Person_ID AND e.UniqMonthID = i.UniqMonthID

GROUP BY e.RecordNumber

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ALL PROCEDURES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

if OBJECT_ID('NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Activity') is not null
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Activity

SELECT 
	r.ReportingPeriodEndDate,
	r.Person_ID,
	r.UniqServReqID,
	c.UniqMonthID,
	r.RecordNumber,
	COALESCE(c.Der_SNoMEDProcTerm,c.Der_SNoMEDObsTerm) AS Der_SNoMEDTerm,
	CASE WHEN c.Der_SNoMEDProcQual = '443390004' THEN 0 ELSE 1 END AS Der_InterventionOffered,
	CASE WHEN c.Der_SNoMEDProcCode IN 
--CBTp
	('718026005', -- 'Cognitive behavioural therapy for psychosis'
	'1097161000000100', -- 'Referral for cognitive behavioural therapy for psychosis'

--FI
	'985451000000105', -- 'Family intervention for psychosis'
	'859411000000105', -- 'Referral for family therapy'

--Clozapine
	'723948002', -- 'Clozapine therapy'

--Physical health assessments and healthy lifestyle promotion
	'196771000000101', -- 'Smoking assessment'
	'443781008', -- 'Assessment of lifestyle'
	'698094009', -- 'Measurement of body mass index'
	'171222001', -- 'Hypertension screening'
	'43396009', -- 'Haemoglobin A1c measurement'
	'271062006', -- 'Fasting blood glucose measurement'
	'271061004', -- 'Random blood glucose measurement'
	'121868005', -- 'Total cholesterol measurement'
	'17888004', -- 'High density lipoprotein measurement'
	'166842003', -- 'Total cholesterol: HDL ratio measurement'
	'763243004', -- 'Assessment using QRISK cardiovascular disease 10 year risk calculator'
	'225323000', -- 'Smoking cessation education'
	'710081004', -- 'Smoking cessation therapy'
	'871661000000106', -- 'Referral to smoking cessation service'
	'715282001', -- 'Combined healthy eating and physical education programme'
	'1094331000000103', -- 'Referral for combined healthy eating and physical education programme'
	'281078001', -- 'Education about alcohol consumption'
	'425014005', -- 'Substance use education'
	'1099141000000106', -- 'Referral to alcohol misuse service'
	'201521000000104', -- 'Referral to substance misuse service'
	'699826006', -- 'Lifestyle education regarding risk of diabetes'
	'718361005', -- 'Weight management programme'
	'408289007', -- 'Refer to weight management programme'
	'1097171000000107', -- 'Referral for lifestyle education'

--Physical health interventions
	'1090411000000105', -- 'Referral to general practice service'
	'1097181000000109', -- 'Referral for antihypertensive therapy'
	'308116003', -- 'Antihypertensive therapy'
	'1099151000000109', -- 'Referral for diabetic care'
	'385804009', -- 'Diabetic care'
	'1098021000000108', -- 'Diet modification'
	'1097191000000106', -- 'Metformin therapy'
	'134350008', -- 'Lipid lowering therapy'

--Education and empolyment suppoort
	'183339004', -- 'Education rehabilitation'
	'415271004', -- 'Referral to education service'
	'70082004', -- 'Vocational rehabilitation'
	'18781004', -- 'Patient referral for vocational rehabilitation'
	'335891000000102', -- 'Supported employment'
	'1098051000000103', -- 'Employment support'
	'1098041000000101', -- 'Referral to an employment support service'
	'1082621000000104', -- 'Individual Placement and Support'
	'1082611000000105', -- 'Referral to an Individual Placement and Support service'

--Carer focused education and support
	'726052009', -- 'Carer focused education and support programme'
	'1097201000000108', -- 'Referral for carer focused education and support programme'

--ARMS
	'304891004', -- 'Cognitive behavioural therapy'
	'519101000000109', -- 'Referral for cognitive behavioural therapy'
	'1095991000000102') -- 'At Risk Mental State for Psychosis'

--duplicated these codes to pick up those recorded as OBS
	OR c.CodeObs IN( '196771000000101', -- 'Smoking assessment'
	'698094009', -- 'Measurement of body mass index'
	'171222001', -- 'Hypertension screening'
	'43396009', -- 'Haemoglobin A1c measurement'
	'271062006', -- 'Fasting blood glucose measurement'
	'271061004', -- 'Random blood glucose measurement'
	'121868005', -- 'Total cholesterol measurement'
	'17888004', -- 'High density lipoprotein measurement'
	'166842003') -- 'Total cholesterol: HDL ratio measurement'
	THEN 'NICE concordant' 
	WHEN COALESCE(c.Der_SNoMEDProcCode,c.CodeObs) IS NOT NULL THEN 'Other' 
	END AS [Intervention type]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Activity

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Ref r

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Interventions c ON r.RecordNumber = c.RecordNumber AND COALESCE(c.Der_SNoMEDProcTerm, c.Der_SNoMEDObsTerm) IS NOT NULL
	AND c.Der_ContactDate BETWEEN r.ReferralRequestReceivedDate AND COALESCE(r.ServDischDate,r.ReportingPeriodEndDate) AND r.ServDischDate IS NULL AND r.ReferRejectionDate IS NULL

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE PROCEDURES BY REFERRAL
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_ProcAgg') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_ProcAgg

SELECT
	r.UniqMonthID,
	r.OrgIDProv,
	r.RecordNumber,
	r.UniqServReqID,
	COUNT([Intervention type]) AS 'AnySNoMED',
	SUM(CASE WHEN a.[Intervention type] = 'NICE concordant' THEN 1 ELSE 0 END) AS 'NICESNoMED'
	
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_ProcAgg

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Ref r 

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Activity a ON r.Person_ID = a.Person_ID AND r.UniqServReqID = a.UniqServReqID AND a.UniqMonthID <= r.UniqMonthID

GROUP BY r.RecordNumber, r.UniqServReqID, r.UniqMonthID, r.OrgIDProv

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE ACTIVITY
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Agg') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Agg

SELECT
	r.Person_ID,
	r.ReportingPeriodEndDate,
	r.RecordNumber,
	r.UniqServReqID,
		
	--in month activity
	COUNT(CASE WHEN a.Der_Contact IS NOT NULL AND a.Der_ActivityType = 'DIRECT' THEN a.RecordNumber END) AS Der_InMonthContacts,
	COUNT(CASE WHEN a.Der_Contact IS NOT NULL AND a.Der_ActivityType = 'DIRECT' AND a.ConsMediumUsed = '01' THEN a.RecordNumber END) AS Der_InMonthF2FContacts,
	COUNT(CASE WHEN a.Der_Contact IS NOT NULL AND a.Der_ActivityType = 'DIRECT' AND a.ConsMediumUsed = '02' THEN a.RecordNumber END) AS Der_InMonthTeleContacts,
	COUNT(CASE WHEN a.Der_Contact IS NOT NULL AND a.Der_ActivityType = 'DIRECT' AND a.ConsMediumUsed IN ('03','04','05','06','98') THEN a.RecordNumber END) AS Der_InMonthOtherContacts,
	COUNT(CASE WHEN a.Der_Contact IS NOT NULL AND a.Der_ActivityType = 'DIRECT'  AND (a.ConsMediumUsed NOT IN ('01','02','03','04','05','06','98') OR a.ConsMediumUsed IS NULL) THEN a.RecordNumber END) AS Der_InMonthInvContacts,
	COUNT(CASE WHEN a.AttendOrDNACode IN ('7','3') THEN a.RecordNumber END) AS Der_InMonthDNAContacts,
	COUNT(CASE WHEN a.AttendOrDNACode IN ('2','4') THEN a.RecordNumber END) AS Der_InMonthCancelledContacts,
	COUNT(CASE WHEN a.Der_ActivityType = 'INDIRECT' THEN a.RecordNumber END) AS Der_InMonthIndirectContacts,
	COUNT(CASE WHEN a.Der_ActivityType = 'DIRECT' AND a.AttendOrDNACode NOT IN ('2','3','4','5','6','7') THEN a.RecordNumber END) AS Der_InMonthInvalidContacts,
	MAX(CASE WHEN a.Der_Contact IS NOT NULL THEN a.Der_ContactDate END) AS Der_LastContact,
	SUM(CASE WHEN a.Der_Contact IS NOT NULL AND a.Der_ActivityType = 'DIRECT' THEN a.Der_ContactDuration END) AS Der_ContactDuration

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Agg

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Ref r

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Activity a ON a.RecordNumber = r.RecordNumber AND a.UniqServReqID = r.UniqServReqID

GROUP BY r.Person_ID, r.ReportingPeriodEndDate, r.RecordNumber, r.UniqServReqID

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET CUMULATIVE ACTIVITY
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Cumulative') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Cumulative

SELECT
	r.Person_ID,
	r.ReportingPeriodEndDate,
	r.RecordNumber,
	r.UniqServReqID,

	-- cumulative activity
	MAX(Der_LastContact) AS Der_LastContact,
	SUM(a.Der_InMonthContacts) AS Der_CumulativeContacts

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Cumulative

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Ref r

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Agg a ON r.Person_ID = a.Person_ID AND r.UniqServReqID = a.UniqServReqID AND a.ReportingPeriodEndDate <= r.ReportingPeriodEndDate 

GROUP BY r.Person_ID, r.ReportingPeriodEndDate, r.RecordNumber, r.UniqServReqID

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
BUILD MASTER TABLE
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

if OBJECT_ID('NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Master') is not null
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Master

SELECT
	r.ReportingPeriodStartDate,
	r.ReportingPeriodEndDate,
	r.UniqServReqID,
	r.RecordNumber,
	r.OrgIDProv AS [Provider code],
	h.Organisation_Name AS [Provider name],
	COALESCE(cc.New_Code,r.OrgIDCCGRes, 'Missing / Invalid') AS [CCG code],
	COALESCE(c.Organisation_Name,'Missing / Invalid') AS [CCG name],
	ons.CCG21CD AS [CCG ONS code],
	COALESCE(c.STP_Code,'Missing / Invalid') AS [STP code],
	COALESCE(c.STP_Name,'Missing / Invalid') AS [STP name],
	ons.STP21CD AS [STP ONS code],
	COALESCE(c.Region_Code,'Missing / Invalid') AS [Region code],
	COALESCE(c.Region_Name,'Missing / Invalid') AS [Region name],
	ons.NHSER21CD AS [Region ONS code],
	r.Person_ID,
	CASE 
		WHEN e.Category IS NULL THEN  'Missing / invalid'
		WHEN e.Category = '' THEN 'Missing / invalid'
		ELSE CONCAT(e.[Category],' - ',e.[Main_Description_60_Chars])
	END AS Ethnicity,
	COALESCE(RIGHT(Person_Gender_Desc, LEN(Person_Gender_Desc) - 3), 'Missing / invalid') AS Gender,
	COALESCE(CASE WHEN l.IMD_Decile = '1' THEN '1 - most deprived' WHEN l.IMD_Decile = '10' THEN '10 - least deprived' ELSE CAST(l.IMD_Decile AS Varchar) END, 'Missing / Invalid') AS IMD_Decile,
	CASE
		WHEN r.AgeServReferRecDate BETWEEN 0 AND 13 THEN 'Under 14'
		WHEN r.AgeServReferRecDate BETWEEN 14 AND 35 THEN '14-35'
		WHEN r.AgeServReferRecDate BETWEEN 36 AND 65 THEN '36-65'
		WHEN r.AgeServReferRecDate >65 THEN 'Over 65'
		ELSE 'Missing / invalid'
	END AS [Age category],
	r.ReferralRequestReceivedDate,
	COALESCE(rr.Main_Description, 'Missing / invalid') AS [Primary reason for referral],
	r.CareProfTeamID AS [Local team identifier],

	-- get caseload measures
	CASE WHEN ((r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL THEN 1 ELSE 0 END AS [Open referrals],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_CumulativeContacts >=1 THEN 1 ELSE 0 END AS [Total caseload],

	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_CumulativeContacts >=1 AND r.AgeServReferRecDate BETWEEN 0 AND 13 THEN 1 ELSE 0 END AS [People on the caseload aged 13 and under],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_CumulativeContacts >=1 AND r.AgeServReferRecDate BETWEEN 14 AND 17 THEN 1 ELSE 0 END AS [People on the caseload aged 14-17],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_CumulativeContacts >=1 AND r.AgeServReferRecDate BETWEEN 18 AND 35 THEN 1 ELSE 0 END AS [People on the caseload aged 18-35],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_CumulativeContacts >=1 AND r.AgeServReferRecDate >35 THEN 1 ELSE 0 END AS [People on the caseload aged 36 and over],
	
	CASE WHEN r.ReferralRequestReceivedDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate THEN 1 ELSE 0 END AS [New referrals],
	CASE WHEN r.ServDischDate IS NOT NULL THEN 1 ELSE 0 END AS [Closed referrals],
	CASE WHEN r.ServDischDate IS NOT NULL AND r.ReferClosReason IN ('02','04') THEN 1 ELSE 0 END AS [Closed referrals - treatment complete / further treatment not appropriate],
	CASE WHEN r.ServDischDate IS NOT NULL AND r.ReferClosReason IN ('01','08') THEN 1 ELSE 0 END AS [Closed referrals - admitted / referred elsewhere],
	CASE WHEN r.ServDischDate IS NOT NULL AND r.ReferClosReason IN ('03','07') THEN 1 ELSE 0 END AS [Closed referrals - person moved / requested discharge],
	CASE WHEN r.ServDischDate IS NOT NULL AND r.ReferClosReason IN ('05','09') THEN 1 ELSE 0 END AS [Closed referrals - DNA / refused to be seen],
	CASE WHEN r.ServDischDate IS NOT NULL AND cu.Der_CumulativeContacts IS NOT NULL AND r.ReferClosReason = '08' THEN 1 ELSE 0 END AS [Closed referrals signposted],
	CASE WHEN r.ServDischDate IS NOT NULL AND (r.ReferClosReason NOT IN ('01','02','03','04','05','07','08','09') OR r.ReferClosReason IS NULL) THEN 1 ELSE 0 END AS [Closed referrals - other reason / unknown],

	CASE WHEN r.ServDischDate IS NOT NULL AND cu.Der_CumulativeContacts = 1 THEN 1 ELSE 0 END AS [Closed with one contact],
	CASE WHEN r.ServDischDate IS NOT NULL AND cu.Der_CumulativeContacts > 1 THEN 1 ELSE 0 END AS [Closed with two or more contacts],
	CASE WHEN r.ServDischDate IS NOT NULL AND (cu.Der_CumulativeContacts IS NULL OR cu.Der_CumulativeContacts = 0) THEN 1 ELSE 0 END AS [No contacts offered / attended],

	-- get referral length for referrals closed in month, inc categories
	CASE WHEN r.ServDischDate IS NOT NULL AND DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ServDischDate) BETWEEN 0 and 27 THEN 1 ELSE 0 END AS [Referral length - less than four weeks],
	CASE WHEN r.ServDischDate IS NOT NULL AND DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ServDischDate) BETWEEN 28 and 182 THEN 1 ELSE 0 END AS [Referral length - one to six months],
	CASE WHEN r.ServDischDate IS NOT NULL AND DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ServDischDate) BETWEEN 183 AND 365 THEN 1 ELSE 0 END AS [Referral length - six to 12 months],
	CASE WHEN r.ServDischDate IS NOT NULL AND DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ServDischDate) BETWEEN 366 AND 730 THEN 1 ELSE 0 END AS [Referral length - one to two years],
	CASE WHEN r.ServDischDate IS NOT NULL AND DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ServDischDate) > 730 THEN 1 ELSE 0 END AS [Referral length - two years or more],

	-- get referral not accepted measures, inc duration
	CASE WHEN r.ReferRejectionDate IS NOT NULL THEN 1 ELSE 0 END AS [Referrals not accepted],
	CASE WHEN r.ReferRejectionDate IS NOT NULL AND r.ReferRejectReason = 02 THEN 1 ELSE 0 END AS [Referrals not accepted - alternative service required],
	CASE WHEN r.ReferRejectionDate IS NOT NULL AND r.ReferRejectReason = 01 THEN 1 ELSE 0 END AS [Referrals not accepted - duplicate],
	CASE WHEN r.ReferRejectionDate IS NOT NULL AND r.ReferRejectReason = 03 THEN 1 ELSE 0 END AS [Referrals not accepted - incomplete],
	CASE WHEN r.ReferRejectionDate IS NOT NULL AND (r.ReferRejectReason NOT IN (01,02,03) OR r.ReferRejectReason IS NULL) THEN 1 ELSE 0 
		END AS [Referrals not accepted - missing / invalid],
	CASE WHEN r.ReferRejectionDate IS NOT NULL THEN DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ReferRejectionDate) END AS [Referrals not accepted length],

	-- get days since last contact measures, inc categories, limited to open referrals at month end
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND DATEDIFF(dd,cu.Der_LastContact,r.ReportingPeriodEndDate) BETWEEN 0 and 6 THEN 1 ELSE 0 END AS [Time since last contact - less than one week],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND DATEDIFF(dd,cu.Der_LastContact,r.ReportingPeriodEndDate) BETWEEN 7 and 13 THEN 1 ELSE 0 END AS [Time since last contact - one to two weeks],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND DATEDIFF(dd,cu.Der_LastContact,r.ReportingPeriodEndDate) BETWEEN 14 and 27 THEN 1 ELSE 0 END AS [Time since last contact - two to four weeks],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND DATEDIFF(dd,cu.Der_LastContact,r.ReportingPeriodEndDate) >27 THEN 1 ELSE 0 END AS [Time since last contact - four weeks or more],
	
	-- get in month activity counts
	ag.Der_InMonthContacts AS [Attended contacts],
	ag.Der_InMonthDNAContacts AS [DNA'd contacts],
	ag.Der_InMonthCancelledContacts AS [Cancelled contacts],
	ag.Der_InMonthIndirectContacts AS [Indirect contacts],
	ag.Der_InMonthInvalidContacts AS [Unknown / Invalid attendance code],
	ag.Der_InMonthF2FContacts AS [Face to face contacts],
	ag.Der_InMonthTeleContacts AS [Telephone contacts],
	ag.Der_InMonthOtherContacts AS [Contacts via other mediums],
	ag.Der_InMonthInvalidContacts AS [Unknown / Invalid consultation medium],
	ag.Der_ContactDuration AS [Duration of clinical contact],
	b.BedDays AS [Days spent as an inpatient],
	CASE WHEN b.BedDays >0 THEN 1 ELSE 0 END AS [People who spent time as an inpatient],
	
	-- get outcome measures
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_CumulativeContacts >=1 AND a.HoNOSRecordedMoreThanOnce = 0 THEN a.HoNOSRecordedOnce END AS [HoNOS recorded once],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_CumulativeContacts >=1 THEN a.HoNOSRecordedMoreThanOnce END AS [HoNOS recorded more than once],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_CumulativeContacts >=1 AND a.HoNOSRecordedOnce = 0 THEN 1 ELSE 0 END AS [HoNOS never recorded],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_CumulativeContacts >=1 AND a.DIALOGRecordedMoreThanOnce = 0 THEN a.DIALOGRecordedOnce END AS [DIALOG recorded once],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_CumulativeContacts >=1 THEN a.DIALOGRecordedMoreThanOnce END AS [DIALOG recorded more than once],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_CumulativeContacts >=1 AND a.DIALOGRecordedOnce = 0 THEN 1 ELSE 0 END AS [DIALOG never recorded],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_CumulativeContacts >=1 AND a.QPRRecordedMoreThanOnce = 0 THEN a.QPRRecordedOnce END AS [QPR recorded once],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_CumulativeContacts >=1 THEN a.QPRRecordedMoreThanOnce END AS [QPR recorded more than once],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_CumulativeContacts >=1 AND a.QPRRecordedOnce = 0 THEN 1 ELSE 0 END AS [QPR never recorded],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_CumulativeContacts >=1 AND a.TwoMeasuresTwice >0 THEN 1 ELSE 0 END AS [People with at least 2 outcome measures recorded at least twice],
	--HoNOS initial scores
	s.BEH_Ini, s.INJ_Ini, s.SUB_Ini, s.COG_Ini, s.ILL_Ini, s.HAL_Ini, s.DEP_Ini, s.OTH_Ini, s.REL_Ini, s.ADL_Ini, s.LIV_Ini, s.OCC_Ini,
	--DIALOG initial scores
	s.MEN_Ini, s.PHY_Ini, s.JOB_Ini, s.ACC_Ini, s.LEI_Ini, s.FRD_Ini, s.PRT_Ini, s.SAF_Ini, s.MED_Ini, s.PRA_Ini, s.CON_Ini,
	-- QPR initial score
	s.QPR_Ini,
	-- HoNOS final scores
	s.BEH_Fin, s.INJ_Fin, s.SUB_Fin, s.COG_Fin, s.ILL_Fin, s.HAL_Fin, s.DEP_Fin, s.OTH_Fin, s.REL_Fin, s.ADL_Fin, s.LIV_Fin, s.OCC_Fin,
	--DIALOG final scores
	s.MEN_Fin, s.PHY_Fin, s.JOB_Fin, s.ACC_Fin, s.LEI_Fin, s.FRD_Fin, s.PRT_Fin, s.SAF_Fin, s.MED_Fin, s.PRA_Fin, s.CON_Fin,
	--QPR final score
	s.QPR_Fin,
	
	CASE WHEN s.PairedHoNOS >= 1 THEN 1 ELSE 0 END AS [Closed referrals with a paired HoNOS],
	CASE WHEN s.PairedDialog >= 1 THEN 1 ELSE 0 END AS [Closed referrals with a paired DIALOG],
	CASE WHEN s.PairedQPR >= 1 THEN 1 ELSE 0 END AS [Closed referrals with a paired QPR],
	
	-- get aggregate SNoMED measures
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND p.AnySNoMED > 0 THEN 1 ELSE 0 END AS [Referrals with any SNoMED codes],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND p.NICESNoMED > 0 THEN 1 ELSE 0 END AS [Referrals with NICE concordant SNoMED codes]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Master

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Ref r 

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AssAgg a ON r.Person_ID = a.Person_ID AND r.UniqServReqID = a.UniqServReqID AND r.ReportingPeriodEndDate = a.ReportingPeriodEndDate AND r.CareProfTeamID = a.CareProfTeamID

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_ProcAgg p ON r.RecordNumber = p.RecordNumber AND r.UniqServReqID = p.UniqServReqID 

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_BedDays b ON r.RecordNumber = b.RecordNumber

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Score s ON r.Person_ID = s.Person_ID AND r.UniqServReqID = s.UniqServReqID AND r.ReferralRequestReceivedDate >= '2016-01-01' AND r.ServDischDate IS NOT NULL

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_DataDic_ZZZ_ReasonForReferralToMentalHealth rr ON r.PrimReasonReferralMH = rr.Main_Code_Text COLLATE DATABASE_DEFAULT AND rr.Effective_To IS NULL AND rr.Valid_To IS NULL

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_Deprivation_By_LSOA] l ON r.LSOA2011 = l.LSOA_Code AND l.Effective_Snapshot_Date = '2019-12-31'

LEFT JOIN [NHSE_UKHF].[Data_Dictionary].[vw_Ethnic_Category_Code_SCD] e ON r.EthnicCategory = e.[Main_Code_Text] COLLATE DATABASE_DEFAULT AND e.Is_Latest = 1

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_DataDic_ZZZ_PersonGender] g ON r.Gender = g.Person_Gender_Code

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_Other_ComCodeChanges cc ON r.OrgIDCCGRes = cc.Org_Code

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies h ON r.OrgIDProv = h.Organisation_Code

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Commissioner_Hierarchies c ON COALESCE(cc.New_Code,r.OrgIDCCGRes) = c.Organisation_Code

LEFT JOIN [NHSE_Sandbox_MentalHealth].[dbo].[Reference_ONS_CCG_lkp] ons ON ons.CCG21CDH = COALESCE(cc.New_Code,r.OrgIDCCGRes) 

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Agg ag ON ag.RecordNumber = r.RecordNumber AND ag.UniqServReqID = r.UniqServReqID

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Cumulative cu ON cu.RecordNumber = r.RecordNumber AND cu.UniqServReqID = r.UniqServReqID

WHERE r.UniqMonthID BETWEEN @StartRP AND @EndRP

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
BUILD CORE SNoMED TABLE
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--if OBJECT_ID('NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_SNoCORE') is not null
--DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_SNoCORE

--SELECT
--	m.ReportingPeriodEndDate,
--	m.[Local team identifier],
--	m.[Provider code],
--	m.[Provider name],
--	m.[CCG code],
--	m.[CCG name],
--	m.[STP code],
--	m.[STP name],
--	m.[Region code],
--	m.[Region name],
--	m.[Primary reason for referral],
--	m.[Age category]

--INTO NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_SNoCORE

--FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Master m

--LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Activity a ON m.Person_ID = a.Person_ID AND m.UniqServReqID = a.UniqServReqID AND a.ReportingPeriodEndDate <= m.ReportingPeriodEndDate 

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE CORE DASHBOARD
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AggMainDash') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AggMainDash

SELECT
	m.ReportingPeriodEndDate,
	m.[Local team identifier],
	m.[Provider code],
	m.[Provider name],
	m.[CCG code],
	m.[CCG name],
	m.[CCG ONS code],
	m.[STP code],
	m.[STP name],
	m.[STP ONS code],
	m.[Region code],
	m.[Region name],
	m.[Region ONS code],
	m.[Primary reason for referral],
	m.[Age category],

	SUM([Open referrals]) AS [Open referrals],	
	SUM([Total caseload]) AS [Total caseload],

	SUM([People on the caseload aged 13 and under]) AS [People on the caseload aged 13 and under],
	SUM([People on the caseload aged 14-17]) AS [People on the caseload aged 14-17],
	SUM([People on the caseload aged 18-35]) AS [People on the caseload aged 18-35],
	SUM([People on the caseload aged 36 and over]) AS [People on the caseload aged 36 and over],
	
	SUM([New referrals]) AS [New referrals],
	SUM([Closed referrals]) AS [Closed referrals],
	SUM([Closed referrals - treatment complete / further treatment not appropriate]) AS [Closed referrals - treatment complete / further treatment not appropriate],
	SUM([Closed referrals - admitted / referred elsewhere]) AS [Closed referrals - admitted / referred elsewhere],
	SUM([Closed referrals - person moved / requested discharge]) AS [Closed referrals - person moved / requested discharge],
	SUM([Closed referrals - DNA / refused to be seen]) AS [Closed referrals - DNA / refused to be seen],
	SUM([Closed referrals - other reason / unknown]) AS [Closed referrals - other reason / unknown],
	SUM([Closed referrals signposted]) AS [Closed referrals signposted],
	SUM([Closed with one contact]) AS [Closed with one contact],
	SUM([Closed with two or more contacts]) AS [Closed with two or more contacts],
	SUM([No contacts offered / attended]) AS [No contacts offered / attended],
	
	SUM([Referral length - less than four weeks]) AS [Referral length - less than four weeks],
	SUM([Referral length - one to six months]) AS [Referral length - one to six months],
	SUM([Referral length - six to 12 months]) AS [Referral length - six to 12 months],
	SUM([Referral length - one to two years]) AS [Referral length - one to two years],
	SUM([Referral length - two years or more]) AS [Referral length - two years or more],

	SUM([Referrals not accepted]) AS [Referrals not accepted],
	SUM([Referrals not accepted - alternative service required]) AS [Referrals not accepted - alternative service required],
	SUM([Referrals not accepted - duplicate]) AS [Referrals not accepted - duplicate],
	SUM([Referrals not accepted - incomplete]) AS [Referrals not accepted - incomplete],
	SUM([Referrals not accepted - missing / invalid]) AS [Referrals not accepted - missing / invalid],
	SUM([Referrals not accepted length]) AS [Referrals not accepted length],
	
	SUM([Time since last contact - less than one week]) AS [Time since last contact - less than one week],
	SUM([Time since last contact - one to two weeks]) AS [Time since last contact - one to two weeks],
	SUM([Time since last contact - two to four weeks]) AS [Time since last contact - two to four weeks],
	SUM([Time since last contact - four weeks or more]) AS [Time since last contact - four weeks or more],
	
	SUM([Attended contacts]) AS [Attended contacts],
	SUM([DNA'd contacts]) AS [DNA'd contacts],
	SUM([Cancelled contacts]) AS [Cancelled contacts],
	SUM([Indirect contacts]) AS [Indirect contacts],
	SUM([Unknown / Invalid attendance code]) AS [Unknown / Invalid attendance code],
	SUM([Face to face contacts]) AS [Face to face contacts],
	SUM([Telephone contacts]) AS [Telephone contacts],
	SUM([Contacts via other mediums]) AS [Contacts via other mediums],
	SUM([Unknown / Invalid consultation medium]) AS [Unknown / Invalid consultation medium],
	SUM([Duration of clinical contact]) AS [Duration of clinical contact],
	SUM([Days spent as an inpatient]) AS [Days spent as an inpatient],
	SUM([People who spent time as an inpatient]) AS [People who spent time as an inpatient],

	SUM([HoNOS recorded once]) AS [HoNOS recorded once],
	SUM([HoNOS recorded more than once]) AS [HoNOS recorded more than once],
	SUM([HoNOS never recorded]) AS [HoNOS never recorded],
	SUM([DIALOG recorded once]) AS [DIALOG recorded once],
	SUM([DIALOG recorded more than once]) AS [DIALOG recorded more than once],
	SUM([DIALOG never recorded]) AS [DIALOG never recorded],
	SUM([QPR recorded once]) AS [QPR recorded once],
	SUM([QPR recorded more than once]) AS [QPR recorded more than once],
	SUM([QPR never recorded]) AS [QPR never recorded],
	SUM([People with at least 2 outcome measures recorded at least twice]) AS [People with at least 2 outcome measures recorded at least twice],
	SUM([Closed referrals with a paired HoNOS]) AS [Closed referrals with a paired HoNOS],
	SUM([Closed referrals with a paired DIALOG]) AS [Closed referrals with a paired DIALOG],
	SUM([Closed referrals with a paired QPR]) AS [Closed referrals with a paired QPR],
	
	SUM(BEH_Ini) AS [BEH initial],
	SUM(INJ_Ini) AS [INJ initial],
	SUM(SUB_Ini) AS [SUB initial],
	SUM(COG_Ini) AS [COG initial],
	SUM(ILL_Ini) AS [ILL initial],
	SUM(HAL_Ini) AS [HAL initial],
	SUM(DEP_Ini) AS [DEP initial],
	SUM(OTH_Ini) AS [OTH initial],
	SUM(REL_Ini) AS [REL initial],
	SUM(ADL_Ini) AS [ADL initial],
	SUM(LIV_Ini) AS [LIV initial],
	SUM(OCC_Ini) AS [OCC initial],

	SUM(MEN_Ini) AS [MEN initial],
	SUM(PHY_Ini) AS [PHY initial],
	SUM(JOB_Ini) AS [JOB initial],
	SUM(ACC_Ini) AS [ACC initial],
	SUM(LEI_Ini) AS [LEI initial],
	SUM(FRD_Ini) AS [FRD initial],
	SUM(PRT_Ini) AS [PRT initial],
	SUM(SAF_Ini) AS [SAF initial],
	SUM(MED_Ini) AS [MED initial],
	SUM(PRA_Ini) AS [PRA initial],
	SUM(CON_Ini) AS [CON initial],
	
	SUM(QPR_Ini) AS [QPR initial],
	
	SUM(BEH_Fin) AS [BEH final],
	SUM(INJ_Fin) AS [INJ final],
	SUM(SUB_Fin) AS [SUB final],
	SUM(COG_Fin) AS [COG final],
	SUM(ILL_Fin) AS [ILL final],
	SUM(HAL_Fin) AS [HAL final],
	SUM(DEP_Fin) AS [DEP final],
	SUM(OTH_Fin) AS [OTH final],
	SUM(REL_Fin) AS [REL final],
	SUM(ADL_Fin) AS [ADL final],
	SUM(LIV_Fin) AS [LIV final],
	SUM(OCC_Fin) AS [OCC final],
	
	SUM(MEN_Fin) AS [MEN final],
	SUM(PHY_Fin) AS [PHY final],
	SUM(JOB_Fin) AS [JOB final],
	SUM(ACC_Fin) AS [ACC final],
	SUM(LEI_Fin) AS [LEI final],
	SUM(FRD_Fin) AS [FRD final],
	SUM(PRT_Fin) AS [PRT final],
	SUM(SAF_Fin) AS [SAF final],
	SUM(MED_Fin) AS [MED final],
	SUM(PRA_Fin) AS [PRA final],
	SUM(CON_Fin) AS [CON final],
	
	SUM(QPR_Fin) AS [QPR final],
	
	SUM([Referrals with any SNoMED codes]) AS [Referrals with any SNoMED codes],
	SUM([Referrals with NICE concordant SNoMED codes]) AS [Referrals with NICE concordant SNoMED codes],

	-- duplicate measures for denominator in tableau
	SUM([Closed referrals with a paired HoNOS]) AS [Closed referrals with a paired HoNOS2],
	SUM([Closed referrals with a paired DIALOG]) AS [Closed referrals with a paired DIALOG2],
	SUM([Closed referrals with a paired QPR]) AS [Closed referrals with a paired QPR2],
	SUM([Total caseload]) AS [Caseload2]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AggMainDash

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Master m

GROUP BY m.ReportingPeriodEndDate, m.[Local team identifier], m.[Provider code], m.[Provider name], m.[CCG code], m.[CCG name], m.[CCG ONS code], m.[STP code], m.[STP name], m.[STP ONS code], m.[Region code], m.[Region name], m.[Region ONS code],
	m.[Primary reason for referral], m.[Age category]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE IN MONTH SNoMED
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Agg2') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Agg2

SELECT
	m.ReportingPeriodEndDate,
	m.[Local team identifier],
	m.[Provider code],
	m.[Provider name],
	m.[CCG code],
	m.[CCG name],
	m.[CCG ONS code],
	m.[STP code],
	m.[STP name],
	m.[STP ONS code],
	m.[Region code],
	m.[Region name],
	m.[Region ONS code],
	m.[Primary reason for referral],
	m.[Age category],
	a.[Intervention type],
	a.Der_SNoMEDTerm AS [SNoMED term],
	COUNT(a.Der_SNoMEDTerm) AS [Number of interventions]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Agg2

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Master m

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Activity a ON m.Person_ID = a.Person_ID AND m.UniqServReqID = a.UniqServReqID AND a.ReportingPeriodEndDate = m.ReportingPeriodEndDate 

GROUP BY m.ReportingPeriodEndDate, m.[Local team identifier], m.[Provider code], m.[Provider name], m.[CCG code], m.[CCG name], m.[CCG ONS code], m.[STP code], m.[STP name], m.[STP ONS code], m.[Region code], m.[Region name], m.[Region ONS code],
	m.[Primary reason for referral], m.[Age category], a.[Intervention type], a.Der_SNoMEDTerm

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
UNPIVOT AND CREATE ACTIVITY EXTRACT
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DELETE FROM [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EIPTT] WHERE [Data source] LIKE 'MHSDS%'

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EIPTT]

SELECT
	ReportingPeriodEndDate,
	[Local team identifier],
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
	[CCG ONS code],
	[STP code],
	[STP name],
	[STP ONS code],
	[Region code],
	[Region name],
	[Region ONS code],
	[Primary reason for referral],
	[Age category],
	'MHSDS - Activity' AS [Data source],
	'Core Dashboard' AS [Dashboard type],
	'ENGLAND' AS Breakdown,
	NULL AS [Breakdown category],
	MeasureName,
	MeasureValue,
	CASE 
		WHEN MeasureName LIKE '%SNoMED codes' THEN [Caseload2]
		WHEN MeasureName LIKE '%recorded%' THEN [Caseload2]
		WHEN MeasureName = 'Duration of clinical contact' THEN [Caseload2]
		WHEN MeasureName = 'Days spent as an inpatient' THEN [People who spent time as an inpatient]
		WHEN MeasureName = 'BEH initial' THEN [Closed referrals with a paired HoNOS2]
		WHEN MeasureName = 'INJ initial' THEN [Closed referrals with a paired HoNOS2]
		WHEN MeasureName = 'SUB initial' THEN [Closed referrals with a paired HoNOS2]
		WHEN MeasureName = 'COG initial' THEN [Closed referrals with a paired HoNOS2]
		WHEN MeasureName = 'ILL initial' THEN [Closed referrals with a paired HoNOS2]
		WHEN MeasureName = 'HAL initial' THEN [Closed referrals with a paired HoNOS2]
		WHEN MeasureName = 'DEP initial' THEN [Closed referrals with a paired HoNOS2]
		WHEN MeasureName = 'OTH initial' THEN [Closed referrals with a paired HoNOS2]
		WHEN MeasureName = 'REL initial' THEN [Closed referrals with a paired HoNOS2]
		WHEN MeasureName = 'ADL initial' THEN [Closed referrals with a paired HoNOS2]
		WHEN MeasureName = 'LIV initial' THEN [Closed referrals with a paired HoNOS2]
		WHEN MeasureName = 'OCC initial' THEN [Closed referrals with a paired HoNOS2]
		WHEN MeasureName = 'MEN initial' THEN [Closed referrals with a paired DIALOG2]
		WHEN MeasureName = 'PHY initial' THEN [Closed referrals with a paired DIALOG2]
		WHEN MeasureName = 'JOB initial' THEN [Closed referrals with a paired DIALOG2]
		WHEN MeasureName = 'ACC initial' THEN [Closed referrals with a paired DIALOG2]
		WHEN MeasureName = 'LEI initial' THEN [Closed referrals with a paired DIALOG2]
		WHEN MeasureName = 'FRD initial' THEN [Closed referrals with a paired DIALOG2]
		WHEN MeasureName = 'PRT initial' THEN [Closed referrals with a paired DIALOG2]
		WHEN MeasureName = 'SAF initial' THEN [Closed referrals with a paired DIALOG2]
		WHEN MeasureName = 'MED initial' THEN [Closed referrals with a paired DIALOG2]
		WHEN MeasureName = 'PRA initial' THEN [Closed referrals with a paired DIALOG2]
		WHEN MeasureName = 'CON initial' THEN [Closed referrals with a paired DIALOG2]
		WHEN MeasureName = 'QPR initial' THEN [Closed referrals with a paired QPR2]
	END AS Denominator,
	CASE
		WHEN MeasureName = 'BEH initial' THEN [BEH final]
		WHEN MeasureName = 'INJ initial' THEN [INJ final]
		WHEN MeasureName = 'SUB initial' THEN [SUB final]
		WHEN MeasureName = 'COG initial' THEN [COG final]
		WHEN MeasureName = 'ILL initial' THEN [ILL final]
		WHEN MeasureName = 'HAL initial' THEN [HAL final]
		WHEN MeasureName = 'DEP initial' THEN [DEP final]
		WHEN MeasureName = 'OTH initial' THEN [OTH final]
		WHEN MeasureName = 'REL initial' THEN [REL final]
		WHEN MeasureName = 'ADL initial' THEN [ADL final]
		WHEN MeasureName = 'LIV initial' THEN [LIV final]
		WHEN MeasureName = 'OCC initial' THEN [OCC final]
		WHEN MeasureName = 'MEN initial' THEN [MEN final]
		WHEN MeasureName = 'PHY initial' THEN [PHY final]
		WHEN MeasureName = 'JOB initial' THEN [JOB final]
		WHEN MeasureName = 'ACC initial' THEN [ACC final]
		WHEN MeasureName = 'LEI initial' THEN [LEI final]
		WHEN MeasureName = 'FRD initial' THEN [FRD final]
		WHEN MeasureName = 'PRT initial' THEN [PRT final]
		WHEN MeasureName = 'SAF initial' THEN [SAF final]
		WHEN MeasureName = 'MED initial' THEN [MED final]
		WHEN MeasureName = 'PRA initial' THEN [PRA final]
		WHEN MeasureName = 'CON initial' THEN [CON final]
		WHEN MeasureName = 'QPR initial' THEN [QPR final]
		END AS UpperLimit,
	NULL AS LowerLimit

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AggMainDash 

UNPIVOT (MeasureValue FOR MeasureName IN 
	([Total caseload],[Open referrals],[People on the caseload aged 13 and under],[People on the caseload aged 14-17],[People on the caseload aged 18-35],[People on the caseload aged 36 and over],
	[New referrals],
	
	[Closed referrals],[Closed referrals - treatment complete / further treatment not appropriate],[Closed referrals - admitted / referred elsewhere],[Closed referrals - person moved / requested discharge],
	[Closed referrals - DNA / refused to be seen],[Closed referrals - other reason / unknown],[Closed referrals signposted],[Closed with one contact],[Closed with two or more contacts],[No contacts offered / attended],
	[Referral length - less than four weeks],[Referral length - one to six months],[Referral length - six to 12 months],[Referral length - one to two years],[Referral length - two years or more],[Referrals not accepted],
	[Referrals not accepted - alternative service required],[Referrals not accepted - duplicate],[Referrals not accepted - incomplete],[Referrals not accepted - missing / invalid],[Referrals not accepted length],
	
	[Time since last contact - less than one week],[Time since last contact - one to two weeks],[Time since last contact - two to four weeks],[Time since last contact - four weeks or more],[Attended contacts],[DNA'd contacts],
	[Cancelled contacts],[Indirect contacts],[Unknown / Invalid attendance code],[Face to face contacts],[Telephone contacts],[Contacts via other mediums],[Unknown / Invalid consultation medium],[Days spent as an inpatient],
	[Duration of clinical contact],

	[HoNOS recorded once],[HoNOS recorded more than once],[HoNOS never recorded],[DIALOG recorded once],[DIALOG recorded more than once],[DIALOG never recorded],[QPR recorded once],[QPR recorded more than once],[QPR never recorded],
	[People with at least 2 outcome measures recorded at least twice],

	[Closed referrals with a paired HoNOS],[BEH initial],[INJ initial],[SUB initial],[COG initial],[ILL initial],[HAL initial],[DEP initial],[OTH initial],[REL initial],[ADL initial],[LIV initial],[OCC initial],
	[MEN initial],[PHY initial],[JOB initial],[ACC initial],[LEI initial],[FRD initial],[PRT initial],[SAF initial],[MED initial],[PRA initial],[CON initial],[QPR initial],[Referrals with any SNoMED codes],[Referrals with NICE concordant SNoMED codes])) u

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EIPTT]

SELECT 
	ReportingPeriodEndDate,
	[Local team identifier],
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
	[CCG ONS code],
	[STP code],
	[STP name],
	[STP ONS code],
	[Region code],
	[Region name],
	[Region ONS code],
	[Primary reason for referral],
	[Age category],
	'MHSDS - Activity' AS [Data source],
	'SNoMED' AS [Dashboard type],
	[Intervention type] AS Breakdown,
	[SNoMED term] AS [Breakdown category],
	'Number of interventions' AS MeasureName,
	[Number of interventions] AS MeasureValue,
	NULL AS Denominator,
	NULL AS UpperLimit,
	NULL AS LowerLimit

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Agg2

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EIPTT]

SELECT
	ReportingPeriodEndDate,
	NULL AS [Local team identifier],
	NULL AS [Provider code],
	NULL AS [Provider name],
	[CCG code],
	[CCG name],
	[CCG ONS code],
	[STP code],
	[STP name],
	[STP ONS code],
	[Region code],
	[Region name],
	[Region ONS code],
	NULL AS [Primary reason for referral],
	NULL AS [Age category],
	'MHSDS - Demo' AS [Data source],
	'Ethnicity' AS [Dashboard type],
	'Ethnicity' AS Breakdown,
	m.Ethnicity AS [Breakdown category],
	'Caseload' AS MeasureName,
	SUM([Total caseload]) AS MeasureValue,
	NULL AS Denominator,
	NULL AS UpperLimit,
	NULL AS LowerLimit

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Master m

GROUP BY m.ReportingPeriodEndDate, [CCG code],	[CCG name],	[CCG ONS code],	[STP code],	[STP name],	[STP ONS code],m.[Region code], m.[Region name], [Region ONS code], m.Ethnicity

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EIPTT]

SELECT
	ReportingPeriodEndDate,
	NULL AS [Local team identifier],
	NULL AS [Provider code],
	NULL AS [Provider name],
	[CCG code],
	[CCG name],
	[CCG ONS code],
	[STP code],
	[STP name],
	[STP ONS code],
	[Region code],
	[Region name],
	[Region ONS code],
	NULL AS [Primary reason for referral],
	NULL AS [Age category],
	'MHSDS - Demo' AS [Data source],
	'Gender' AS [Dashboard type],
	'Gender' AS Breakdown,
	m.Gender AS [Breakdown category],
	'Caseload' AS MeasureName,
	SUM([Total caseload]) AS MeasureValue,
	NULL AS Denominator,
	NULL AS UpperLimit,
	NULL AS LowerLimit

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Master m

GROUP BY m.ReportingPeriodEndDate, [CCG code],	[CCG name],	[CCG ONS code],	[STP code],	[STP name],	[STP ONS code],m.[Region code], m.[Region name], [Region ONS code], m.Gender

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EIPTT]

SELECT
	ReportingPeriodEndDate,
	NULL AS [Local team identifier],
	NULL AS [Provider code],
	NULL AS [Provider name],
	[CCG code],
	[CCG name],
	[CCG ONS code],
	[STP code],
	[STP name],
	[STP ONS code],
	[Region code],
	[Region name],
	[Region ONS code],
	NULL AS [Primary reason for referral],
	NULL AS [Age category],
	'MHSDS - Demo' AS [Data source],
	'IMD' AS [Dashboard type],
	'IMD' AS Breakdown,
	m.IMD_Decile AS [Breakdown category],
	'Caseload' AS MeasureName,
	SUM([Total caseload]) AS MeasureValue,
	NULL AS Denominator,
	NULL AS UpperLimit,
	NULL AS LowerLimit

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_Master m

GROUP BY m.ReportingPeriodEndDate, [CCG code],	[CCG name],	[CCG ONS code],	[STP code],	[STP name],	[STP ONS code],m.[Region code], m.[Region name], [Region ONS code], m.IMD_Decile

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET PUBLISHED AWT DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AWTPrep') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AWTPrep

SELECT 
	m.Reporting_Period_End AS [ReportingPeriodEndDate],
	m.Breakdown AS [Organisation type],
	CAST(m.Primary_Level AS varchar (20)) AS [Organisation code],
	
	SUM(CASE WHEN m.Measure_ID = 'eip23b' THEN m.Measure_Value END) AS [Two week clock stops],
	SUM(CASE WHEN m.Measure_ID = 'eip23a' THEN m.Measure_Value END) AS [All clock stops],
	SUM(CASE WHEN m.Measure_ID = 'eip23e' THEN m.Measure_Value END) AS [Referrals waiting <2 Weeks],
	SUM(CASE WHEN m.Measure_ID = 'eip23f' THEN m.Measure_Value END) AS [Referrals waiting >2 Weeks],
	SUM(CASE WHEN m.Measure_ID = 'eip23d' THEN m.Measure_Value END) AS [All referrals still waiting],

	--Duplicate for denominators
	SUM(CASE WHEN m.Measure_ID = 'eip23a' THEN m.Measure_Value END) AS [All clock stops2],
	SUM(CASE WHEN m.Measure_ID = 'eip23d' THEN m.Measure_Value END) AS [All referrals still waiting2]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AWTPrep

FROM NHSE_Sandbox_MentalHealth.dbo.Staging_UnsuppressedMHSDSPublicationFiles m 

WHERE m.Measure_ID IN ('eip23a', 'eip23b', 'eip23d', 'eip23e', 'eip23f')

GROUP BY m.Reporting_Period_End, m.Breakdown, m.Primary_Level

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
INSERT ENGLAND AND PROVIDER DATA INTO EXTRACT TABLE
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EIPTT] 

SELECT
	ReportingPeriodEndDate,
	NULL AS [Local team identifier],
	NULL AS [Provider code],
	NULL AS [Provider name],
	NULL AS [CCG code],
	NULL AS [CCG name],
	NULL AS [CCG ONS code],
	NULL AS [STP code],
	NULL AS [STP name],
	NULL AS [STP ONS code],
	NULL AS [Region code],
	NULL AS [Region name],
	NULL AS [Region ONS code],
	NULL AS [Primary reason for referral],
	NULL AS [Age category],
	'MHSDS - AWT' AS [Data source],
	'AWT' AS [Dashboard type],
	'ENGLAND' AS Breakdown,
	'AWT' AS [Breakdown category],
	MeasureName,
	MeasureValue,
	CASE 
		WHEN MeasureName = 'Two week clock stops' THEN [All clock stops2]
		WHEN MeasureName = 'Referrals waiting >2 Weeks' THEN [All referrals still waiting2] 
	END AS Denominator,
	NULL AS UpperLimit,
	NULL AS LowerLimit

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AWTPrep a

UNPIVOT (MeasureValue FOR MeasureName IN ([All clock stops],[Two week clock stops],[Referrals waiting <2 Weeks],[Referrals waiting >2 Weeks],[All referrals still waiting])) c

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies p ON p.Organisation_Code = [Organisation code] COLLATE DATABASE_DEFAULT 

WHERE [Organisation type] = 'ENGLAND'

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EIPTT]

SELECT
	ReportingPeriodEndDate,
	NULL AS [Local team identifier],
	[Organisation code] AS [Provider code],
	p.Organisation_Name AS [Provider name],
	NULL AS [CCG code],
	NULL AS [CCG name],
	NULL AS [CCG ONS code],
	NULL AS [STP code],
	NULL AS [STP name],
	NULL AS [STP ONS code],
	NULL AS [Region code],
	NULL AS [Region name],
	NULL AS [Region ONS code],
	NULL AS [Primary reason for referral],
	NULL AS [Age category],
	'MHSDS - AWT' AS [Data source],
	'AWT' AS [Dashboard type],
	'PROVIDER' AS Breakdown,
	'AWT' AS [Breakdown category],
	MeasureName,
	MeasureValue,
	CASE 
		WHEN MeasureName = 'Two week clock stops' THEN [All clock stops2]
		WHEN MeasureName = 'Referrals waiting >2 Weeks' THEN [All referrals still waiting2] 
	END AS Denominator,
	NULL AS UpperLimit,
	NULL AS LowerLimit

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AWTPrep a

UNPIVOT (MeasureValue FOR MeasureName IN ([All clock stops],[Two week clock stops],[Referrals waiting <2 Weeks],[Referrals waiting >2 Weeks],[All referrals still waiting])) c

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies p ON p.Organisation_Code = [Organisation code] COLLATE DATABASE_DEFAULT 

WHERE [Organisation type] = 'PROVIDER'

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
MAP TO NEW CCG CODES AND STP / REGION
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AWTCCG') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AWTCCG

SELECT 
	m.ReportingPeriodEndDate,
	COALESCE(cc.New_Code, m.[Organisation code] COLLATE DATABASE_DEFAULT ) AS [CCG code],
	COALESCE(c.Organisation_Name,'Missing / Invalid') AS [CCG name],
	COALESCE(c.STP_Code,'Missing / Invalid') AS [STP code],
	COALESCE(c.STP_Name,'Missing / Invalid') AS [STP name],
	COALESCE(c.Region_Code,'Missing / Invalid') AS [Region code],
	COALESCE(c.Region_Name,'Missing / Invalid') AS [Region name],
	CASE WHEN cc.New_Code IS NULL THEN 1 ELSE 0 END AS [No CCG change],

	m.[Two week clock stops],
	m.[All clock stops],
	m.[Referrals waiting <2 Weeks],
	m.[Referrals waiting >2 Weeks],
	m.[All referrals still waiting],
	m.[All clock stops2],
	m.[All referrals still waiting2]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AWTCCG

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AWTPrep m 

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges] cc ON m.[Organisation code] = cc.Org_Code COLLATE DATABASE_DEFAULT 

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Commissioner_Hierarchies c ON COALESCE(cc.New_Code, m.[Organisation code]) = c.Organisation_Code COLLATE DATABASE_DEFAULT 

WHERE [Organisation type] = 'CCG - GP Practice or Residence'

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CALCULATE VALUES FOR NEW CCGS / REGIONS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AWTNewCCG') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AWTNewCCG

SELECT
	a.ReportingPeriodEndDate,
	a.[CCG code],
	a.[CCG name],
	a.[STP code],
	a.[STP name],
	a.[Region code],
	a.[Region name],
	
	SUM(a.[Two week clock stops]) AS [Two week clock stops],
	SUM(a.[All clock stops]) AS [All clock stops],
	SUM(a.[Referrals waiting <2 Weeks]) AS [Referrals waiting <2 Weeks],
	SUM(a.[Referrals waiting >2 Weeks]) AS [Referrals waiting >2 Weeks],
	SUM(a.[All referrals still waiting]) AS [All referrals still waiting],
	SUM(a.[All clock stops2]) AS [All clock stops2],
	SUM(a.[All referrals still waiting2]) AS [All referrals still waiting2]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AWTNewCCG

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AWTCCG a

GROUP BY a.ReportingPeriodEndDate,a.[CCG code],a.[CCG name],a.[STP code],a.[STP name],a.[Region code],a.[Region name], a.[No CCG change]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
INSERT INTO EXTRACT
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EIPTT]

SELECT
	ReportingPeriodEndDate,
	NULL AS [Local team identifier],
	NULL AS [Provider code],
	NULL AS [Provider name],
	NULL AS [CCG code],
	NULL AS [CCG name],
	NULL AS [CCG ONS code],
	NULL AS [STP code],
	NULL AS [STP name],
	NULL AS [STP ONS code],
	[Region code],
	[Region name],
	NULL AS [Region ONS code],
	NULL AS [Primary reason for referral],
	NULL AS [Age category],
	'MHSDS - AWT' AS [Data source],
	'AWT' AS [Dashboard type],
	'REGION' AS Breakdown,
	'AWT' AS [Breakdown category],
	MeasureName,
	SUM(MeasureValue) AS MeasureValue,
	SUM(CASE 
		WHEN MeasureName = 'Two week clock stops' THEN [All clock stops2]
		WHEN MeasureName = 'Referrals waiting >2 Weeks' THEN [All referrals still waiting2] 
	END) AS Denominator,
	NULL AS UpperLimit,
	NULL AS LowerLimit

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AWTNewCCG a

UNPIVOT (MeasureValue FOR MeasureName IN ([All clock stops],[Two week clock stops],[Referrals waiting <2 Weeks],[Referrals waiting >2 Weeks],[All referrals still waiting])) c

GROUP BY ReportingPeriodEndDate, [Region code],	[Region name], MeasureName

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EIPTT]

SELECT
	ReportingPeriodEndDate,
	NULL AS [Local team identifier],
	NULL AS [Provider code],
	NULL AS [Provider name],
	NULL AS [CCG code],
	NULL AS [CCG name],
	NULL AS [CCG ONS code],
	[STP code],
	[STP name],
	NULL AS [STP ONS code],
	NULL AS [Region code],
	NULL AS [Region name],
	NULL AS [Region ONS code],
	NULL AS [Primary reason for referral],
	NULL AS [Age category],
	'MHSDS - AWT' AS [Data source],
	'AWT' AS [Dashboard type],
	'STP' AS Breakdown,
	'AWT' AS [Breakdown category],
	MeasureName,
	SUM(MeasureValue) AS MeasureValue,
	SUM(CASE 
		WHEN MeasureName = 'Two week clock stops' THEN [All clock stops2]
		WHEN MeasureName = 'Referrals waiting >2 Weeks' THEN [All referrals still waiting2] 
	END) AS Denominator,
	NULL AS UpperLimit,
	NULL AS LowerLimit

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AWTNewCCG a

UNPIVOT (MeasureValue FOR MeasureName IN ([All clock stops],[Two week clock stops],[Referrals waiting <2 Weeks],[Referrals waiting >2 Weeks],[All referrals still waiting])) c

GROUP BY ReportingPeriodEndDate, [STP code], [STP name], MeasureName

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EIPTT]

SELECT
	ReportingPeriodEndDate,
	NULL AS [Local team identifier],
	NULL AS [Provider code],
	NULL AS [Provider name],
	[CCG code],
	[CCG name],
	NULL AS [CCG ONS code],
	NULL AS [STP code],
	NULL AS [STP name],
	NULL AS [STP ONS code],
	NULL AS [Region code],
	NULL AS [Region name],
	NULL AS [Region ONS code],
	NULL AS [Primary reason for referral],
	NULL AS [Age category],
	'MHSDS - AWT' AS [Data source],
	'AWT' AS [Dashboard type],
	'CCG' AS Breakdown,
	'AWT' AS [Breakdown category],
	MeasureName,
	MeasureValue,
	CASE 
		WHEN MeasureName = 'Two week clock stops' THEN [All clock stops2]
		WHEN MeasureName = 'Referrals waiting >2 Weeks' THEN [All referrals still waiting2] 
	END AS Denominator,
	NULL AS UpperLimit,
	NULL AS LowerLimit

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_EIP_AWTNewCCG a

UNPIVOT (MeasureValue FOR MeasureName IN ([All clock stops],[Two week clock stops],[Referrals waiting <2 Weeks],[Referrals waiting >2 Weeks],[All referrals still waiting])) c

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
MANUALLY AMEND MHSDS ORG NAMES TO MATCH THOSE IN
THE NCAP AUDIT
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

UPDATE [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EIPTT]

SET [Provider name] = 'FORWARD THINKING BIRMINGHAM'

WHERE [Provider code] = 'RQ3'

UPDATE [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EIPTT]

SET [Provider name] = 'INSIGHT TEAM, PLYMOUTH'

WHERE [Provider code] IN ('NR5','NKD')

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
DROP TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_EIP_Activity
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_EIP_Agg
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_EIP_Agg2
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_EIP_AggMainDash
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_EIP_Ass
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_EIP_AssAgg
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_EIP_AssOrder
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_EIP_AWTCCG
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_EIP_AWTNewCCG
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_EIP_AWTPrep
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_EIP_BedDays
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_EIP_Cumulative
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_EIP_FandL
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_EIP_Master
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_EIP_ProcAgg
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_EIP_Ref
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_EIP_Score

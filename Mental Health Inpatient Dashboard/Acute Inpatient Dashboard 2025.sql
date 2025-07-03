/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ACUTE DASHBOARD v.3 (2022)

CREATED BY TOM BARDSLEY 10 NOVEMBER 2022
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DECLARE @RP_START INT
DECLARE @RP_END INT
DECLARE @RP_STARTDATE DATE
DECLARE @RP_ENDDATE DATE

SET @RP_START = 1429 
SET @RP_END = (SELECT MAX(UniqMonthID) FROM MHDInternal.PreProc_Header)

SET @RP_STARTDATE = (SELECT MIN(ReportingPeriodStartDate) FROM MHDInternal.PreProc_Header WHERE UniqMonthID = @RP_START)
SET @RP_ENDDATE = (SELECT MAX(ReportingPeriodEndDate) FROM MHDInternal.PreProc_Header WHERE UniqMonthID = @RP_END)


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET LATEST PATIENT INDICATORS FOR LD AND AUTISM STATUS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_PatInd') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_PatInd

SELECT DISTINCT
EFFECTIVE_FROM
,MHS005UniqID
,OrgIDProv
,Person_ID
,Der_Person_ID
,RecordNumber
,p.UniqMonthID
,p.UniqSubmissionID
,p.NHSEUniqSubmissionID
,AutismStatus
,LDStatus
INTO MHDInternal.Temp_AcuteDash_PatInd
FROM MESH_MHSDS.MHS005PatInd p
INNER JOIN MESH_MHSDS.MHSDS_SubmissionFlags s ON p.NHSEUniqSubmissionID = s.NHSEUniqSubmissionID AND s.Der_IsLatest = 'Y' 
WHERE p.UniqMonthID BETWEEN @RP_START AND @RP_END





/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET FIRST WARD STAY PER SPELL x MONTH
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_FirstWS') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_FirstWS

SELECT DISTINCT 
	i.UniqHospProvSpellNum
	,i.Person_ID
	,i.UniqServReqID
	,i.UniqMonthID
	,i.RecordNumber
	,i.ReportingPeriodStartDate
	,i.ReportingPeriodEndDate
	,i.OrgIDProv
	,i.StartDateHospProvSpell
	,i.StartTimeHospProvSpell
	,i.DischDateHospProvSpell
	,i.AdmMethCodeHospProvSpell
	,i.DischMethCodeHospProvSpell
	,i.SourceAdmCodeHospProvSpell
	,i.DischDestCodeHospProvSpell
	,i.EstimatedDischDateHospProvSpell
	,i.DecidedToAdmitDate
	,i.DecidedToAdmitTime
	,r.AgeRepPeriodEnd
	,r.EthnicCategory
	,r.Gender
	,NULLIF(r.LSOA2011,'') AS LSOA2011
	,r.Der_SubICBCode
	,r.OrgIDCCGRes
	,ia.UniqWardStayID AS UniqWardStayID_first 
	,ia.StartDateWardStay AS StartDateWardStay_first 
	,ia.StartTimeWardStay AS StartTimeWardStay_first 
	,ia.UniqMonthID AS WS_UniqMonthID_first
	,CASE WHEN ia.HospitalBedTypeMH = '10' THEN '200'
	WHEN ia.HospitalBedTypeMH = '11' THEN '201' 
	WHEN ia.HospitalBedTypeMH = '12' THEN '202' 
	WHEN ia.HospitalBedTypeMH = '13' THEN '203'  
	WHEN ia.HospitalBedTypeMH = '14' THEN '204' 
	WHEN ia.HospitalBedTypeMH = '15' THEN '205'
	WHEN ia.HospitalBedTypeMH = '17' THEN '17' --V5 code, only applicable to data pre April 24
	WHEN ia.HospitalBedTypeMH = '19' THEN '206'
	WHEN ia.HospitalBedTypeMH = '20' THEN '207'
	WHEN ia.HospitalBedTypeMH = '21' THEN '208' 
	WHEN ia.HospitalBedTypeMH = '22' THEN '209'
	WHEN ia.HospitalBedTypeMH = '40' THEN '210' 
	WHEN ia.HospitalBedTypeMH = '39' THEN '211' 
	WHEN ia.HospitalBedTypeMH = '35' THEN '35' --V5 code mapped to '212' OR '213' in v6 (not 1:1)
	WHEN ia.HospitalBedTypeMH = '36' THEN '36' --V5 code mapped to '212' OR '213' in v6 (not 1:1)
	WHEN ia.HospitalBedTypeMH = '37' THEN '37' --V5 code mapped to '212' OR '213' in v6 (not 1:1)
	WHEN ia.HospitalBedTypeMH = '38' THEN '38' --V5 code mapped to '212' OR '213' in v6 (not 1:1)
	WHEN ia.HospitalBedTypeMH = '23' THEN '300'
	WHEN ia.HospitalBedTypeMH = '24' THEN '301' 
	WHEN ia.HospitalBedTypeMH IN ('25','26') THEN '302' 
	WHEN ia.HospitalBedTypeMH = '27' THEN '303' 
	WHEN ia.HospitalBedTypeMH = '28' THEN '304'  
	WHEN ia.HospitalBedTypeMH = '29' THEN '305' 
	WHEN ia.HospitalBedTypeMH = '31' THEN '306' 
	WHEN ia.HospitalBedTypeMH = '32' THEN '307'
	WHEN ia.HospitalBedTypeMH = '33' THEN '308' 
	WHEN ia.HospitalBedTypeMH = '34' THEN '309' 
	WHEN ia.HospitalBedTypeMH = '30' THEN '30' --V5 code mapped to '310' OR '311' in V6 (not 1:1)
	ELSE ia.HospitalBedTypeMH
	END AS HospitalBedTypeMH_first --maps v5 codes to v6
	,ia.WardLocDistanceHome
	,p.LDStatus
	,p.AutismStatus
	
INTO MHDInternal.Temp_AcuteDash_FirstWS

FROM MHDInternal.PreProc_Inpatients i  

LEFT JOIN MHDInternal.PreProc_Referral r ON i.RecordNumber = r.RecordNumber AND i.UniqServReqID = r.UniqServReqID -- needs to be changed to MHDInternal.PreProc_Referral eventually

LEFT JOIN MHDInternal.PreProc_Inpatients ia ON i.UniqHospProvSpellNum = ia.UniqHospProvSpellNum AND i.UniqServReqID = ia.UniqServReqID and i.Person_ID = ia.Person_ID
	AND ia.Der_FirstWardStayRecord = 1 --- get ward stay of admission 

LEFT JOIN MHDInternal.Temp_AcuteDash_PatInd p ON i.Person_ID = p.Der_Person_ID AND i.RecordNumber = p.RecordNumber
	
WHERE i.UniqMonthID BETWEEN @RP_START AND @RP_END


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET LATEST WARD STAY PER HOSPITAL SPELL x MONTH
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_LatestWard') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_LatestWard

SELECT 
	s.UniqHospProvSpellNum
	,s.UniqServReqID
	,s.Person_ID
	,s.UniqMonthID
	,i.UniqWardStayID
	,i.RecordNumber
	,i.StartDateWardStay
	,i.StartTimeWardStay
	,i.EndDateWardStay
	,i.EndTimeWardStay
	,CASE WHEN i.HospitalBedTypeMH = '10' THEN '200'
	WHEN i.HospitalBedTypeMH = '11' THEN '201' 
	WHEN i.HospitalBedTypeMH = '12' THEN '202' 
	WHEN i.HospitalBedTypeMH = '13' THEN '203'  
	WHEN i.HospitalBedTypeMH = '14' THEN '204' 
	WHEN i.HospitalBedTypeMH = '15' THEN '205'
	WHEN i.HospitalBedTypeMH = '17' THEN '17' --V5 code, only applicable to data pre April 24
	WHEN i.HospitalBedTypeMH = '19' THEN '206'
	WHEN i.HospitalBedTypeMH = '20' THEN '207'
	WHEN i.HospitalBedTypeMH = '21' THEN '208' 
	WHEN i.HospitalBedTypeMH = '22' THEN '209'
	WHEN i.HospitalBedTypeMH = '40' THEN '210' 
	WHEN i.HospitalBedTypeMH = '39' THEN '211' 
	WHEN i.HospitalBedTypeMH = '35' THEN '35' --V5 code mapped to '212' OR '213' in v6 (not 1:1)
	WHEN i.HospitalBedTypeMH = '36' THEN '36' --V5 code mapped to '212' OR '213' in v6 (not 1:1)
	WHEN i.HospitalBedTypeMH = '37' THEN '37' --V5 code mapped to '212' OR '213' in v6 (not 1:1)
	WHEN i.HospitalBedTypeMH = '38' THEN '38' --V5 code mapped to '212' OR '213' in v6 (not 1:1)
	WHEN i.HospitalBedTypeMH = '23' THEN '300'
	WHEN i.HospitalBedTypeMH = '24' THEN '301' 
	WHEN i.HospitalBedTypeMH IN ('25','26') THEN '302' 
	WHEN i.HospitalBedTypeMH = '27' THEN '303' 
	WHEN i.HospitalBedTypeMH = '28' THEN '304'  
	WHEN i.HospitalBedTypeMH = '29' THEN '305' 
	WHEN i.HospitalBedTypeMH = '31' THEN '306' 
	WHEN i.HospitalBedTypeMH = '32' THEN '307'
	WHEN i.HospitalBedTypeMH = '33' THEN '308' 
	WHEN i.HospitalBedTypeMH = '34' THEN '309' 
	WHEN i.HospitalBedTypeMH = '30' THEN '30' --V5 code mapped to '310' OR '311' in V6 (not 1:1)
	ELSE i.HospitalBedTypeMH
	END AS HospitalBedTypeMH --maps v5 codes to v6
	,i.MHS502UniqID
	,i.WardLocDistanceHome
	,i.SiteIDOfTreat
	,ROW_NUMBER () OVER(PARTITION BY i.Person_ID, i.UniqServReqID, i.UniqHospProvSpellNum, i.UniqMonthID ORDER BY ISNULL(i.EndDateWardStay,'2100-12-31') DESC, i.MHS502UniqID DESC) AS WS_Order

INTO MHDInternal.Temp_AcuteDash_LatestWard

FROM MHDInternal.Temp_AcuteDash_FirstWS s

INNER JOIN MHDInternal.PreProc_Inpatients i ON i.UniqHospProvSpellNum = s.UniqHospProvSpellNum 
	AND i.UniqServReqID = s.UniqServReqID 
	AND i.Person_ID = s.Person_ID
	AND i.UniqMonthID = s.UniqMonthID


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET DIAGNOSES FOR INPATIENT SPELLS 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_Diag') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_Diag

SELECT 
	h.UniqHospProvSpellNum
	,h.Person_ID
	,h.UniqServReqID
	,h.RecordNumber
	,p.CodedDiagTimestamp AS DiagDate
	,'Primary' AS DiagType 
	,LEFT(REPLACE((REPLACE(p.PrimDiag, '.','')),'X','0'),3) AS Diag
	,ROW_NUMBER()OVER(PARTITION BY h.UniqHospProvSpellNum, h.RecordNumber ORDER BY p.CodedDiagTimestamp DESC, p.MHS604UniqID DESC) AS RN --- get latest diagnosis that month

INTO MHDInternal.Temp_AcuteDash_Diag

FROM MHDInternal.Temp_AcuteDash_FirstWS h 

INNER JOIN MESH_MHSDS.MHS604PrimDiag p ON p.UniqServReqID = h.UniqServReqID AND p.CodedDiagTimestampDatetime <= h.ReportingPeriodEndDate --- LOCF 
INNER JOIN MESH_MHSDS.MHSDS_SubmissionFlags f ON p.NHSEUniqSubmissionID = f.NHSEUniqSubmissionID AND f.Der_IsLatest = 'Y' 

WHERE p.DiagSchemeInUse = '02' -- ICD-10 codes only 
AND LEFT(p.PrimDiag,1) = 'F' -- MH diagnoses only 



/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
COMBINE INTO FINAL SPELL-LEVEL TABLE 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_Spells') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_Spells

SELECT 
	a.UniqHospProvSpellNum
	,a.Person_ID
	,a.UniqServReqID
	,a.UniqMonthID
	,a.RecordNumber
	,a.ReportingPeriodStartDate
	,a.ReportingPeriodEndDate
	,a.OrgIDProv
	,a.StartDateHospProvSpell
	,a.StartTimeHospProvSpell
	,a.DischDateHospProvSpell
	,a.AdmMethCodeHospProvSpell
	,a.DischMethCodeHospProvSpell
	,a.SourceAdmCodeHospProvSpell
	,a.DischDestCodeHospProvSpell
	,CASE 
		WHEN(a.DischMethCodeHospProvSpell NOT IN ('4','6','7','8') OR a.DischMethCodeHospProvSpell IS NULL) THEN 1 
	ELSE 0 END AS Der_ReAdm_Flag1 -- readmissions denom flag  
	,CASE 
		WHEN(a.DischDestCodeHospProvSpell NOT IN ('48','49','50','53','84','87','79') OR a.DischDestCodeHospProvSpell IS NULL) THEN 1 
	ELSE 0 END AS Der_ReAdm_Flag2 -- readmissions denom flag   
	,a.DecidedToAdmitDate
	,a.DecidedToAdmitTime
	,a.EstimatedDischDateHospProvSpell
	,a.AgeRepPeriodEnd
	,a.EthnicCategory
	,a.Gender
	,a.LSOA2011
	,a.Der_SubICBCode
	,a.OrgIDCCGRes
	-- WS at admission 
	,a.UniqWardStayID_first 
	,a.StartDateWardStay_first 
	,a.StartTimeWardStay_first 
	,a.WS_UniqMonthID_first
	,a.HospitalBedTypeMH_first 
	,CASE 
		WHEN a.HospitalBedTypeMH_first IN ('17','35','36','37','38','30') THEN CONCAT('V5: ',COALESCE(w1b.NationalCodeDefinition, w1.Main_Description_60_Chars),' (only applicable before April 2024)')
		ELSE CONCAT('V6: ',COALESCE(w1b.NationalCodeDefinition, w1.Main_Description_60_Chars,'Missing/Invalid'))
		END AS BedType_first
	,CASE 
		WHEN a.HospitalBedTypeMH_first IN ('10','11','12','200','201','202') THEN 'Adult Acute (ICB commissioned)' 
		WHEN a.HospitalBedTypeMH_first IN ('13','14','15','16','17','18','19','20','21','22','35','36','37','38','39','40','203','204','205','206','207','208','209','210','211','212','213') THEN 'Adult Specialist' 
		WHEN a.HospitalBedTypeMH_first IN ('23','24','25','26','27','28','29','30','31','32','33','34','300','301','302','303','304','305','306','307','308','309','310','311') THEN 'CYP' 
		ELSE 'Missing/Invalid' 
	END as BedType_first_Category
	,a.WardLocDistanceHome AS WardLocDistanceHome_first
	,a.LDStatus
	,a.AutismStatus
	-- Latest WS 
	,z.UniqWardStayID AS UniqWardStayID_last
	,z.StartDateWardStay AS StartDateWardStay_last
	,z.StartTimeWardStay AS StartTimeWardStay_last
	,z.UniqMonthID AS WS_UniqMonthID_last
	,z.HospitalBedTypeMH AS HospitalBedTypeMH_last
	,CASE 
		WHEN z.HospitalBedTypeMH IN ('17','35','36','37','38','30') THEN CONCAT('V5: ',COALESCE(w2b.NationalCodeDefinition, w2.Main_Description_60_Chars),' (only applicable before April 2024)')
		ELSE CONCAT('V6: ',COALESCE(w2b.NationalCodeDefinition, w2.Main_Description_60_Chars,'Missing/Invalid'))
		END AS BedType_last
	,CASE 
		WHEN z.HospitalBedTypeMH IN ('10','11','12','200','201','202') THEN 'Adult Acute (ICB commissioned)' 
		WHEN z.HospitalBedTypeMH IN ('13','14','15','16','17','18','19','20','21','22','35','36','37','38','39','40','203','204','205','206','207','208','209','210','211','212','213') THEN 'Adult Specialist' 
		WHEN z.HospitalBedTypeMH IN ('23','24','25','26','27','28','29','30','31','32','33','34','300','301','302','303','304','305','306','307','308','309','310','311') THEN 'CYP' 
		ELSE 'Missing/Invalid' 
		END as BedType_last_Category
	,z.WardLocDistanceHome AS WardLocDistanceHome_last
	,z.SiteIDOfTreat AS SiteIDOfTreat_last
	-- Derivations 
	,CASE WHEN a.StartDateHospProvSpell BETWEEN a.ReportingPeriodStartDate AND a.ReportingPeriodEndDate THEN 1 ELSE 0 END AS Der_Admission 
	,CASE WHEN a.DischDateHospProvSpell BETWEEN a.ReportingPeriodStartDate AND a.ReportingPeriodEndDate THEN 1 ELSE 0 END AS Der_Discharge 
	,CASE WHEN a.DischDateHospProvSpell IS NULL OR a.DischDateHospProvSpell > a.ReportingPeriodEndDate THEN 1 ELSE 0 END AS Der_Open 
	,DATEDIFF(DD, a.StartDateHospProvSpell, a.DischDateHospProvSpell)+1 AS Der_LOS -- closed spells only 
	,CASE 
		WHEN a.StartDateHospProvSpell < a.ReportingPeriodStartDate AND a.DischDateHospProvSpell BETWEEN a.ReportingPeriodStartDate AND a.ReportingPeriodEndDate THEN DATEDIFF(DD, a.ReportingPeriodStartDate, a.DischDateHospProvSpell) 
		WHEN a.StartDateHospProvSpell < a.ReportingPeriodStartDate AND a.DischDateHospProvSpell NOT BETWEEN a.ReportingPeriodStartDate AND a.ReportingPeriodEndDate THEN DATEDIFF(DD, a.ReportingPeriodStartDate, a.ReportingPeriodEndDate)+1
		WHEN a.StartDateHospProvSpell < a.ReportingPeriodStartDate AND a.DischDateHospProvSpell IS NULL THEN DATEDIFF(DD, a.ReportingPeriodStartDate, a.ReportingPeriodEndDate)+1
		WHEN a.StartDateHospProvSpell >= a.ReportingPeriodStartDate AND DischDateHospProvSpell BETWEEN a.ReportingPeriodStartDate AND a.ReportingPeriodEndDate THEN DATEDIFF(DD, a.StartDateHospProvSpell, a.DischDateHospProvSpell)
		WHEN a.StartDateHospProvSpell >= a.ReportingPeriodStartDate AND a.DischDateHospProvSpell NOT BETWEEN a.ReportingPeriodStartDate AND a.ReportingPeriodEndDate THEN DATEDIFF(DD, a.StartDateHospProvSpell, a.ReportingPeriodEndDate)+1
		WHEN a.StartDateHospProvSpell >= a.ReportingPeriodStartDate AND a.DischDateHospProvSpell IS NULL THEN DATEDIFF(DD, a.StartDateHospProvSpell, a.ReportingPeriodEndDate)+1
	END AS Der_RP_BedDays 
	,d.DiagDate
	,d.Diag AS PrimDiag 

INTO MHDInternal.Temp_AcuteDash_Spells

FROM MHDInternal.Temp_AcuteDash_FirstWS a

INNER JOIN MHDInternal.Temp_AcuteDash_LatestWard z ON a.UniqHospProvSpellNum = z.UniqHospProvSpellNum 
	AND a.UniqServReqID = z.UniqServReqID 
	AND a.Person_ID = z.Person_ID
	AND a.UniqMonthID = z.UniqMonthID
	AND z.WS_Order = 1 

LEFT JOIN [UKHD_Data_Dictionary].[Mental_Health_Admitted_Patient_Classification_SCD_1] w1 ON a.HospitalBedTypeMH_first = w1.Main_Code_Text COLLATE DATABASE_DEFAULT AND w1.Is_Latest = 1
LEFT JOIN MHDInternal.Reference_MHSDSv6_BedTypes w1b ON a.HospitalBedTypeMH_first = w1b.MHAdmittedPatientClass 
LEFT JOIN [UKHD_Data_Dictionary].[Mental_Health_Admitted_Patient_Classification_SCD_1] w2 ON z.HospitalBedTypeMH = w2.Main_Code_Text COLLATE DATABASE_DEFAULT AND w2.Is_Latest = 1
LEFT JOIN MHDInternal.Reference_MHSDSv6_BedTypes w2b ON z.HospitalBedTypeMH = w2b.MHAdmittedPatientClass 

LEFT JOIN MHDInternal.Temp_AcuteDash_Diag d ON a.UniqHospProvSpellNum = d.UniqHospProvSpellNum AND a.RecordNumber = d.RecordNumber AND d.RN = 1 




/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
GET PREVIOUS CONTACTS FOR PEOPLE ADMITTED IN THE RP 	
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/	

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_PrevContact') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_PrevContact

SELECT 
	s.UniqHospProvSpellNum
	,s.Person_ID
	,s.StartDateHospProvSpell
	,a.Der_ActivityUniqID
	,a.Der_ContactDate
	,DATEDIFF(DAY, a.Der_ContactDate, s.StartDateHospProvSpell) As DateDiffCont
	,ROW_NUMBER() OVER(PARTITION BY s.UniqHospProvSpellNum ORDER BY a.Der_ContactDate DESC) AS RN

INTO MHDInternal.Temp_AcuteDash_PrevContact

FROM MHDInternal.Temp_AcuteDash_Spells s 

INNER JOIN MHDInternal.PreProc_Activity a ON s.Person_ID = a.Person_ID 
	AND DATEDIFF(DAY, a.Der_ContactDate, s.StartDateHospProvSpell) <= 365 
	AND DATEDIFF(DAY, a.Der_ContactDate, s.StartDateHospProvSpell) > 2 
	AND Der_Contact = 1 

LEFT JOIN MESH_MHSDS.MHS501HospProvSpell h ON a.Person_ID = h.Der_Person_ID AND a.RecordNumber = h.RecordNumber AND a.UniqServReqID = h.UniqServReqID 
	AND h.UniqHospProvSpellID IS NULL 

WHERE s.Der_Admission = 1 


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
GET READMISSIONS FOR DISCHARGED SPELLS  	
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/	

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_ReAdm') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_ReAdm

SELECT 
	s.Person_ID
	,s.RecordNumber
	,s.UniqHospProvSpellNum AS Index_HS
	,s.StartDateHospProvSpell AS Index_StartDate
	,s.DischDateHospProvSpell AS Index_DischDate
	,a.UniqHospProvSpellNum
	,a.StartDateHospProvSpell 
	,DATEDIFF(DD, s.DischDateHospProvSpell, a.StartDateHospProvSpell) AS TimetoReadm 
	,ROW_NUMBER()OVER(PARTITION BY s.Person_ID, s.UniqHospProvSpellNum ORDER BY a.StartDateHospProvSpell ASC) AS FirstReAdm -- earliest readmission per index
	,ROW_NUMBER()OVER(PARTITION BY a.Person_ID, a.UniqHospProvSpellNum ORDER BY s.DischDateHospProvSpell DESC) AS LastDisch -- most recent discharge per (re)admission 

INTO MHDInternal.Temp_AcuteDash_ReAdm

FROM MHDInternal.Temp_AcuteDash_Spells s  

INNER JOIN MHDInternal.Temp_AcuteDash_Spells a ON s.Person_ID = a.Person_ID
	AND a.StartDateHospProvSpell >= s.DischDateHospProvSpell
	AND a.Der_Admission = 1 
	AND a.UniqHospProvSpellNum <> s.UniqHospProvSpellNum 

WHERE s.Der_Discharge = 1 
AND s.Der_ReAdm_Flag1 = 1 
AND s.Der_ReAdm_Flag2 = 1 


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
GET PERIODS OF HOME LEAVE  	
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/	

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_HomeLeave') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_HomeLeave

SELECT 
	s.UniqHospProvSpellNum
	,s.RecordNumber
	,COUNT(*) AS HL_periods
	,SUM(hl.HomeLeaveDaysEndRP) AS HomeLeaveDaysEndRP

INTO MHDInternal.Temp_AcuteDash_HomeLeave

FROM MHDInternal.Temp_AcuteDash_Spells s 

INNER JOIN MESH_MHSDS.MHS509HomeLeave hl ON s.UniqHospProvSpellNum = hl.UniqHospProvSpellID AND s.RecordNumber = hl.RecordNumber
INNER JOIN MESH_MHSDS.MHSDS_SubmissionFlags f ON hl.NHSEUniqSubmissionID = f.NHSEUniqSubmissionID AND f.Der_IsLatest = 'Y'

GROUP BY s.UniqHospProvSpellNum, s.RecordNumber 


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
GET PERIODS OF ABSENCE WITHOUT LEAVE 	
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/	

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_LeaveofAbsence') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_LeaveofAbsence

SELECT 
	s.UniqHospProvSpellNum
	,s.RecordNumber
	,COUNT(*) AS LOA_periods
	,SUM(la.LOADaysRP) AS LOADaysRP

INTO MHDInternal.Temp_AcuteDash_LeaveofAbsence

FROM MHDInternal.Temp_AcuteDash_Spells s 

INNER JOIN MESH_MHSDS.MHS510LeaveOfAbsence la ON s.UniqHospProvSpellNum = la.UniqHospProvSpellID AND s.RecordNumber = la.RecordNumber
INNER JOIN MESH_MHSDS.MHSDS_SubmissionFlags f ON la.NHSEUniqSubmissionID = f.NHSEUniqSubmissionID AND f.Der_IsLatest = 'Y'

GROUP BY s.UniqHospProvSpellNum, s.RecordNumber 



/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
GET RESTRICTIVE INTERVENTIONS 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/	

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_Restraint') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_Restraint

SELECT
	r1.UniqHospProvSpellNum 
	,r1.RecordNumber
	,COUNT(*) AS [RI total] 
	,SUM(CASE WHEN r1.RestrictiveIntType IN ('01','02','07','08','09','10','11','12','13') THEN 1 ELSE 0 END) AS [Physical restraint] 
	,SUM(CASE WHEN r1.RestrictiveIntType IN ('04') THEN 1 ELSE 0 END) AS [Mechanical restraint]
	,SUM(CASE WHEN r1.RestrictiveIntType IN ('14','15','16','17','03') THEN 1 ELSE 0 END) AS [Chemical restraint]
	,SUM(CASE WHEN r1.RestrictiveIntType IN ('05','06') THEN 1 ELSE 0 END) AS [Seclusion or Segregation]

INTO MHDInternal.Temp_AcuteDash_Restraint

FROM MESH_MHSDS.MHS505RestrictiveIntervention r1 
INNER JOIN MESH_MHSDS.MHSDS_SubmissionFlags f ON r1.NHSEUniqSubmissionID = f.NHSEUniqSubmissionID AND f.Der_IsLatest = 'Y' 

GROUP BY r1.UniqHospProvSpellNum, r1.RecordNumber

INSERT INTO MHDInternal.Temp_AcuteDash_Restraint

SELECT
	r1.UniqHospProvSpellID AS UniqHospProvSpellNum
	,r1.RecordNumber
	,COUNT(*) AS [RI total] 
	,SUM(CASE WHEN rt.RestrictiveIntType IN ('01','02','07','08','09','10','11','12','13') THEN 1 ELSE 0 END) AS [Physical restraint] 
	,SUM(CASE WHEN rt.RestrictiveIntType IN ('04') THEN 1 ELSE 0 END) AS [Mechanical restraint]
	,SUM(CASE WHEN rt.RestrictiveIntType IN ('14','15','16','17','03') THEN 1 ELSE 0 END) AS [Chemical restraint]
	,SUM(CASE WHEN rt.RestrictiveIntType IN ('05','06') THEN 1 ELSE 0 END) AS [Seclusion or Segregation]

FROM MESH_MHSDS.MHS505RestrictiveInterventInc r1 
INNER JOIN MESH_MHSDS.MHSDS_SubmissionFlags f ON r1.NHSEUniqSubmissionID = f.NHSEUniqSubmissionID AND f.Der_IsLatest = 'Y'  
LEFT JOIN MESH_MHSDS.MHS515RestrictiveInterventType rt ON r1.RecordNumber = rt.RecordNumber AND r1.UniqRestrictiveIntIncID = rt.UniqRestrictiveIntIncID 

GROUP BY r1.UniqHospProvSpellID, r1.RecordNumber


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
GET MHA BED DAYS 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_MHA') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_MHA

SELECT 
	h.UniqHospProvSpellNum
	,h.RecordNumber
	,h.StartDateHospProvSpell
	,h.DischDateHospProvSpell
	,CASE WHEN h.StartDateHospProvSpell < h.ReportingPeriodStartDate THEN h.ReportingPeriodStartDate ELSE h.StartDateHospProvSpell END AS Der_SpellStart 
	,ISNULL(h.DischDateHospProvSpell, h.ReportingPeriodEndDate) AS Der_SpellEnd 
	,h.ReportingPeriodStartDate
	,h.ReportingPeriodEndDate
	,m.UniqMHActEpisodeID
	,m.StartDateMHActLegalStatusClass
	,m.EndDateMHActLegalStatusClass
	,CASE WHEN m.StartDateMHActLegalStatusClass < h.ReportingPeriodStartDate THEN h.ReportingPeriodStartDate ELSE m.StartDateMHActLegalStatusClass END AS Der_MHAStart 
	,ISNULL(m.EndDateMHActLegalStatusClass, DATEADD(DD, -1,InactTimeMHAPeriod)) AS Der_MHAEndDate
	,m.ExpiryDateMHActLegalStatusClass
	,m.NHSDLegalStatus
	,DATEDIFF(DD, 
		(CASE WHEN (CASE WHEN h.StartDateHospProvSpell < h.ReportingPeriodStartDate THEN h.ReportingPeriodStartDate ELSE h.StartDateHospProvSpell END) 
		> (CASE WHEN m.StartDateMHActLegalStatusClass < h.ReportingPeriodStartDate THEN h.ReportingPeriodStartDate ELSE m.StartDateMHActLegalStatusClass END) 
		THEN (CASE WHEN h.StartDateHospProvSpell < h.ReportingPeriodStartDate THEN h.ReportingPeriodStartDate ELSE h.StartDateHospProvSpell END) ELSE (CASE WHEN m.StartDateMHActLegalStatusClass < h.ReportingPeriodStartDate THEN h.ReportingPeriodStartDate ELSE m.StartDateMHActLegalStatusClass END) END)
		
		, (CASE WHEN ISNULL(h.DischDateHospProvSpell, h.ReportingPeriodEndDate) < ISNULL(m.EndDateMHActLegalStatusClass, DATEADD(DD, -1,InactTimeMHAPeriod)) THEN ISNULL(h.DischDateHospProvSpell, h.ReportingPeriodEndDate) ELSE ISNULL(m.EndDateMHActLegalStatusClass, DATEADD(DD, -1,InactTimeMHAPeriod)) END )) MHA_BedDays -- +1 at the end of this line?

	,ROW_NUMBER()OVER(PARTITION BY UniqHospProvSpellNum, ReportingPeriodStartDate ORDER BY StartDateMHActLegalStatusClass) AS OrderMHA

INTO MHDInternal.Temp_AcuteDash_MHA

FROM MHDInternal.Temp_AcuteDash_Spells h  

INNER JOIN MESH_MHSDS.MHS401MHActPeriod m ON h.RecordNumber = m.RecordNumber AND h.OrgIDProv = m.OrgIDProv 
	AND m.StartDateMHActLegalStatusClass < ISNULL(h.DischDateHospProvSpell, h.ReportingPeriodEndDate)


WHERE m.NHSDLegalStatus IN ('02','03','07','08','09','10','12','13','14','15','16','17','18','31','32','37','38') -- hospital detentions 


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
GET CLINICALLY READY FOR DISCHARGE PERIODS 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_CRFD') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_CRFD

SELECT 
	c.UniqHospProvSpellID
	,f.ReportingPeriodStartDate
	,f.ReportingPeriodEndDate
	,c.RecordNumber
	,c.MHS518UniqID
	,c.StartDateClinReadyforDisch
	,c.EndDateClinReadyforDisch
	,c.AttribToIndic
	,c.ClinReadyforDischDelayReason
	,ROW_NUMBER()OVER(PARTITION BY c.UniqHospProvSpellID, c.UniqMonthID ORDER BY StartDateClinReadyforDisch ASC, MHS518UniqID ASC) AS rnk 
	,LAG(EndDateClinReadyforDisch,1) OVER(PARTITION BY UniqHospProvSpellID, c.UniqMonthID ORDER BY StartDateClinReadyforDisch ASC, MHS518UniqID ASC) AS LastEndDate 
	,(DATEDIFF(DD,	
		(CASE 
			WHEN StartDateClinReadyforDisch < ReportingPeriodStartDate THEN ReportingPeriodStartDate
			WHEN ROW_NUMBER()OVER(PARTITION BY c.UniqHospProvSpellID, c.UniqMonthID ORDER BY StartDateClinReadyforDisch ASC, MHS518UniqID ASC) = 1 AND StartDateClinReadyforDisch BETWEEN ReportingPeriodStartDate AND ReportingPeriodEndDate THEN DATEADD(DD,1,StartDateClinReadyforDisch)
			WHEN ROW_NUMBER()OVER(PARTITION BY c.UniqHospProvSpellID, c.UniqMonthID ORDER BY StartDateClinReadyforDisch ASC, MHS518UniqID ASC) <> 1 AND StartDateClinReadyforDisch BETWEEN ReportingPeriodStartDate AND ReportingPeriodEndDate AND StartDateClinReadyforDisch > DATEADD(DD,1,LAG(EndDateClinReadyforDisch,1) OVER(PARTITION BY UniqHospProvSpellID, c.UniqMonthID ORDER BY StartDateClinReadyforDisch ASC, MHS518UniqID ASC)) THEN DATEADD(DD,1,StartDateClinReadyforDisch)
			WHEN ROW_NUMBER()OVER(PARTITION BY c.UniqHospProvSpellID, c.UniqMonthID ORDER BY StartDateClinReadyforDisch ASC, MHS518UniqID ASC) <> 1 AND StartDateClinReadyforDisch BETWEEN ReportingPeriodStartDate AND ReportingPeriodEndDate THEN StartDateClinReadyforDisch
			ELSE '1900-01-01'
			END),
		(CASE WHEN EndDateClinReadyforDisch IS NULL THEN DATEADD(DD,1,ReportingPeriodEndDate) ELSE EndDateClinReadyforDisch END)	
			)) AS CRfD_Days 

INTO MHDInternal.Temp_AcuteDash_CRFD

FROM MESH_MHSDS.MHS518ClinReadyforDischarge c

INNER JOIN MESH_MHSDS.MHSDS_SubmissionFlags f ON c.NHSEUniqSubmissionID = f.NHSEUniqSubmissionID AND f.Der_IsLatest = 'Y'  

WHERE StartDateClinReadyforDisch <> ISNULL(EndDateClinReadyforDisch,'2424-01-01') -- exclude single day CRfD periods (why?) 


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
FINAL MASTER TABLE 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/	

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_Master') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_Master

SELECT
	s.UniqHospProvSpellNum
	,s.RecordNumber
	,s.UniqServReqID
	,s.Person_ID
	,s.ReportingPeriodStartDate
	,s.ReportingPeriodEndDate
	,s.AgeRepPeriodEnd
	,CASE 
		WHEN s.AgeRepPeriodEnd < 18 THEN '0-17'
		WHEN s.AgeRepPeriodEnd BETWEEN 18 AND 24 THEN '18-24'
		WHEN s.AgeRepPeriodEnd BETWEEN 25 AND 34 THEN '25-34'
		WHEN s.AgeRepPeriodEnd BETWEEN 35 AND 44 THEN '35-44'
		WHEN s.AgeRepPeriodEnd BETWEEN 45 AND 54 THEN '45-54'
		WHEN s.AgeRepPeriodEnd BETWEEN 55 AND 64 THEN '55-64'
		WHEN s.AgeRepPeriodEnd > 64 THEN '65+'
		ELSE 'Missing/Invalid'
		END AS AgeBand
	,CASE WHEN s.Gender = '1' THEN 'Male' WHEN s.Gender = '2' THEN 'Female' WHEN s.Gender = '9' THEN 'Indeterminate' WHEN s.Gender IN ('X','Z') THEN 'Not known/stated' ELSE 'Missing/invalid' END as Gender
	,CASE 
		WHEN s.EthnicCategory IS NULL THEN 'Missing/invalid'
		WHEN s.EthnicCategory = '' THEN 'Missing/invalid' 
		ELSE s.EthnicCategory 
		END AS Der_EthnicCat 
	,CASE 
		WHEN s.EthnicCategory = 'A' THEN 'White - British'
		WHEN s.EthnicCategory IN ('B') THEN 'White - Irish'
		WHEN s.EthnicCategory IN ('C') THEN 'White - Any other White background'
		WHEN s.EthnicCategory IN ('D') THEN 'Mixed - White and Black Caribbean'
		WHEN s.EthnicCategory IN ('E') THEN 'Mixed - White and Black African'
		WHEN s.EthnicCategory IN ('F') THEN 'Mixed - White and Asian'
		WHEN s.EthnicCategory IN ('G') THEN 'Mixed - Any other mixed background'
		WHEN s.EthnicCategory IN ('H') THEN 'Asian or Asian British - Indian'
		WHEN s.EthnicCategory IN ('J') THEN 'Asian or Asian British - Pakistani'
		WHEN s.EthnicCategory IN ('K') THEN 'Asian or Asian British - Bangladeshi'
		WHEN s.EthnicCategory IN ('L') THEN 'Asian or Asian British - Any other Asian background'
		WHEN s.EthnicCategory IN ('M') THEN 'Black or Black British - Caribbean'
		WHEN s.EthnicCategory IN ('N') THEN 'Black or Black British - African'
		WHEN s.EthnicCategory IN ('P') THEN 'Black or Black British - Any other Black background'
		WHEN s.EthnicCategory IN ('R') THEN 'Other Ethnic Groups - Chinese'
		WHEN s.EthnicCategory IN ('S') THEN 'Other Ethnic Groups - Any other ethnic group'
		WHEN s.EthnicCategory IN ('Z', '99') THEN 'Not stated/known'
		ELSE 'Missing/Invalid' END AS Der_EthnicFull
	,CASE 
		WHEN s.EthnicCategory = 'A' THEN 'White British'
		WHEN s.EthnicCategory IN ('B','C') THEN 'White Other'
		WHEN s.EthnicCategory IN ('D','E','F','G') THEN 'Mixed'
		WHEN s.EthnicCategory IN ('H','J','K','L') THEN 'Asian'
		WHEN s.EthnicCategory IN ('M','N','P') THEN 'Black'
		WHEN s.EthnicCategory IN ('R','S') THEN 'Other'
		ELSE 'Missing/Invalid' END AS UpperEthnicity
	,s.LSOA2011
	,CASE 
		WHEN dep.IMD_Decile = '1' THEN '01 Most deprived'
		WHEN dep.IMD_Decile = '2' THEN '02 More deprived'
		WHEN dep.IMD_Decile = '3' THEN '03 More deprived'
		WHEN dep.IMD_Decile = '4' THEN '04 More deprived'
		WHEN dep.IMD_Decile = '5' THEN '05 More deprived'
		WHEN dep.IMD_Decile = '6' THEN '06 Less deprived'
		WHEN dep.IMD_Decile = '7' THEN '07 Less deprived'
		WHEN dep.IMD_Decile = '8' THEN '08 Less deprived'
		WHEN dep.IMD_Decile = '9' THEN '09 Less deprived'
		WHEN dep.IMD_Decile = '10' THEN '10 Least deprived'
		ELSE 'Missing/invalid'
		END AS IMD_Decile
	,r1.[Description] AS Diagnosis
	,CASE WHEN r1.Category_1_Description = 'Mental retardation' THEN 'Intellectual disability' WHEN r1.Category_1_Description IS NULL THEN 'Missing/invalid' ELSE r1.Category_1_Description END AS DiagGroup 
	,s.OrgIDProv AS [Provider code]
	,p.Organisation_Name AS [Provider name]
	,CASE 
		WHEN s.Der_SubICBCode IN ('NONC','','UNK', 'X98') THEN 'Missing/invalid' 
		WHEN c.Organisation_Name IS NULL THEN 'Missing/invalid'
		WHEN c.Region_Code IN ('REG001','UNK','REG002') THEN 'Missing/invalid'
		ELSE COALESCE(cc.New_Code,s.Der_SubICBCode, 'Missing/Invalid') 
		END AS [subICB code]
	,CASE WHEN c.Region_Code IN ('REG001','UNK','REG002') THEN 'Missing/invalid' ELSE COALESCE(c.Organisation_Name,'Missing/invalid') END AS [subICB name]
	,CASE WHEN c.Region_Code IN ('REG001','UNK','REG002') THEN 'Missing/invalid' ELSE COALESCE(c.STP_Code,'Missing/invalid') END AS [ICB code]
	,CASE WHEN c.Region_Code IN ('REG001','UNK','REG002') THEN 'Missing/invalid' ELSE COALESCE(c.STP_Name,'Missing/invalid') END AS [ICB name]
	,CASE WHEN c.Region_Code IN ('REG001','UNK','REG002') THEN 'Missing/invalid' ELSE COALESCE(c.Region_Code,'Missing/invalid') END AS [Region code]
	,CASE WHEN c.Region_Code IN ('REG001','UNK','REG002') THEN 'Missing/invalid' ELSE COALESCE(c.Region_Name,'Missing/invalid') END AS [Region name]
	,s.StartDateHospProvSpell
	,s.StartTimeHospProvSpell
	,CAST(s.StartDateHospProvSpell AS DATETIME) + CAST(s.StartTimeHospProvSpell AS DATETIME) AS HospProvSpellStartDateTime
	,s.DischDateHospProvSpell
	,s.EstimatedDischDateHospProvSpell
	,s.AdmMethCodeHospProvSpell
	,CASE 
		WHEN s.AdmMethCodeHospProvSpell IN ('11','12','13') THEN 'Elective' -- known issues
		WHEN s.AdmMethCodeHospProvSpell IN ('21','2A') THEN 'Emergency - A&E' 
		WHEN s.AdmMethCodeHospProvSpell = '25' THEN 'Emergency - CRHT'
		WHEN s.AdmMethCodeHospProvSpell IN ('22','23','24','2B','2D') THEN 'Emergency - other' 
		WHEN s.AdmMethCodeHospProvSpell = '81' THEN 'Transfer' 
		WHEN s.AdmMethCodeHospProvSpell IN ('98','99') THEN 'Not known/applicable' 
		ELSE 'Missing/invalid' 
	END AS Der_AdmissionMethod
	,s.SourceAdmCodeHospProvSpell
	,CASE 
		WHEN s.SourceAdmCodeHospProvSpell IN ('19','29') THEN 'Usual/temporary placeof residence' 
		WHEN s.SourceAdmCodeHospProvSpell IN ('37','39','40','42') THEN 'Court/police/justice' 
		WHEN s.SourceAdmCodeHospProvSpell IN ('51','52') THEN 'NHS Acute Provider' 
		WHEN s.SourceAdmCodeHospProvSpell IN ('49','53') THEN 'NHS MH&LD Ward'
		WHEN s.SourceAdmCodeHospProvSpell IN ('87') THEN 'Independent Sector Provider' 
		WHEN s.SourceAdmCodeHospProvSpell IN ('54','55','56','85') THEN 'Care Home'
		WHEN s.SourceAdmCodeHospProvSpell IN ('65','66','79','88') THEN 'Other' 
		WHEN s.SourceAdmCodeHospProvSpell IN ('98','99') THEN 'Not known/not applicable' 
		ELSE 'Missing/invalid'
	END AS Der_AdmissionSource 
	,s.DischMethCodeHospProvSpell
	,CASE 
		WHEN s.DischMethCodeHospProvSpell = '1' THEN 'Discharged on clinical advice' 
		WHEN s.DischMethCodeHospProvSpell = '3' THEN 'Discharged by MH review tribunal, Home Secretary or court' 
		WHEN s.DischMethCodeHospProvSpell = '4' THEN 'Patient died' 
		WHEN s.DischMethCodeHospProvSpell = '6' THEN 'Patient discharged him/herself' 
		WHEN s.DischMethCodeHospProvSpell = '7' THEN 'Patient discharged by relative or advocate' 
		WHEN s.DischMethCodeHospProvSpell = '8' THEN 'Not applicable/not discharged' 
		WHEN s.DischMethCodeHospProvSpell = '9' THEN 'Not known' 
	ELSE 'Missing/invalid' 
	END AS Der_DischargeMethod 
	,s.DischDestCodeHospProvSpell
	,CASE 
		WHEN s.DischDestCodeHospProvSpell IN ('19') THEN 'Usual place of residence' 
		WHEN s.DischDestCodeHospProvSpell IN ('29') THEN 'Temporary place of residence' 
		WHEN s.DischDestCodeHospProvSpell IN ('37','39','40','42') THEN 'Court/police/justice' 
		WHEN s.SourceAdmCodeHospProvSpell IN ('51','52') THEN 'NHS Acute Provider' 
		WHEN s.DischDestCodeHospProvSpell IN ('49','53') THEN 'NHS MH&LD Ward'
		WHEN s.DischDestCodeHospProvSpell IN ('87') THEN 'Independent Sector Provider' 
		WHEN s.DischDestCodeHospProvSpell IN ('54','55','56','85') THEN 'Care Home'
		WHEN s.DischDestCodeHospProvSpell IN ('65','66','79','88') THEN 'Other' 
		WHEN s.DischDestCodeHospProvSpell IN ('98','99') THEN 'Not known/not applicable' 
		ELSE 'Missing/invalid'
	END AS Der_DischargeDestination
	,CASE WHEN s.DecidedToAdmitDate <= '1901-01-01' THEN NULL ELSE s.DecidedToAdmitDate END AS DecidedToAdmitDate
	,s.DecidedToAdmitTime
	,CAST(s.DecidedToAdmitDate AS DATETIME) + CAST(s.DecidedToAdmitTime AS DATETIME) AS DTA_DateTime
	,s.UniqWardStayID_first
	,s.StartDateWardStay_first
	,s.BedType_first
	,s.BedType_first_Category
	,s.UniqWardStayID_last
	,s.StartDateWardStay_last
	,s.BedType_last
	,s.BedType_last_Category
	,s.WardLocDistanceHome_last
	,CASE 
		WHEN s.WardLocDistanceHome_last BETWEEN 0 AND 4 THEN '0-4km' 
		WHEN s.WardLocDistanceHome_last BETWEEN 5 AND 9 THEN '5-9km'
		WHEN s.WardLocDistanceHome_last BETWEEN 10 AND 19 THEN '10-19km' 
		WHEN s.WardLocDistanceHome_last BETWEEN 20 AND 29 THEN '20-29km'
		WHEN s.WardLocDistanceHome_last BETWEEN 30 AND 39 THEN '20-39km' 
		WHEN s.WardLocDistanceHome_last BETWEEN 40 AND 49 THEN '40-49km' 
		WHEN s.WardLocDistanceHome_last BETWEEN 50 AND 59 THEN '50-59km' 
		WHEN s.WardLocDistanceHome_last BETWEEN 60 AND 69 THEN '60-69km' 
		WHEN s.WardLocDistanceHome_last >= 70 THEN '70+km' 
	ELSE 'Missing/Invalid'
	END AS Der_WardDistanceHome_Cat
	,s.Der_Admission
	,s.Der_Discharge
	,CASE WHEN s.DischDateHospProvSpell IS NULL OR s.DischDateHospProvSpell > s.ReportingPeriodEndDate THEN 1 ELSE 0 END AS Der_Open
	,s.Der_LOS
	,s.Der_RP_BedDays 
	,CASE
		WHEN s.LDStatus = '1' THEN 'Confirmed patient diagnosis of a learning disability'
		WHEN s.LDStatus = '2' THEN 'Suspected learning disability diagnosis (patient on diagnostic pathway)'
		WHEN s.LDStatus = '3' THEN 'Suspected learning disability diagnosis (patient not on diagnostic pathway)'
		WHEN s.LDStatus = '4' THEN 'Suspected learning disability diagnosis (not known whether patient on diagnostic pathway)'
		WHEN s.LDStatus = '5' THEN 'No patient diagnosis of a learning disability'
		WHEN s.LDStatus = 'U' THEN 'Patient asked but learning disability status not known'
		WHEN s.LDStatus IN ('X','Z') THEN 'Not known/stated'
		ELSE 'Missing/invalid'
		END AS LDStatus
	,CASE 
		WHEN s.AutismStatus = '1' THEN 'Confirmed patient diagnosis of autism'
		WHEN s.AutismStatus = '2' THEN 'Suspected autism diagnosis (patient on diagnostic pathway)'
		WHEN s.AutismStatus = '3' THEN 'Suspected autism diagnosis (patient not on diagnostic pathway)'
		WHEN s.AutismStatus = '4' THEN 'Suspected autism diagnosis (not known whether patient on diagnostic pathway)'
		WHEN s.AutismStatus = '5' THEN 'No patient diagnosis of autism'
		WHEN s.AutismStatus = 'U' THEN 'Patient asked but autism status not known'
		WHEN s.AutismStatus IN ('X','Z') THEN 'Not known/stated'
		ELSE 'Missing/invalid'
		END AS AutismStatus
	,CASE WHEN s.SourceAdmCodeHospProvSpell NOT IN ('49','53','87') THEN Der_Admission ELSE 0 END AS NoContactAdm_flag -- eligible for no contact admission metric 
	,CASE WHEN s.SourceAdmCodeHospProvSpell NOT IN ('49','53','87') AND nc.Der_ContactDate IS NULL THEN 1 ELSE 0 END AS NoPrevContact -- no previous contact in 364 days before admission
	,CASE WHEN s.Der_ReAdm_Flag1 = 1 AND s.Der_ReAdm_Flag2 = 1 THEN 1 ELSE 0 END Der_ReAdm_Flag
	,ra.TimetoReadm --- time from discharge to next (unplanned) admission 
	,ISNULL(hl.HomeLeaveDaysEndRP,0) AS HomeLeaveDaysEndRP
	,ISNULL(la.LOADaysRP,0) AS LOADaysRP
	,ri.[RI total]
	,ri.[Physical restraint]
	,ri.[Chemical restraint]
	,ri.[Mechanical restraint]
	,ri.[Seclusion or Segregation]
	,mha.MHA_BedDays
	,CASE WHEN s.StartDateHospProvSpell = mha.Der_MHAStart THEN 1 ELSE 0 END AS MHA_DOA
	,CASE WHEN s.StartDateHospProvSpell < mha.Der_MHAStart THEN 1 ELSE 0 END AS MHA_DSA
	,ISNULL(crfd.CRfD_Periods,0) AS CRfD_Periods
	,ISNULL(crfd.CRfD_Days,0) AS CRfD_Days
	,ISNULL(crfd.CRfD_Open,0) AS CRfD_Open
	,crfd.CRFD_Length

INTO MHDInternal.Temp_AcuteDash_Master

FROM MHDInternal.Temp_AcuteDash_Spells s  

LEFT JOIN Reporting_UKHD_ODS.Provider_Hierarchies p ON s.OrgIDProv = p.Organisation_Code
LEFT JOIN Internal_Reference.ComCodeChanges cc ON s.Der_SubICBCode = cc.Org_Code
LEFT JOIN Reporting_UKHD_ODS.Commissioner_Hierarchies c ON COALESCE(cc.New_Code,s.Der_SubICBCode) = c.Organisation_Code

LEFT JOIN [UKHF_Demography].[Domains_Of_Deprivation_By_LSOA1_1] dep ON s.LSOA2011 = dep.LSOA_Code AND dep.Effective_Snapshot_Date = '2019-12-31'
LEFT JOIN [UKHD_ICD10].[Codes_And_Titles_And_MetaData_1]  r1 ON s.PrimDiag = r1.Code AND r1.Effective_To IS NULL 

LEFT JOIN MHDInternal.Temp_AcuteDash_PrevContact nc ON s.UniqHospProvSpellNum = nc.UniqHospProvSpellNum AND s.Person_ID = nc.Person_ID AND nc.RN = 1 
LEFT JOIN MHDInternal.Temp_AcuteDash_ReAdm ra ON s.UniqHospProvSpellNum = ra.Index_HS AND s.Person_ID = ra.Person_ID AND ra.FirstReAdm = 1 AND ra.LastDisch = 1 ANd s.Der_Discharge = 1 

LEFT JOIN MHDInternal.Temp_AcuteDash_HomeLeave hl ON s.UniqHospProvSpellNum = hl.UniqHospProvSpellNum AND s.RecordNumber = hl.RecordNumber
LEFT JOIN MHDInternal.Temp_AcuteDash_LeaveofAbsence la ON s.UniqHospProvSpellNum = la.UniqHospProvSpellNum AND s.RecordNumber = la.RecordNumber

LEFT JOIN MHDInternal.Temp_AcuteDash_Restraint ri ON s.UniqHospProvSpellNum = ri.UniqHospProvSpellNum AND s.RecordNumber = ri.RecordNumber
LEFT JOIN MHDInternal.Temp_AcuteDash_MHA mha ON s.UniqHospProvSpellNum = mha.UniqHospProvSpellNum AND s.RecordNumber = mha.RecordNumber AND mha.OrderMHA = 1 

LEFT JOIN (
			SELECT UniqHospProvSpellID, RecordNumber
				,COUNT(*) AS  CRfD_Periods
				,SUM(CRfD_Days) AS CRfD_Days
				,MAX(CASE WHEN EndDateClinReadyforDisch IS NULL OR EndDateClinReadyforDisch > ReportingPeriodEndDate THEN 1 ELSE 0 END) CRfD_Open 
				,SUM(CASE WHEN EndDateClinReadyforDisch BETWEEN ReportingPeriodStartDate AND ReportingPeriodEndDate THEN DATEDIFF(DD,StartDateClinReadyforDisch,EndDateClinReadyforDisch)+1 ELSE 0 END) AS CRFD_Length
			FROM MHDInternal.Temp_AcuteDash_CRFD 
			GROUP BY UniqHospProvSpellID, RecordNumber
			) crfd ON s.UniqHospProvSpellNum = crfd.UniqHospProvSpellID AND s.RecordNumber = crfd.RecordNumber 


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
GET BEDS INFORMATION, AT WARD STAY / WARD CODE LEVEL
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/	

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_Wards') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_Wards

SELECT 
	wd.UniqWardCode
	,wd.NHSEUniqSubmissionID
	,f.ReportingPeriodStartDate
	,f.ReportingPeriodEndDate
	,wd.AvailBedDays
	,wd.ClosedBedDays
	,wd.OrgIDProv
	,o1.Organisation_Name AS Provider_Name
	,wd.SiteIDOfWard
	,o2.[Name] AS [SiteName]
	,CASE WHEN o4.Region_Code IN ('REG001','UNK','REG002') THEN 'Missing/invalid' ELSE o4.Region_Code END AS Region_Code
	,CASE WHEN o4.Region_Code IN ('REG001','UNK','REG002') THEN 'Missing/invalid' ELSE o4.Region_Name END AS Region_Name
	,CASE WHEN o4.Region_Code IN ('REG001','UNK','REG002') THEN 'Missing/invalid' ELSE o4.STP_Code END AS ICB_Code
	,CASE WHEN o4.Region_Code IN ('REG001','UNK','REG002') THEN 'Missing/invalid' ELSE o4.STP_Name END AS ICB_Name
	,CASE WHEN o4.Region_Code IN ('REG001','UNK','REG002') THEN 'Missing/invalid' ELSE o4.Organisation_Code END AS Der_subICBCode
	,CASE WHEN o4.Region_Code IN ('REG001','UNK','REG002') THEN 'Missing/invalid' ELSE o4.Organisation_Name END AS Der_subICBName

INTO MHDInternal.Temp_AcuteDash_Wards

FROM MESH_MHSDS.MHS903WardDetails wd 

INNER JOIN MESH_MHSDS.MHSDS_SubmissionFlags f ON wd.NHSEUniqSubmissionID = f.NHSEUniqSubmissionID AND f.Der_IsLatest = 'Y' 

LEFT JOIN Reporting_UKHD_ODS.Provider_Hierarchies o1 ON wd.OrgIDProv = o1.Organisation_Code
LEFT JOIN UKHD_ODS.All_Codes o2 ON wd.SiteIDOfWard= o2.Code
LEFT JOIN [UKHD_ODS].[Postcode_Grid_Refs_Eng_Wal_Sco_And_NI_SCD] o3 ON o2.Postcode = o3.Postcode_single_space_e_Gif AND o3.Is_Latest = 1 
LEFT JOIN Reporting_UKHD_ODS.Commissioner_Hierarchies o4 ON o3.Primary_Care_Organisation = o4.Organisation_Code


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
GET OCCUPIED BED DAYS (MHSDS v6 ONLY)
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_WardStays') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_WardStays

SELECT 
	w.UniqMonthID
	,f.ReportingPeriodEndDate
	,w.OrgIDProv
	,w.SiteIDOfWard
	,CASE WHEN w.MHAdmittedPatientClass = '10' THEN '200'
	WHEN w.MHAdmittedPatientClass = '11' THEN '201' 
	WHEN w.MHAdmittedPatientClass = '12' THEN '202' 
	WHEN w.MHAdmittedPatientClass = '13' THEN '203'  
	WHEN w.MHAdmittedPatientClass = '14' THEN '204' 
	WHEN w.MHAdmittedPatientClass = '15' THEN '205'
	WHEN w.MHAdmittedPatientClass = '17' THEN '17' --V5 code, only applicable to data pre April 24
	WHEN w.MHAdmittedPatientClass = '19' THEN '206'
	WHEN w.MHAdmittedPatientClass = '20' THEN '207'
	WHEN w.MHAdmittedPatientClass = '21' THEN '208' 
	WHEN w.MHAdmittedPatientClass = '22' THEN '209'
	WHEN w.MHAdmittedPatientClass = '40' THEN '210' 
	WHEN w.MHAdmittedPatientClass = '39' THEN '211' 
	WHEN w.MHAdmittedPatientClass = '35' THEN '35' --V5 code mapped to '212' OR '213' in v6 (not 1:1)
	WHEN w.MHAdmittedPatientClass = '36' THEN '36' --V5 code mapped to '212' OR '213' in v6 (not 1:1)
	WHEN w.MHAdmittedPatientClass = '37' THEN '37' --V5 code mapped to '212' OR '213' in v6 (not 1:1)
	WHEN w.MHAdmittedPatientClass = '38' THEN '38' --V5 code mapped to '212' OR '213' in v6 (not 1:1)
	WHEN w.MHAdmittedPatientClass = '23' THEN '300'
	WHEN w.MHAdmittedPatientClass = '24' THEN '301' 
	WHEN w.MHAdmittedPatientClass IN ('25','26') THEN '302' 
	WHEN w.MHAdmittedPatientClass = '27' THEN '303' 
	WHEN w.MHAdmittedPatientClass = '28' THEN '304'  
	WHEN w.MHAdmittedPatientClass = '29' THEN '305' 
	WHEN w.MHAdmittedPatientClass = '31' THEN '306' 
	WHEN w.MHAdmittedPatientClass = '32' THEN '307'
	WHEN w.MHAdmittedPatientClass = '33' THEN '308' 
	WHEN w.MHAdmittedPatientClass = '34' THEN '309' 
	WHEN w.MHAdmittedPatientClass = '30' THEN '30' --V5 code mapped to '310' OR '311' in V6 (not 1:1)
	ELSE w.MHAdmittedPatientClass
	END AS MHAdmittedPatientClass --maps v5 codes to v6
	,w.UniqWardCode
	,SUM(CASE WHEN w.startDatewardstay BETWEEN f.ReportingPeriodStartDate AND f.ReportingPeriodEndDate THEN 1 ELSE 0 END) AS WS_Started 
	,SUM(CASE WHEN w.EndDateWardStay BETWEEN f.ReportingPeriodStartDate AND f.ReportingPeriodEndDate THEN 1 ELSE 0 END) AS WS_Ended
	,SUM(CASE WHEN w.EndDateWardStay IS NULL OR w.EndDateWardStay > f.ReportingPeriodEndDate THEN 1 ELSE 0 END) AS WS_Open
	,SUM(w.BedDaysWSEndRP) AS Total_BedDays 
	,SUM(ISNULL(hl.HomeLeaveDaysEndRP,0)) AS HL_Days 
	,SUM(ISNULL(la.LOADaysRP,0)) AS LoA_Days  

INTO MHDInternal.Temp_AcuteDash_WardStays

FROM MESH_MHSDS.MHS502WardStay_ALL w 

INNER JOIN MESH_MHSDS.MHSDS_SubmissionFlags f ON w.NHSEUniqSubmissionID = f.NHSEUniqSubmissionID AND f.Der_IsLatest = 'Y' 

LEFT JOIN 
	(
	SELECT 
		a.UniqWardStayID
		,a.RecordNumber 
		,SUM(HomeLeaveDaysEndRP) AS HomeLeaveDaysEndRP
	FROM MESH_MHSDS.MHS509HomeLeave a
	INNER JOIN MESH_MHSDS.MHSDS_SubmissionFlags f ON a.NHSEUniqSubmissionID = f.NHSEUniqSubmissionID AND f.Der_IsLatest = 'Y' 
	WHERE f.ReportingPeriodStartDate >= '2024-04-01' 
	GROUP BY a.UniqWardStayID, a.RecordNumber 
	) hl ON w.RecordNumber = hl.RecordNumber AND w.UniqWardStayID = hl.UniqWardStayID 

LEFT JOIN 
	(
	SELECT 
		a.UniqWardStayID
		,a.RecordNumber 
		,SUM(LOADaysRP) AS LOADaysRP
	FROM MESH_MHSDS.MHS510LeaveOfAbsence a
	INNER JOIN MESH_MHSDS.MHSDS_SubmissionFlags f ON a.NHSEUniqSubmissionID = f.NHSEUniqSubmissionID AND f.Der_IsLatest = 'Y' 
	WHERE f.ReportingPeriodStartDate >= '2024-04-01' 
	GROUP BY a.UniqWardStayID, a.RecordNumber 
	) la ON w.RecordNumber = la.RecordNumber AND w.UniqWardStayID = la.UniqWardStayID 

WHERE f.ReportingPeriodStartDate >= '2024-04-01' 

GROUP BY w.UniqMonthID, f.ReportingPeriodEndDate, w.OrgIDProv, w.SiteIDOfWard, w.UniqWardCode, w.MHAdmittedPatientClass 




/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
COMBINE ALL WARD ACTIVITY 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_WardCombined') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_WardCombined

SELECT
	a.UniqWardCode
	,a.NHSEUniqSubmissionID
	,a.ReportingPeriodStartDate
	,a.ReportingPeriodEndDate
	,a.OrgIDProv
	,a.Provider_Name
	,a.SiteIDOfWard
	,a.SiteName
	,a.Der_subICBCode
	,a.Der_subICBName
	,a.ICB_Code
	,a.ICB_Name
	,a.Region_Code
	,a.Region_Name
	,a.AvailBedDays
	,a.ClosedBedDays 
	,b.MHAdmittedPatientClass 
	,CASE 
		WHEN b.MHAdmittedPatientClass IN ('17','35','36','37','38','30') THEN CONCAT('V5: ',COALESCE(bt2.NationalCodeDefinition, bt1.Main_Description_60_Chars),' (only applicable before April 2024)')
		ELSE CONCAT('V6: ',COALESCE(bt2.NationalCodeDefinition, bt1.Main_Description_60_Chars,'Missing/Invalid'))
		END AS BedType
	,CASE 
		WHEN b.MHAdmittedPatientClass IN ('10','11','12','200','201','202') THEN 'Adult Acute (ICB commissioned)' 
		WHEN b.MHAdmittedPatientClass IN ('13','14','15','16','17','18','19','20','21','22','35','36','37','38','39','40','203','204','205','206','207','208','209','210','211','212','213') THEN 'Adult Specialist' 
		WHEN b.MHAdmittedPatientClass IN ('23','24','25','26','27','28','29','30','31','32','33','34','300','301','302','303','304','305','306','307','308','309','310','311') THEN 'CYP' 
		ELSE 'Missing/Invalid' 
		END as BedType_Category
	,b.WS_Started 
	,b.WS_Ended
	,b.WS_Open
	,b.Total_BedDays 
	,b.HL_Days 
	,b.LoA_Days  

INTO MHDInternal.Temp_AcuteDash_WardCombined

FROM MHDInternal.Temp_AcuteDash_Wards a 

LEFT JOIN MHDInternal.Temp_AcuteDash_WardStays b ON a.ReportingPeriodEndDate = b.ReportingPeriodEndDate 
	AND a.OrgIDProv = b.OrgIdProv 
	AND a.UniqWardCode = b.UniqWardCode

LEFT JOIN [UKHD_Data_Dictionary].[Mental_Health_Admitted_Patient_Classification_SCD_1] bt1 ON b.MHAdmittedPatientClass = bt1.Main_Code_Text COLLATE DATABASE_DEFAULT AND bt1.Is_Latest = 1
LEFT JOIN MHDInternal.Reference_MHSDSv6_BedTypes bt2 ON b.MHAdmittedPatientClass = bt2.MHAdmittedPatientClass 



/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
CREATE CRFD MASTER TABLE 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_CRFDMaster') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_CRFDMaster

SELECT 
	m.[Provider code]
	,m.[Provider name]
	,CASE WHEN m.[Region code] IN ('REG001','UNK','REG002') THEN 'Missing/invalid' ELSE m.[subICB code] END AS [subICB code]
	,CASE WHEN m.[Region code] IN ('REG001','UNK','REG002') THEN 'Missing/invalid' ELSE m.[subICB name] END AS [subICB name]
	,CASE WHEN m.[Region code] IN ('REG001','UNK','REG002') THEN 'Missing/invalid' ELSE m.[ICB code] END AS [ICB code]
	,CASE WHEN m.[Region code] IN ('REG001','UNK','REG002') THEN 'Missing/invalid' ELSE m.[ICB name] END AS [ICB name]
	,CASE WHEN m.[Region code] IN ('REG001','UNK','REG002') THEN 'Missing/invalid' ELSE m.[Region code] END AS [Region code]
	,CASE WHEN m.[Region code] IN ('REG001','UNK','REG002') THEN 'Missing/invalid' ELSE m.[Region name] END AS [Region name]
	,m.BedType_last
	,m.BedType_last_Category
	,c.ReportingPeriodStartDate
	,c.ReportingPeriodEndDate
	,UniqHospProvSpellID
	,c.RecordNumber
	,MHS518UniqID
	,StartDateClinReadyforDisch
	,EndDateClinReadyforDisch
	,CASE 
		WHEN AttribToIndic = '04' THEN 'NHS' 
		WHEN AttribToIndic = '05' THEN 'Social Care' 
		WHEN AttribToIndic = '06' THEN 'Both (NHS and Social Care)' 
	ELSE 'Missing/invalid' 
	END AS Der_AttributableOrg
	,ClinReadyforDischDelayReason
	,CASE 
		WHEN ClinReadyforDischDelayReason IN ('01','02','04','05','06','08','09','10','12','13','22','23','24','25'
											,'26','27','28','29','30','31','33','37') THEN 'Community' 
		WHEN ClinReadyforDischDelayReason IN ('03','07','20','21','34') THEN 'Social care/local authority' 
		WHEN ClinReadyforDischDelayReason IN ('11','35','36') THEN 'Hospital'
		WHEN ClinReadyforDischDelayReason IN ('14','15','16','17','18','19','32') THEN 'Housing' 
		WHEN ClinReadyforDischDelayReason = '98' THEN 'Not known'
	ELSE 'Missing/invalid' 
	END AS Der_CRFD_ReasonGroup
	,CASE 
		WHEN ClinReadyforDischDelayReason = '01' THEN 'Awaiting care coordinator allocation'
		WHEN ClinReadyforDischDelayReason = '02' THEN 'Awaiting allocation of community psychiatrist' 
		WHEN ClinReadyforDischDelayReason = '03' THEN 'Awaiting allocation of social worker' 
		WHEN ClinReadyforDischDelayReason = '04' THEN 'Awaiting public funding or decision from funding panel'
		WHEN ClinReadyforDischDelayReason = '05' THEN 'Awaiting further community or MH NHS services not delivered in an acute setting' 
		WHEN ClinReadyforDischDelayReason = '06' THEN 'Awaiting availability of placement in prison or Immigration Removal Centre'
		WHEN ClinReadyforDischDelayReason = '07' THEN 'Awaiting availability of placement in care home without nursing' 
		WHEN ClinReadyforDischDelayReason = '08' THEN 'Awaiting availability of placement in care home with nursing' 
		WHEN ClinReadyforDischDelayReason = '09' THEN 'Awaiting commencement of care package in usual or temporary place of residence' 
		WHEN ClinReadyforDischDelayReason = '10' THEN 'Awaiting provision of community equipment and/or adaption to own home' 
		WHEN ClinReadyforDischDelayReason = '11' THEN 'Patient or Family choice' 
		WHEN ClinReadyforDischDelayReason = '12' THEN 'Disputes relating to responsible commissioner for post-discharge care' 
		WHEN ClinReadyforDischDelayReason = '13' THEN 'Disputes relating to post-discharge care pathway between clinical teams and/or care panels'
		WHEN ClinReadyforDischDelayReason = '14' THEN 'Housing - awaiting availability of private rented accommodation'
		WHEN ClinReadyforDischDelayReason = '15' THEN 'Housing - awaiting availability of social rent housing via council housing waiting list' 
		WHEN ClinReadyforDischDelayReason = '16' THEN 'Housing - awaiting purchase/sourcing of own home' 
		WHEN ClinReadyforDischDelayReason = '17' THEN 'Housing - patient NOT eligible for funded care or support' 
		WHEN ClinReadyforDischDelayReason = '18' THEN 'Housing - awaiting supported accommodation' 
		WHEN ClinReadyforDischDelayReason = '19' THEN 'Housing - awaiting temporary accommodation from the LA' 
		WHEN ClinReadyforDischDelayReason = '20' THEN 'Awaiting availability of residential children''s home (non-secure)'
		WHEN ClinReadyforDischDelayReason = '21' THEN 'Awaiting availability of secure children''s home (welfare or non-welfare)'
		WHEN ClinReadyforDischDelayReason = '22' THEN 'Awaiting availability of placement in Youth Offender institution' 
		WHEN ClinReadyforDischDelayReason = '23' THEN 'Child or young person awaiting foster placement' 
		WHEN ClinReadyforDischDelayReason = '24' THEN 'Awaiting MoJ agreement to proposed placement' 
		WHEN ClinReadyforDischDelayReason = '25' THEN 'Awaiting outcome of legal proceedings under relevant MHA legislation' 
		WHEN ClinReadyforDischDelayReason = '26' THEN 'Awaiting Court of Protection proceedings' 
		WHEN ClinReadyforDischDelayReason = '27' THEN 'Awaiting DOLS application' 
		WHEN ClinReadyforDischDelayReason = '28' THEN 'Delay due to consideration of specific court judgements' 
		WHEN ClinReadyforDischDelayReason = '29' THEN 'Awaiting residential special school or college placement' 
		WHEN ClinReadyforDischDelayReason = '30' THEN 'Lack of local education support' 
		WHEN ClinReadyforDischDelayReason = '31' THEN 'Public safety concern unrelated to clinical treatment need'
		WHEN ClinReadyforDischDelayReason = '32' THEN 'Highly bespoke housing and/or care arrangements not available in the community' 
		WHEN ClinReadyforDischDelayReason = '33' THEN 'No lawful support available in the community excluding social care'
		WHEN ClinReadyforDischDelayReason = '34' THEN 'No social care support including social care funded placement' 
		WHEN ClinReadyforDischDelayReason = '35' THEN 'Delays to NHS-led assessments in the community' 
		WHEN ClinReadyforDischDelayReason = '36' THEN 'Hospital staff shortages' 
		WHEN ClinReadyforDischDelayReason = '37' THEN 'Delays to non-NHS led assessments in the community' 
		WHEN ClinReadyforDischDelayReason = '98' THEN 'Reason not known' 
		ELSE 'Missing/invalid'
	END AS Der_CRFD_Reason
	,c.CRfD_Days
	,rnk
	,CASE WHEN StartDateClinReadyforDisch BETWEEN c.REPortingPeriodStartDate AND c.ReportingPeriodEndDate THEN 1 ELSE 0 END AS Der_CRFD_Started
	,CASE WHEN EndDateClinReadyforDisch BETWEEN c.REPortingPeriodStartDate AND c.ReportingPeriodEndDate THEN 1 ELSE 0 END AS Der_CRFD_Ended
	,CASE WHEN EndDateClinReadyforDisch BETWEEN c.REPortingPeriodStartDate AND c.ReportingPeriodEndDate THEN DATEDIFF(DD, StartDateClinReadyforDisch, EndDateClinReadyforDisch)+1 ELSE NULL END AS Der_CRFD_Length
	,CASE WHEN EndDateClinReadyforDisch IS NULL OR EndDateClinReadyforDisch > c.ReportingPeriodEndDate THEN 1 ELSE 0 END AS Der_CRFD_Open 

INTO MHDInternal.Temp_AcuteDash_CRFDMaster

FROM MHDInternal.Temp_AcuteDash_CRFD c

INNER JOIN MHDInternal.Temp_AcuteDash_Master m ON c.RecordNumber = m.RecordNumber AND c.UniqHospProvSpellID = m.UniqHospProvSpellNum


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
------------------------------------   AGGREGATE METRICS ---------------------------------------------------------------------
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/



/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
HOSPITAL SPELL - ADMISSION METRICS 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/


IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_Agg_Admissions') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_Agg_Admissions

SELECT
	ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,BedType_first as [Bed Type] 
	,BedType_first_Category as [Bed Type Category] 
	,'Admission Source' AS BreakdownCategory1
	,Der_AdmissionSource AS Breakdown1
	,'Decision to Admit' AS BreakdownCategory2
	,CASE 
		WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DTA_DateTime = HospProvSpellStartDateTime THEN 'DTA same time'
		WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) = 0 AND DTA_DateTime < HospProvSpellStartDateTime THEN 'Within 1 hour'
		WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) BETWEEN 1 AND 24 THEN '1-24 hours' 
		WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) BETWEEN 25 AND 168 THEN '1-7 days' 
		WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) >= 169 THEN '7+ days' 
		ELSE 'DTA missing'
	END AS Breakdown2
	,SUM(Der_Admission) AS Admissions
	,SUM(Der_Admission) AS Admissions2 -- denom for DTA complete measure
	,SUM(NoContactAdm_flag) AS NoContactAdm_flag -- denominator for no contact admissions
	,SUM(NoPrevContact) AS NoPrevContact

INTO MHDInternal.Temp_AcuteDash_Agg_Admissions

FROM MHDInternal.Temp_AcuteDash_Master 

WHERE Der_Admission = 1 

GROUP BY ReportingPeriodStartDate,ReportingPeriodEndDate,[Provider code],[Provider name],[subICB code],[subICB name],[ICB code]
	,[ICB name],[Region code],[Region name],BedType_first,BedType_first_Category ,Der_AdmissionSource, CASE 
		WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DTA_DateTime = HospProvSpellStartDateTime THEN 'DTA same time'
		WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) = 0 AND DTA_DateTime < HospProvSpellStartDateTime THEN 'Within 1 hour'
		WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) BETWEEN 1 AND 24 THEN '1-24 hours' 
		WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) BETWEEN 25 AND 168 THEN '1-7 days' 
		WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) >= 169 THEN '7+ days' ELSE 'DTA missing'
	END 

	
/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
HOSPITAL SPELL - OPEN SPELL METRICS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_Agg_OpenSpells') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_Agg_OpenSpells

SELECT
	ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,BedType_last as [Bed Type] 
	,BedType_last_Category as [Bed Type Category] 
	,'Diagnosis' AS BreakdownCategory1
	,DiagGroup AS Breakdown1
	,'Distance From Home' AS BreakdownCategory2
	,Der_WardDistanceHome_Cat AS Breakdown2
	,COUNT(*) AS [Active spells] -- not really needed 
	,SUM(Der_Open) AS [Open spells]
	,SUM(Der_Open) AS [Open spells2] -- denom for CRFD measures 
	,SUM(Der_RP_BedDays) AS [Total bed days]
	,SUM(Der_RP_BedDays) AS [Total bed days2] -- denom for CRFD measures
	,SUM(Der_RP_BedDays-HomeLeaveDaysEndRP-LOADaysRP) AS [Total bed days less leave]
	,SUM(CRfD_Open) AS [Open and CRFD]
	,SUM(CRfD_Days) AS [CRFD Days (spells)]

INTO MHDInternal.Temp_AcuteDash_Agg_OpenSpells

FROM MHDInternal.Temp_AcuteDash_Master  

GROUP BY ReportingPeriodStartDate,ReportingPeriodEndDate,[Provider code],[Provider name],[subICB code],[subICB name],[ICB code]
	,[ICB name],[Region code],[Region name],BedType_last,BedType_last_Category, DiagGroup, Der_WardDistanceHome_Cat



/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
HOSPITAL SPELL - DISCHARGE METRICS INCLUDING LOS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_Agg_Discharge') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_Agg_Discharge

SELECT 
	ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,BedType_last as [Bed Type] 
	,BedType_last_Category as [Bed Type Category] 
	,'Discharge destination' AS BreakdownCategory1
	,ISNULL(Der_DischargeDestination,'Missing/invalid') AS Breakdown1
	,'Diagnosis' AS BreakdownCategory2
	,DiagGroup AS Breakdown2
	,SUM(Der_Discharge) AS Discharges 
	,SUM(Der_Discharge) AS Discharges2 -- denom for LOS measures  
	,SUM(Der_ReAdm_Flag) AS [Discharges eligible for readmission] -- denom for readmission measure
	,SUM(CASE WHEN TimetoReadm < 14 THEN 1 ELSE 0 END) AS [Readmitted 14 days]
	,SUM(CASE WHEN Der_LOS >= 60 THEN 1 ELSE 0 END) AS [LOS over 60 days]
	,SUM(CASE WHEN Der_LOS >= 90 THEN 1 ELSE 0 END) AS [LOS over 90 days]
	,SUM(CASE WHEN Der_LOS < 3 THEN 1 ELSE 0 END) AS [LOS less than 3 days]
	,SUM(Der_LOS) AS [Total LOS] -- for mean LOS 
	,SUM(Der_LOS-ISNULL(CRFD_Length,0)) AS [Total LOS excl CRFD] -- potential mean LOS if there was no CRFD
	,SUM(LOG(Der_LOS)) AS [Total ln LOS] -- for creating geometric mean 

INTO MHDInternal.Temp_AcuteDash_Agg_Discharge

FROM MHDInternal.Temp_AcuteDash_Master  

WHERE Der_Discharge = 1 

GROUP BY ReportingPeriodStartDate,ReportingPeriodEndDate,[Provider code],[Provider name],[subICB code],[subICB name],[ICB code]
	,[ICB name],[Region code],[Region name],BedType_last, BedType_last_Category, Der_DischargeDestination, DiagGroup

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
AGGREGATE CLINICALLY READY FOR DISCHARGE EPISODES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_Agg_CRFD') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_Agg_CRFD

SELECT 
	ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,BedType_last as [Bed Type] 
	,BedType_last_Category as [Bed Type Category] 
	,'CRFD Reason Higher' AS BreakdownCategory1
	,Der_CRFD_ReasonGroup AS Breakdown1
	,'CRFD Reason Lower' AS BreakdownCategory2
	,Der_CRFD_Reason AS Breakdown2
	,COUNT(*) AS [CRFD episodes] -- might not need to report this 
	,SUM(Der_CRFD_Started) AS [CRFD started]
	,SUM(Der_CRFD_Open) AS [CRFD open]
	,SUM(Der_CRFD_Ended) AS [CRFD ended]
	,SUM(Der_CRFD_Length) AS [CRFD closed length]
	,SUM(LOG(Der_CRFD_Length)) AS [CRFD log lenth] -- for gemotric mean
	,SUM(CRfD_Days) AS [CRFD Days]

INTO MHDInternal.Temp_AcuteDash_Agg_CRFD

FROM MHDInternal.Temp_AcuteDash_CRFDMaster

GROUP BY ReportingPeriodStartDate,ReportingPeriodEndDate,[Provider code],[Provider name],[subICB code],[subICB name],[ICB code]
	,[ICB name],[Region code],[Region name],BedType_last,BedType_last_Category, Der_CRFD_ReasonGroup, Der_CRFD_Reason




/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
AGGREGATE WARDS 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_Agg_Wards') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_Agg_Wards

SELECT  
	w.ReportingPeriodStartDate
	,w.ReportingPeriodEndDate
	,w.OrgIDProv AS [Provider code]
	,w.Provider_Name AS [Provider name]
	,COALESCE(w.Der_subICBCode,'Missing/invalid') AS [subICB code]
	,COALESCE(w.Der_subICBName,'Missing/invalid') AS [subICB name]
	,COALESCE(w.ICB_Code,'Missing/invalid') AS [ICB code]
	,COALESCE(w.ICB_Name,'Missing/invalid') AS [ICB name]
	,COALESCE(w.Region_Code,'Missing/invalid') AS [Region code]
	,COALESCE(w.Region_Name,'Missing/invalid') AS [Region name]
	,x.BedType -- majority bed type for ward in the month
	,x.BedType_Category
	,'Site Name' AS BreakdownCategory1 
	,COALESCE(SiteName,'Missing/invalid') AS Breakdown1
	,'Ward Code' AS BreakdownCategory2
	,w.UniqWardCode AS Breakdown2
	,CASE WHEN w.AvailBedDays > 0 AND w.Total_BedDays > 0 THEN CAST(w.AvailBedDays AS INT) ELSE 0 END AS AvailBedDays
	,CASE WHEN w.AvailBedDays > 0 AND w.Total_BedDays > 0 THEN CAST(w.AvailBedDays AS INT) ELSE 0 END AS AvailBedDays2 -- denominator 
	,CASE WHEN w.AvailBedDays > 0 AND w.Total_BedDays >0 THEN CAST(w.ClosedBedDays AS INT) ELSE 0 END AS ClosedBedDays
	,CASE WHEN w.AvailBedDays > 0 AND w.Total_BedDays > 0 THEN w.Total_BedDays ELSE 0 END AS Occupied_BedDays
	,CASE WHEN w.AvailBedDays > 0 AND w.Total_BedDays > 0 THEN CAST(w.AvailBedDays AS INT) - w.Total_BedDays ELSE 0 END AS Unoccupied_BedDays
	,CASE WHEN w.AvailBedDays > 0 AND w.Total_BedDays > 0 THEN CAST(w.AvailBedDays AS INT) + CAST(w.ClosedBedDays AS INT) ELSE 0 END AS Total_BedDays -- denom for % closed
	,w.WS_Started
	,w.WS_Ended
	,w.WS_Open
	-- DQ metrics 
	,1 AS WardMonthCount -- denom 
	,CASE WHEN w.AvailBedDays > 0 THEN 1 ELSE 0 END AS Val_AvailableBedDays 
	,CASE WHEN w.Total_BedDays > 0 THEN 1 ELSE 0 END AS Val_TotalBedDays 
	,CASE WHEN w.AvailBedDays > 0 AND w.Total_BedDays > 0 THEN 1 ELSE 0 END AS Val_Both 

INTO MHDInternal.Temp_AcuteDash_Agg_Wards

FROM MHDInternal.Temp_AcuteDash_WardCombined w 

LEFT JOIN 
	(
	SELECT 
	UniqWardCode
	,ReportingPeriodEndDate
	,BedType
	,BedType_Category
	,SUM(Total_BedDays) AS Total_BedDays
	,ROW_NUMBER()OVER(PARTITION BY UniqWardCode, ReportingPeriodEndDate ORDER BY SUM(Total_BEdDays) DESC) AS Main_BedType
	FROM MHDInternal.Temp_AcuteDash_WardCombined

	GROUP BY UniqWardCode
	,ReportingPeriodEndDate
	,BedType
	,BedType_Category
	) x ON w.UniqWardCode = x.UniqWardCode AND w.ReportingPeriodEndDate = x.ReportingPeriodEndDate AND x.Main_BedType = 1

ORDER BY [Provider name], SiteName, x.UniqWardCode, ReportingPeriodEndDate




/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
AGGREGATE SELECTED DEMOGRAPHIC MEASURES 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
AGGREGATE SELECTED DEMOGRAPHIC MEASURES 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
HOSPITAL SPELL - ADMISSION METRICS BY DEMOGRAPHIC BREAKDOWNS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_Agg_Admissions_Demo') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_Agg_Admissions_Demo

-- Define schema and data types to prevent truncate issue when inserting data
CREATE TABLE MHDInternal.Temp_AcuteDash_Agg_Admissions_Demo(
	ReportingPeriodStartDate DATE
	,ReportingPeriodEndDate DATE
	,[Provider code] VARCHAR(200)
	,[Provider name] VARCHAR(200)
	,[subICB code] VARCHAR(200)
	,[subICB name] VARCHAR(200)
	,[ICB code] VARCHAR(200)
	,[ICB name] VARCHAR(200)
	,[Region code] VARCHAR(200)
	,[Region name] VARCHAR(200)
	,[Bed Type] VARCHAR(200)
	,[Bed Type Category] VARCHAR(200)
	,BreakdownCategory1 VARCHAR(200)
	,Breakdown1 VARCHAR(200)
	,BreakdownCategory2 VARCHAR(200)
	,Breakdown2 VARCHAR(200)
	,Admissions BIGINT
	,Admissions2 BIGINT
	,NoContactAdm_flag BIGINT
	,NoPrevContact BIGINT
	,[DTA complete] BIGINT
	,[DTA complete2] BIGINT
	,[DTA - same time] BIGINT
	,[DTA - <1 hour] BIGINT
	,[DTA - 1-24 hours] BIGINT
	,[DTA - 1-7 days] BIGINT
	,[DTA - 7+ days] BIGINT
)

-- HOSPITAL SPELL - GENDER
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_Admissions_Demo
SELECT
	ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,BedType_first as [Bed Type] 
	,BedType_first_Category as [Bed Type Category] 
	,'Gender' AS BreakdownCategory1
	,Gender AS Breakdown1
	,'None' AS BreakdownCategory2 -- don't need two breakdowns for these measures
	,NULL AS Breakdown2
	,SUM(Der_Admission) AS Admissions
	,SUM(Der_Admission) AS Admissions2 -- denom for DTA complete measure
	,SUM(NoContactAdm_flag) AS NoContactAdm_flag -- denominator for no contact admissions
	,SUM(NoPrevContact) AS NoPrevContact
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA complete]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA complete2] -- denom for measures below
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DTA_DateTime = HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA - same time]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) = 0 AND DTA_DateTime < HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA - <1 hour]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) BETWEEN 1 AND 24 THEN 1 ELSE 0 END) AS [DTA - 1-24 hours]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) BETWEEN 25 AND 168 THEN 1 ELSE 0 END) AS [DTA - 1-7 days]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) >= 169 THEN 1 ELSE 0 END) AS [DTA - 7+ days]

FROM MHDInternal.Temp_AcuteDash_Master 

WHERE Der_Admission = 1 

GROUP BY ReportingPeriodStartDate,ReportingPeriodEndDate,[Provider code],[Provider name],[subICB code],[subICB name],[ICB code]
	,[ICB name],[Region code],[Region name],BedType_first, BedType_first_Category, Gender


--- HOSPITAL SPELL - AGE BAND
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_Admissions_Demo
SELECT
	ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,BedType_first as [Bed Type]
	,BedType_first_Category as [Bed Type Category]
	,'Age Band' AS BreakdownCategory1
	,AgeBand AS Breakdown1
	,'None' AS BreakdownCategory2
	,NULL AS Breakdown2
	,SUM(Der_Admission) AS Admissions
	,SUM(Der_Admission) AS Admissions2 -- denom for DTA complete measure
	,SUM(NoContactAdm_flag) AS NoContactAdm_flag -- denominator for no contact admissions
	,SUM(NoPrevContact) AS NoPrevContact
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA complete]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA complete2] -- denom for measures below
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DTA_DateTime = HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA - same time]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) = 0 AND DTA_DateTime < HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA - <1 hour]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) BETWEEN 1 AND 24 THEN 1 ELSE 0 END) AS [DTA - 1-24 hours]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) BETWEEN 25 AND 168 THEN 1 ELSE 0 END) AS [DTA - 1-7 days]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) >= 169 THEN 1 ELSE 0 END) AS [DTA - 7+ days]

FROM MHDInternal.Temp_AcuteDash_Master 

WHERE Der_Admission = 1 

GROUP BY ReportingPeriodStartDate,ReportingPeriodEndDate,[Provider code],[Provider name],[subICB code],[subICB name],[ICB code]
	,[ICB name],[Region code],[Region name],BedType_first, BedType_first_Category, AgeBand

-- HOSPITAL SPELL - ETHNICITY
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_Admissions_Demo
SELECT
	ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,BedType_first as [Bed Type] 
	,BedType_first_Category as [Bed Type Category]
	,'Upper Ethnicity' AS BreakdownCategory1
	,UpperEthnicity AS Breakdown1
	,'Lower Ethnicity' AS BreakdownCategory2
	,Der_EthnicFull AS Breakdown2
	,SUM(Der_Admission) AS Admissions
	,SUM(Der_Admission) AS Admissions2 -- denom for DTA complete measure
	,SUM(NoContactAdm_flag) AS NoContactAdm_flag -- denominator for no contact admissions
	,SUM(NoPrevContact) AS NoPrevContact
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA complete]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA complete2] -- denom for measures below
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DTA_DateTime = HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA - same time]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) = 0 AND DTA_DateTime < HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA - <1 hour]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) BETWEEN 1 AND 24 THEN 1 ELSE 0 END) AS [DTA - 1-24 hours]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) BETWEEN 25 AND 168 THEN 1 ELSE 0 END) AS [DTA - 1-7 days]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) >= 169 THEN 1 ELSE 0 END) AS [DTA - 7+ days]

FROM MHDInternal.Temp_AcuteDash_Master 

WHERE Der_Admission = 1 

GROUP BY ReportingPeriodStartDate,ReportingPeriodEndDate,[Provider code],[Provider name],[subICB code],[subICB name],[ICB code]
	,[ICB name],[Region code],[Region name],BedType_first, BedType_first_Category, UpperEthnicity, Der_EthnicFull	


--- HOSPITAL SPELL - IMD Decile
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_Admissions_Demo
SELECT
	ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,BedType_first as [Bed Type] 
	,BedType_first_Category as [Bed Type Category]
	,'IMD Decile' AS BreakdownCategory1
	,IMD_Decile AS Breakdown1
	,'None' AS BreakdownCategory2
	,NULL AS Breakdown2
	,SUM(Der_Admission) AS Admissions
	,SUM(Der_Admission) AS Admissions2 -- denom for DTA complete measure
	,SUM(NoContactAdm_flag) AS NoContactAdm_flag -- denominator for no contact admissions
	,SUM(NoPrevContact) AS NoPrevContact
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA complete]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA complete2] -- denom for measures below
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DTA_DateTime = HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA - same time]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) = 0 AND DTA_DateTime < HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA - <1 hour]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) BETWEEN 1 AND 24 THEN 1 ELSE 0 END) AS [DTA - 1-24 hours]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) BETWEEN 25 AND 168 THEN 1 ELSE 0 END) AS [DTA - 1-7 days]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) >= 169 THEN 1 ELSE 0 END) AS [DTA - 7+ days]

FROM MHDInternal.Temp_AcuteDash_Master 

WHERE Der_Admission = 1 

GROUP BY ReportingPeriodStartDate,ReportingPeriodEndDate,[Provider code],[Provider name],[subICB code],[subICB name],[ICB code]
	,[ICB name],[Region code],[Region name],BedType_first, BedType_first_Category, IMD_Decile

-- HOSPITAL SPELL - LD STATUS
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_Admissions_Demo
SELECT
	ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,BedType_first as [Bed Type] 
	,BedType_first_Category as [Bed Type Category] 
	,'LD Status' AS BreakdownCategory1
	,LDStatus AS Breakdown1
	,'None' AS BreakdownCategory2 -- don't need two breakdowns for these measures
	,NULL AS Breakdown2
	,SUM(Der_Admission) AS Admissions
	,SUM(Der_Admission) AS Admissions2 -- denom for DTA complete measure
	,SUM(NoContactAdm_flag) AS NoContactAdm_flag -- denominator for no contact admissions
	,SUM(NoPrevContact) AS NoPrevContact
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA complete]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA complete2] -- denom for measures below
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DTA_DateTime = HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA - same time]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) = 0 AND DTA_DateTime < HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA - <1 hour]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) BETWEEN 1 AND 24 THEN 1 ELSE 0 END) AS [DTA - 1-24 hours]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) BETWEEN 25 AND 168 THEN 1 ELSE 0 END) AS [DTA - 1-7 days]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) >= 169 THEN 1 ELSE 0 END) AS [DTA - 7+ days]

FROM MHDInternal.Temp_AcuteDash_Master 

WHERE Der_Admission = 1 

GROUP BY ReportingPeriodStartDate,ReportingPeriodEndDate,[Provider code],[Provider name],[subICB code],[subICB name],[ICB code]
	,[ICB name],[Region code],[Region name],BedType_first, BedType_first_Category, LDstatus


-- HOSPITAL SPELL - AUTISM STATUS
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_Admissions_Demo
SELECT
	ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,BedType_first as [Bed Type] 
	,BedType_first_Category as [Bed Type Category] 
	,'Autism Status' AS BreakdownCategory1
	,AutismStatus AS Breakdown1
	,'None' AS BreakdownCategory2 -- don't need two breakdowns for these measures
	,NULL AS Breakdown2
	,SUM(Der_Admission) AS Admissions
	,SUM(Der_Admission) AS Admissions2 -- denom for DTA complete measure
	,SUM(NoContactAdm_flag) AS NoContactAdm_flag -- denominator for no contact admissions
	,SUM(NoPrevContact) AS NoPrevContact
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA complete]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA complete2] -- denom for measures below
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DTA_DateTime = HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA - same time]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) = 0 AND DTA_DateTime < HospProvSpellStartDateTime THEN 1 ELSE 0 END) AS [DTA - <1 hour]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) BETWEEN 1 AND 24 THEN 1 ELSE 0 END) AS [DTA - 1-24 hours]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) BETWEEN 25 AND 168 THEN 1 ELSE 0 END) AS [DTA - 1-7 days]
	,SUM(CASE WHEN DTA_DateTime <= HospProvSpellStartDateTime AND DATEDIFF(HOUR, DTA_DateTime, HospProvSpellStartDateTime) >= 169 THEN 1 ELSE 0 END) AS [DTA - 7+ days]

FROM MHDInternal.Temp_AcuteDash_Master 

WHERE Der_Admission = 1 

GROUP BY ReportingPeriodStartDate,ReportingPeriodEndDate,[Provider code],[Provider name],[subICB code],[subICB name],[ICB code]
	,[ICB name],[Region code],[Region name],BedType_first, BedType_first_Category, AutismStatus
	
/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
HOSPITAL SPELL - OPEN SPELL METRICS BY DEMOGRAPHIC BREAKDOWN
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_Agg_OpenSpells_Demo') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_Agg_OpenSpells_Demo

-- Define schema and data types to prevent truncate issue when inserting data
CREATE TABLE MHDInternal.Temp_AcuteDash_Agg_OpenSpells_Demo(
ReportingPeriodStartDate DATE
,ReportingPeriodEndDate DATE
,[Provider code] VARCHAR(200)
,[Provider name] VARCHAR(200)
,[subICB code] VARCHAR(200)
,[subICB name] VARCHAR(200)
,[ICB code] VARCHAR(200)
,[ICB name] VARCHAR(200)
,[Region code] VARCHAR(200)
,[Region name] VARCHAR(200)
,[Bed Type] VARCHAR(200)
,[Bed Type Category] VARCHAR(200)
,BreakdownCategory1 VARCHAR(200)
,Breakdown1 VARCHAR(200)
,BreakdownCategory2 VARCHAR(200)
,Breakdown2 VARCHAR(200)
,[Active spells] BIGINT
,[Open spells] BIGINT
,[Open spells2] BIGINT
,[Total bed days] BIGINT
,[Total bed days2] BIGINT
,[Total bed days less leave] BIGINT
,[Open and CRFD] BIGINT
,[CRFD Days (spells)] BIGINT
)

-- OPEN SPELL - GENDER
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_OpenSpells_Demo
SELECT
	ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,BedType_last as [Bed Type]
	,BedType_last_Category as [Bed Type Category]
	,'Gender' AS BreakdownCategory1
	,Gender AS Breakdown1
	,'None' AS BreakdownCategory2
	,NULL AS Breakdown2
	,COUNT(*) AS [Active spells] -- not really needed 
	,SUM(Der_Open) AS [Open spells]
	,SUM(Der_Open) AS [Open spells2] -- denom for CRFD measures 
	,SUM(Der_RP_BedDays) AS [Total bed days]
	,SUM(Der_RP_BedDays) AS [Total bed days2] -- denom for CRFD measures
	,SUM(Der_RP_BedDays-HomeLeaveDaysEndRP-LOADaysRP) AS [Total bed days less leave]
	,SUM(CRfD_Open) AS [Open and CRFD]
	,SUM(CRfD_Days) AS [CRFD Days (spells)]

FROM MHDInternal.Temp_AcuteDash_Master  

GROUP BY ReportingPeriodStartDate,ReportingPeriodEndDate,[Provider code],[Provider name],[subICB code],[subICB name],[ICB code]
	,[ICB name],[Region code],[Region name],BedType_last, BedType_last_Category, Gender

-- OPEN SPELL - AGE BAND
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_OpenSpells_Demo
	SELECT
	ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,BedType_last as [Bed Type] 
	,BedType_last_Category as [Bed Type Category]
	,'Age Band' AS BreakdownCategory1
	,AgeBand AS Breakdown1
	,'None' AS BreakdownCategory2
	,NULL AS Breakdown2
	,COUNT(*) AS [Active spells] -- not really needed 
	,SUM(Der_Open) AS [Open spells]
	,SUM(Der_Open) AS [Open spells2] -- denom for CRFD measures 
	,SUM(Der_RP_BedDays) AS [Total bed days]
	,SUM(Der_RP_BedDays) AS [Total bed days2] -- denom for CRFD measures
	,SUM(Der_RP_BedDays-HomeLeaveDaysEndRP-LOADaysRP) AS [Total bed days less leave]
	,SUM(CRfD_Open) AS [Open and CRFD]
	,SUM(CRfD_Days) AS [CRFD Days (spells)]

FROM MHDInternal.Temp_AcuteDash_Master  

GROUP BY ReportingPeriodStartDate,ReportingPeriodEndDate,[Provider code],[Provider name],[subICB code],[subICB name],[ICB code]
	,[ICB name],[Region code],[Region name],BedType_last, BedType_last_Category, AgeBand

-- OPEN SPELL - ETHNICITY
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_OpenSpells_Demo
SELECT
	ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,BedType_last as [Bed Type] 
	,BedType_last_Category as [Bed Type Category]
	,'Upper Ethnicity' AS BreakdownCategory1
	,UpperEthnicity AS Breakdown1
	,'Lower Ethnicity' AS BreakdownCategory2
	,Der_EthnicFull AS Breakdown2
	,COUNT(*) AS [Active spells] -- not really needed 
	,SUM(Der_Open) AS [Open spells]
	,SUM(Der_Open) AS [Open spells2] -- denom for CRFD measures 
	,SUM(Der_RP_BedDays) AS [Total bed days]
	,SUM(Der_RP_BedDays) AS [Total bed days2] -- denom for CRFD measures
	,SUM(Der_RP_BedDays-HomeLeaveDaysEndRP-LOADaysRP) AS [Total bed days less leave]
	,SUM(CRfD_Open) AS [Open and CRFD]
	,SUM(CRfD_Days) AS [CRFD Days (spells)]

FROM MHDInternal.Temp_AcuteDash_Master  

GROUP BY ReportingPeriodStartDate,ReportingPeriodEndDate,[Provider code],[Provider name],[subICB code],[subICB name],[ICB code]
	,[ICB name],[Region code],[Region name],BedType_last, BedType_last_Category, UpperEthnicity, Der_EthnicFull

-- OPEN SPELL - IMD DECILE
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_OpenSpells_Demo
SELECT
	ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,BedType_last as [Bed Type] 
	,BedType_last_Category as [Bed Type Category]
	,'IMD Decile' AS BreakdownCategory1
	,IMD_Decile AS Breakdown1
	,'None' AS BreakdownCategory2
	,NULL AS Breakdown2
	,COUNT(*) AS [Active spells] -- not really needed 
	,SUM(Der_Open) AS [Open spells]
	,SUM(Der_Open) AS [Open spells2] -- denom for CRFD measures 
	,SUM(Der_RP_BedDays) AS [Total bed days]
	,SUM(Der_RP_BedDays) AS [Total bed days2] -- denom for CRFD measures
	,SUM(Der_RP_BedDays-HomeLeaveDaysEndRP-LOADaysRP) AS [Total bed days less leave]
	,SUM(CRfD_Open) AS [Open and CRFD]
	,SUM(CRfD_Days) AS [CRFD Days (spells)]

FROM MHDInternal.Temp_AcuteDash_Master  

GROUP BY ReportingPeriodStartDate,ReportingPeriodEndDate,[Provider code],[Provider name],[subICB code],[subICB name],[ICB code]
	,[ICB name],[Region code],[Region name],BedType_last, BedType_last_Category, IMD_Decile

-- OPEN SPELL - LD STATUS
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_OpenSpells_Demo
SELECT
	ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,BedType_last as [Bed Type] 
	,BedType_last_Category as [Bed Type Category]
	,'LD Status' AS BreakdownCategory1
	,LDStatus AS Breakdown1
	,'None' AS BreakdownCategory2
	,NULL AS Breakdown2
	,COUNT(*) AS [Active spells] -- not really needed 
	,SUM(Der_Open) AS [Open spells]
	,SUM(Der_Open) AS [Open spells2] -- denom for CRFD measures 
	,SUM(Der_RP_BedDays) AS [Total bed days]
	,SUM(Der_RP_BedDays) AS [Total bed days2] -- denom for CRFD measures
	,SUM(Der_RP_BedDays-HomeLeaveDaysEndRP-LOADaysRP) AS [Total bed days less leave]
	,SUM(CRfD_Open) AS [Open and CRFD]
	,SUM(CRfD_Days) AS [CRFD Days (spells)]

FROM MHDInternal.Temp_AcuteDash_Master  

GROUP BY ReportingPeriodStartDate,ReportingPeriodEndDate,[Provider code],[Provider name],[subICB code],[subICB name],[ICB code]
	,[ICB name],[Region code],[Region name],BedType_last, BedType_last_Category, LDStatus


-- OPEN SPELL - AUTISM STATUS
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_OpenSpells_Demo
SELECT
	ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,BedType_last as [Bed Type] 
	,BedType_last_Category as [Bed Type Category]
	,'Autism Status' AS BreakdownCategory1
	,AutismStatus AS Breakdown1
	,'None' AS BreakdownCategory2
	,NULL AS Breakdown2
	,COUNT(*) AS [Active spells] -- not really needed 
	,SUM(Der_Open) AS [Open spells]
	,SUM(Der_Open) AS [Open spells2] -- denom for CRFD measures 
	,SUM(Der_RP_BedDays) AS [Total bed days]
	,SUM(Der_RP_BedDays) AS [Total bed days2] -- denom for CRFD measures
	,SUM(Der_RP_BedDays-HomeLeaveDaysEndRP-LOADaysRP) AS [Total bed days less leave]
	,SUM(CRfD_Open) AS [Open and CRFD]
	,SUM(CRfD_Days) AS [CRFD Days (spells)]

FROM MHDInternal.Temp_AcuteDash_Master  

GROUP BY ReportingPeriodStartDate,ReportingPeriodEndDate,[Provider code],[Provider name],[subICB code],[subICB name],[ICB code]
	,[ICB name],[Region code],[Region name],BedType_last, BedType_last_Category, AutismStatus
	
/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
HOSPITAL SPELL - DISCHARGE METRICS INCLUDING LOS BY DEMOGRAPHIC BREAKDOWNS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_Agg_Discharge_Demo') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_Agg_Discharge_Demo

-- Define schema and data types to prevent truncate issue when inserting data
CREATE TABLE MHDInternal.Temp_AcuteDash_Agg_Discharge_Demo(
ReportingPeriodStartDate DATE
,ReportingPeriodEndDate DATE
,[Provider code] VARCHAR(200)
,[Provider name] VARCHAR(200)
,[subICB code] VARCHAR(200)
,[subICB name] VARCHAR(200)
,[ICB code] VARCHAR(200)
,[ICB name] VARCHAR(200)
,[Region code] VARCHAR(200)
,[Region name] VARCHAR(200)
,[Bed Type] VARCHAR(200)
,[Bed Type Category] VARCHAR(200)
,BreakdownCategory1 VARCHAR(200)
,Breakdown1 VARCHAR(200)
,BreakdownCategory2 VARCHAR(200)
,Breakdown2 VARCHAR(200)
,Discharges BIGINT
,Discharges2 BIGINT
,[Discharges eligible for readmission] BIGINT
,[Readmitted 14 days] BIGINT
,[LOS over 60 days] BIGINT
,[LOS over 90 days] BIGINT
,[LOS less than 3 days] BIGINT
,[Total LOS] BIGINT
,[Total LOS excl CRFD] BIGINT
,[Total ln LOS] BIGINT
)

-- DISCHARGES - GENDER
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_Discharge_Demo
SELECT 
	ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,BedType_last as [Bed Type] 
	,BedType_last_Category as [Bed Type Category]
	,'Gender' AS BreakdownCategory1
	,Gender AS Breakdown1
	,'None' AS BreakdownCategory2
	,NULL AS Breakdown2
	,SUM(Der_Discharge) AS Discharges 
	,SUM(Der_Discharge) AS Discharges2 -- denom for LOS measures  
	,SUM(Der_ReAdm_Flag) AS [Discharges eligible for readmission] -- denom for readmission measure
	,SUM(CASE WHEN TimetoReadm < 14 THEN 1 ELSE 0 END) AS [Readmitted 14 days]
	,SUM(CASE WHEN Der_LOS >= 60 THEN 1 ELSE 0 END) AS [LOS over 60 days]
	,SUM(CASE WHEN Der_LOS >= 90 THEN 1 ELSE 0 END) AS [LOS over 90 days]
	,SUM(CASE WHEN Der_LOS < 3 THEN 1 ELSE 0 END) AS [LOS less than 3 days]
	,SUM(Der_LOS) AS [Total LOS] -- for mean LOS 
	,SUM(Der_LOS-ISNULL(CRFD_Length,0)) AS [Total LOS excl CRFD] -- potential mean LOS if there was no CRFD
	,SUM(LOG(Der_LOS)) AS [Total ln LOS] -- for creating geometric mean 

FROM MHDInternal.Temp_AcuteDash_Master  

WHERE Der_Discharge = 1 

GROUP BY ReportingPeriodStartDate,ReportingPeriodEndDate,[Provider code],[Provider name],[subICB code],[subICB name],[ICB code]
	,[ICB name],[Region code],[Region name],BedType_last, BedType_last_Category, Gender

-- DISCHARGES - AGE BAND
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_Discharge_Demo
SELECT 
	ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,BedType_last as [Bed Type] 
	,BedType_last_Category as [Bed Type Category]
	,'Age Band' AS BreakdownCategory1
	,AgeBand AS Breakdown1
	,'None' AS BreakdownCategory2
	,NULL AS Breakdown2
	,SUM(Der_Discharge) AS Discharges 
	,SUM(Der_Discharge) AS Discharges2 -- denom for LOS measures  
	,SUM(Der_ReAdm_Flag) AS [Discharges eligible for readmission] -- denom for readmission measure
	,SUM(CASE WHEN TimetoReadm < 14 THEN 1 ELSE 0 END) AS [Readmitted 14 days]
	,SUM(CASE WHEN Der_LOS >= 60 THEN 1 ELSE 0 END) AS [LOS over 60 days]
	,SUM(CASE WHEN Der_LOS >= 90 THEN 1 ELSE 0 END) AS [LOS over 90 days]
	,SUM(CASE WHEN Der_LOS < 3 THEN 1 ELSE 0 END) AS [LOS less than 3 days]
	,SUM(Der_LOS) AS [Total LOS] -- for mean LOS 
	,SUM(Der_LOS-ISNULL(CRFD_Length,0)) AS [Total LOS excl CRFD] -- potential mean LOS if there was no CRFD
	,SUM(LOG(Der_LOS)) AS [Total ln LOS] -- for creating geometric mean 

FROM MHDInternal.Temp_AcuteDash_Master  

WHERE Der_Discharge = 1 

GROUP BY ReportingPeriodStartDate,ReportingPeriodEndDate,[Provider code],[Provider name],[subICB code],[subICB name],[ICB code]
	,[ICB name],[Region code],[Region name],BedType_last ,BedType_last_Category, AgeBand

-- DISCHARGES - ETHNICITY
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_Discharge_Demo
SELECT 
	ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,BedType_last as [Bed Type] 
	,BedType_last_Category as [Bed Type Category]
	,'Upper Ethnicity' AS BreakdownCategory1
	,UpperEthnicity AS Breakdown1
	,'Lower Ethnicity' AS BreakdownCategory2
	,Der_EthnicFull AS Breakdown2
	,SUM(Der_Discharge) AS Discharges 
	,SUM(Der_Discharge) AS Discharges2 -- denom for LOS measures  
	,SUM(Der_ReAdm_Flag) AS [Discharges eligible for readmission] -- denom for readmission measure
	,SUM(CASE WHEN TimetoReadm < 14 THEN 1 ELSE 0 END) AS [Readmitted 14 days]
	,SUM(CASE WHEN Der_LOS >= 60 THEN 1 ELSE 0 END) AS [LOS over 60 days]
	,SUM(CASE WHEN Der_LOS >= 90 THEN 1 ELSE 0 END) AS [LOS over 90 days]
	,SUM(CASE WHEN Der_LOS < 3 THEN 1 ELSE 0 END) AS [LOS less than 3 days]
	,SUM(Der_LOS) AS [Total LOS] -- for mean LOS 
	,SUM(Der_LOS-ISNULL(CRFD_Length,0)) AS [Total LOS excl CRFD] -- potential mean LOS if there was no CRFD
	,SUM(LOG(Der_LOS)) AS [Total ln LOS] -- for creating geometric mean 

FROM MHDInternal.Temp_AcuteDash_Master  

WHERE Der_Discharge = 1 

GROUP BY ReportingPeriodStartDate,ReportingPeriodEndDate,[Provider code],[Provider name],[subICB code],[subICB name],[ICB code]
	,[ICB name],[Region code],[Region name],BedType_last,BedType_last_Category, UpperEthnicity, Der_EthnicFull

-- DISCHARGES - IMD Decile
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_Discharge_Demo
SELECT 
	ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,BedType_last as [Bed Type] 
	,BedType_last_Category as [Bed Type Category]
	,'IMD Decile' AS BreakdownCategory1
	,IMD_Decile AS Breakdown1
	,'None' AS BreakdownCategory2
	,NULL AS Breakdown2
	,SUM(Der_Discharge) AS Discharges 
	,SUM(Der_Discharge) AS Discharges2 -- denom for LOS measures  
	,SUM(Der_ReAdm_Flag) AS [Discharges eligible for readmission] -- denom for readmission measure
	,SUM(CASE WHEN TimetoReadm < 14 THEN 1 ELSE 0 END) AS [Readmitted 14 days]
	,SUM(CASE WHEN Der_LOS >= 60 THEN 1 ELSE 0 END) AS [LOS over 60 days]
	,SUM(CASE WHEN Der_LOS >= 90 THEN 1 ELSE 0 END) AS [LOS over 90 days]
	,SUM(CASE WHEN Der_LOS < 3 THEN 1 ELSE 0 END) AS [LOS less than 3 days]
	,SUM(Der_LOS) AS [Total LOS] -- for mean LOS 
	,SUM(Der_LOS-ISNULL(CRFD_Length,0)) AS [Total LOS excl CRFD] -- potential mean LOS if there was no CRFD
	,SUM(LOG(Der_LOS)) AS [Total ln LOS] -- for creating geometric mean 

FROM MHDInternal.Temp_AcuteDash_Master  

WHERE Der_Discharge = 1 

GROUP BY ReportingPeriodStartDate,ReportingPeriodEndDate,[Provider code],[Provider name],[subICB code],[subICB name],[ICB code]
	,[ICB name],[Region code],[Region name],BedType_last ,BedType_last_Category, IMD_Decile

-- DISCHARGES - LD STATUS
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_Discharge_Demo
SELECT 
	ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,BedType_last as [Bed Type] 
	,BedType_last_Category as [Bed Type Category]
	,'LD Status' AS BreakdownCategory1
	,LDStatus AS Breakdown1
	,'None' AS BreakdownCategory2
	,NULL AS Breakdown2
	,SUM(Der_Discharge) AS Discharges 
	,SUM(Der_Discharge) AS Discharges2 -- denom for LOS measures  
	,SUM(Der_ReAdm_Flag) AS [Discharges eligible for readmission] -- denom for readmission measure
	,SUM(CASE WHEN TimetoReadm < 14 THEN 1 ELSE 0 END) AS [Readmitted 14 days]
	,SUM(CASE WHEN Der_LOS >= 60 THEN 1 ELSE 0 END) AS [LOS over 60 days]
	,SUM(CASE WHEN Der_LOS >= 90 THEN 1 ELSE 0 END) AS [LOS over 90 days]
	,SUM(CASE WHEN Der_LOS < 3 THEN 1 ELSE 0 END) AS [LOS less than 3 days]
	,SUM(Der_LOS) AS [Total LOS] -- for mean LOS 
	,SUM(Der_LOS-ISNULL(CRFD_Length,0)) AS [Total LOS excl CRFD] -- potential mean LOS if there was no CRFD
	,SUM(LOG(Der_LOS)) AS [Total ln LOS] -- for creating geometric mean 

FROM MHDInternal.Temp_AcuteDash_Master  

WHERE Der_Discharge = 1 

GROUP BY ReportingPeriodStartDate,ReportingPeriodEndDate,[Provider code],[Provider name],[subICB code],[subICB name],[ICB code]
	,[ICB name],[Region code],[Region name],BedType_last ,BedType_last_Category, LDStatus


-- DISCHARGES - AUTISM STATUS
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_Discharge_Demo
SELECT 
	ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,BedType_last as [Bed Type] 
	,BedType_last_Category as [Bed Type Category]
	,'Autism Status' AS BreakdownCategory1
	,AutismStatus AS Breakdown1
	,'None' AS BreakdownCategory2
	,NULL AS Breakdown2
	,SUM(Der_Discharge) AS Discharges 
	,SUM(Der_Discharge) AS Discharges2 -- denom for LOS measures  
	,SUM(Der_ReAdm_Flag) AS [Discharges eligible for readmission] -- denom for readmission measure
	,SUM(CASE WHEN TimetoReadm < 14 THEN 1 ELSE 0 END) AS [Readmitted 14 days]
	,SUM(CASE WHEN Der_LOS >= 60 THEN 1 ELSE 0 END) AS [LOS over 60 days]
	,SUM(CASE WHEN Der_LOS >= 90 THEN 1 ELSE 0 END) AS [LOS over 90 days]
	,SUM(CASE WHEN Der_LOS < 3 THEN 1 ELSE 0 END) AS [LOS less than 3 days]
	,SUM(Der_LOS) AS [Total LOS] -- for mean LOS 
	,SUM(Der_LOS-ISNULL(CRFD_Length,0)) AS [Total LOS excl CRFD] -- potential mean LOS if there was no CRFD
	,SUM(LOG(Der_LOS)) AS [Total ln LOS] -- for creating geometric mean 

FROM MHDInternal.Temp_AcuteDash_Master  

WHERE Der_Discharge = 1 

GROUP BY ReportingPeriodStartDate,ReportingPeriodEndDate,[Provider code],[Provider name],[subICB code],[subICB name],[ICB code]
	,[ICB name],[Region code],[Region name],BedType_last ,BedType_last_Category, AutismStatus
	
/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
AGGREGATE CLINICALLY READY FOR DISCHARGE EPISODES BY DEMOGRAPHIC BREAKDOWNS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('MHDInternal.Temp_AcuteDash_Agg_CRFD_Demo') IS NOT NULL
DROP TABLE MHDInternal.Temp_AcuteDash_Agg_CRFD_Demo

-- Define schema and data types to prevent truncate issue when inserting data
CREATE TABLE MHDInternal.Temp_AcuteDash_Agg_CRFD_Demo(
ReportingPeriodStartDate DATE
,ReportingPeriodEndDate DATE
,[Provider code] VARCHAR(200)
,[Provider name] VARCHAR(200)
,[subICB code] VARCHAR(200)
,[subICB name] VARCHAR(200)
,[ICB code] VARCHAR(200)
,[ICB name] VARCHAR(200)
,[Region code] VARCHAR(200)
,[Region name] VARCHAR(200)
,[Bed Type]  VARCHAR(200)
,[Bed Type Category] VARCHAR(200)
,BreakdownCategory1 VARCHAR(200)
,Breakdown1 VARCHAR(200)
,BreakdownCategory2 VARCHAR(200)
,Breakdown2 VARCHAR(200)
,[CRFD episodes] BIGINT
,[CRFD started] BIGINT
,[CRFD open] BIGINT
,[CRFD ended] BIGINT
,[CRFD closed length] BIGINT
,[CRFD log lenth] BIGINT
,[CRFD Days] BIGINT
)

-- CRFD - GENDER
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_CRFD_Demo
SELECT 
	c.ReportingPeriodStartDate
	,c.ReportingPeriodEndDate
	,c.[Provider code]
	,c.[Provider name]
	,c.[subICB code]
	,c.[subICB name]
	,c.[ICB code]
	,c.[ICB name]
	,c.[Region code]
	,c.[Region name]
	,c.BedType_last as [Bed Type] 
	,c.BedType_last_Category as [Bed Type Category]
	,'Gender' AS BreakdownCategory1
	,Gender AS Breakdown1
	,'None' AS BreakdownCategory2
	,NULL AS Breakdown2
	,COUNT(*) AS [CRFD episodes] -- might not need to report this 
	,SUM(Der_CRFD_Started) AS [CRFD started]
	,SUM(Der_CRFD_Open) AS [CRFD open]
	,SUM(Der_CRFD_Ended) AS [CRFD ended]
	,SUM(Der_CRFD_Length) AS [CRFD closed length]
	,SUM(LOG(Der_CRFD_Length)) AS [CRFD log lenth] -- for gemotric mean
	,SUM(c.CRfD_Days) AS [CRFD Days]

FROM MHDInternal.Temp_AcuteDash_CRFDMaster c

LEFT JOIN MHDInternal.Temp_AcuteDash_Master a ON c.UniqHospProvSpellID = a.UniqHospProvSpellNum AND a.RecordNumber = c.RecordNumber

GROUP BY c.ReportingPeriodStartDate,c.ReportingPeriodEndDate,c.[Provider code],c.[Provider name],c.[subICB code],c.[subICB name],c.[ICB code]
	,c.[ICB name],c.[Region code],c.[Region name],c.BedType_last ,c.BedType_last_Category, Gender

-- CRFD - AGE BAND
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_CRFD_Demo
SELECT 
	c.ReportingPeriodStartDate
	,c.ReportingPeriodEndDate
	,c.[Provider code]
	,c.[Provider name]
	,c.[subICB code]
	,c.[subICB name]
	,c.[ICB code]
	,c.[ICB name]
	,c.[Region code]
	,c.[Region name]
	,c.BedType_last as [Bed Type] 
	,c.BedType_last_Category as [Bed Type Category]
	,'Age Band' AS BreakdownCategory1
	,AgeBand AS Breakdown1
	,'None' AS BreakdownCategory2
	,NULL AS Breakdown2
	,COUNT(*) AS [CRFD episodes] -- might not need to report this 
	,SUM(Der_CRFD_Started) AS [CRFD started]
	,SUM(Der_CRFD_Open) AS [CRFD open]
	,SUM(Der_CRFD_Ended) AS [CRFD ended]
	,SUM(Der_CRFD_Length) AS [CRFD closed length]
	,SUM(LOG(Der_CRFD_Length)) AS [CRFD log lenth] -- for gemotric mean
	,SUM(c.CRfD_Days) AS [CRFD Days]

FROM MHDInternal.Temp_AcuteDash_CRFDMaster c

LEFT JOIN MHDInternal.Temp_AcuteDash_Master a ON c.UniqHospProvSpellID = a.UniqHospProvSpellNum AND a.RecordNumber = c.RecordNumber

GROUP BY c.ReportingPeriodStartDate,c.ReportingPeriodEndDate,c.[Provider code],c.[Provider name],c.[subICB code],c.[subICB name],c.[ICB code]
	,c.[ICB name],c.[Region code],c.[Region name],c.BedType_last ,c.BedType_last_Category, AgeBand

-- CRFD - ETHNICITY
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_CRFD_Demo
SELECT 
	c.ReportingPeriodStartDate
	,c.ReportingPeriodEndDate
	,c.[Provider code]
	,c.[Provider name]
	,c.[subICB code]
	,c.[subICB name]
	,c.[ICB code]
	,c.[ICB name]
	,c.[Region code]
	,c.[Region name]
	,c.BedType_last as [Bed Type] 
	,c.BedType_last_Category as [Bed Type Category]
	,'Upper Ethnicity' AS BreakdownCategory3
	,UpperEthnicity AS Breakdown3
	,'Lower Ethnicity' AS BreakdownCategory4
	,Der_EthnicFull AS Breakdown4
	,COUNT(*) AS [CRFD episodes] -- might not need to report this 
	,SUM(Der_CRFD_Started) AS [CRFD started]
	,SUM(Der_CRFD_Open) AS [CRFD open]
	,SUM(Der_CRFD_Ended) AS [CRFD ended]
	,SUM(Der_CRFD_Length) AS [CRFD closed length]
	,SUM(LOG(Der_CRFD_Length)) AS [CRFD log lenth] -- for gemotric mean
	,SUM(c.CRfD_Days) AS [CRFD Days]

FROM MHDInternal.Temp_AcuteDash_CRFDMaster c

LEFT JOIN MHDInternal.Temp_AcuteDash_Master a ON c.UniqHospProvSpellID = a.UniqHospProvSpellNum AND a.RecordNumber = c.RecordNumber

GROUP BY c.ReportingPeriodStartDate,c.ReportingPeriodEndDate,c.[Provider code],c.[Provider name],c.[subICB code],c.[subICB name],c.[ICB code]
	,c.[ICB name],c.[Region code],c.[Region name],c.BedType_last ,c.BedType_last_Category, UpperEthnicity, Der_EthnicFull


-- CRFD - IMD DECILE
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_CRFD_Demo
SELECT 
	c.ReportingPeriodStartDate
	,c.ReportingPeriodEndDate
	,c.[Provider code]
	,c.[Provider name]
	,c.[subICB code]
	,c.[subICB name]
	,c.[ICB code]
	,c.[ICB name]
	,c.[Region code]
	,c.[Region name]
	,c.BedType_last as [Bed Type] 
	,c.BedType_last_Category as [Bed Type Category]
	,'IMD Decile' AS BreakdownCategory1
	,IMD_Decile AS Breakdown1
	,'None' AS BreakdownCategory2
	,NULL AS Breakdown2
	,COUNT(*) AS [CRFD episodes] -- might not need to report this 
	,SUM(Der_CRFD_Started) AS [CRFD started]
	,SUM(Der_CRFD_Open) AS [CRFD open]
	,SUM(Der_CRFD_Ended) AS [CRFD ended]
	,SUM(Der_CRFD_Length) AS [CRFD closed length]
	,SUM(LOG(Der_CRFD_Length)) AS [CRFD log lenth] -- for gemotric mean
	,SUM(c.CRfD_Days) AS [CRFD Days]

FROM MHDInternal.Temp_AcuteDash_CRFDMaster c

LEFT JOIN MHDInternal.Temp_AcuteDash_Master a ON c.UniqHospProvSpellID = a.UniqHospProvSpellNum AND a.RecordNumber = c.RecordNumber

GROUP BY c.ReportingPeriodStartDate,c.ReportingPeriodEndDate,c.[Provider code],c.[Provider name],c.[subICB code],c.[subICB name],c.[ICB code]
	,c.[ICB name],c.[Region code],c.[Region name],c.BedType_last ,c.BedType_last_Category, IMD_Decile

-- CRFD - LD STATUS
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_CRFD_Demo
SELECT 
	c.ReportingPeriodStartDate
	,c.ReportingPeriodEndDate
	,c.[Provider code]
	,c.[Provider name]
	,c.[subICB code]
	,c.[subICB name]
	,c.[ICB code]
	,c.[ICB name]
	,c.[Region code]
	,c.[Region name]
	,c.BedType_last as [Bed Type] 
	,c.BedType_last_Category as [Bed Type Category]
	,'LD Status' AS BreakdownCategory1
	,LDStatus AS Breakdown1
	,'None' AS BreakdownCategory2
	,NULL AS Breakdown2
	,COUNT(*) AS [CRFD episodes] -- might not need to report this 
	,SUM(Der_CRFD_Started) AS [CRFD started]
	,SUM(Der_CRFD_Open) AS [CRFD open]
	,SUM(Der_CRFD_Ended) AS [CRFD ended]
	,SUM(Der_CRFD_Length) AS [CRFD closed length]
	,SUM(LOG(Der_CRFD_Length)) AS [CRFD log lenth] -- for gemotric mean
	,SUM(c.CRfD_Days) AS [CRFD Days]

FROM MHDInternal.Temp_AcuteDash_CRFDMaster c

LEFT JOIN MHDInternal.Temp_AcuteDash_Master a ON c.UniqHospProvSpellID = a.UniqHospProvSpellNum AND a.RecordNumber = c.RecordNumber

GROUP BY c.ReportingPeriodStartDate,c.ReportingPeriodEndDate,c.[Provider code],c.[Provider name],c.[subICB code],c.[subICB name],c.[ICB code]
	,c.[ICB name],c.[Region code],c.[Region name],c.BedType_last ,c.BedType_last_Category, LDStatus


-- CRFD - AUTISM STATUS
INSERT INTO MHDInternal.Temp_AcuteDash_Agg_CRFD_Demo
SELECT 
	c.ReportingPeriodStartDate
	,c.ReportingPeriodEndDate
	,c.[Provider code]
	,c.[Provider name]
	,c.[subICB code]
	,c.[subICB name]
	,c.[ICB code]
	,c.[ICB name]
	,c.[Region code]
	,c.[Region name]
	,c.BedType_last as [Bed Type] 
	,c.BedType_last_Category as [Bed Type Category]
	,'Autism Status' AS BreakdownCategory1
	,AutismStatus AS Breakdown1
	,'None' AS BreakdownCategory2
	,NULL AS Breakdown2
	,COUNT(*) AS [CRFD episodes] -- might not need to report this 
	,SUM(Der_CRFD_Started) AS [CRFD started]
	,SUM(Der_CRFD_Open) AS [CRFD open]
	,SUM(Der_CRFD_Ended) AS [CRFD ended]
	,SUM(Der_CRFD_Length) AS [CRFD closed length]
	,SUM(LOG(Der_CRFD_Length)) AS [CRFD log lenth] -- for gemotric mean
	,SUM(c.CRfD_Days) AS [CRFD Days]

FROM MHDInternal.Temp_AcuteDash_CRFDMaster c

LEFT JOIN MHDInternal.Temp_AcuteDash_Master a ON c.UniqHospProvSpellID = a.UniqHospProvSpellNum AND a.RecordNumber = c.RecordNumber

GROUP BY c.ReportingPeriodStartDate,c.ReportingPeriodEndDate,c.[Provider code],c.[Provider name],c.[subICB code],c.[subICB name],c.[ICB code]
	,c.[ICB name],c.[Region code],c.[Region name],c.BedType_last ,c.BedType_last_Category, AutismStatus
	
/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
UNPIVOT FOR DASHBOARD OUTPUT 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('MHDInternal.Dashboard_MH_InpatientDashboard') IS NOT NULL
DROP TABLE MHDInternal.Dashboard_MH_InpatientDashboard

SELECT
	'Hospital admissions' AS DashboardSection
	,ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,[Bed Type]
	,[Bed Type Category]
	,'Main' AS BreakdownGroup
	,CAST(BreakdownCategory1 AS nvarchar(35)) AS BreakdownCategory1
	,CAST(Breakdown1 AS nvarchar(105)) AS Breakdown1
	,CAST(BreakdownCategory2 AS nvarchar(35)) AS BreakdownCategory2
	,CAST(Breakdown2 AS nvarchar(105)) AS Breakdown2
	,MeasureName
	,MeasureValue
	,CASE 
		WHEN MeasureName = 'NoPrevContact' THEN NoContactAdm_flag 
	ELSE NULL 
	END AS Denominator 

INTO MHDInternal.Dashboard_MH_InpatientDashboard

FROM MHDInternal.Temp_AcuteDash_Agg_Admissions 

UNPIVOT (MeasureValue FOR MeasureName IN 
		(Admissions, NoPrevContact)) u 


INSERT INTO MHDInternal.Dashboard_MH_InpatientDashboard

SELECT
	'Open spells' as DashboardSection
	,ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,[Bed Type]
	,[Bed Type Category]
	,'Main' AS BreakdownGroup
	,BreakdownCategory1
	,Breakdown1
	,BreakdownCategory2
	,Breakdown2
	,MeasureName
	,MeasureValue
	,CASE 
		WHEN MeasureName = 'Open and CRFD' THEN [Open spells2]
		WHEN MeasureName = 'CRFD Days (spells)' THEN [Total bed days2]
	ELSE NULL 
	END AS Denominator 

FROM MHDInternal.Temp_AcuteDash_Agg_OpenSpells

UNPIVOT (MeasureValue FOR MeasureName IN 
		([Open spells],[Total bed days],[Total bed days less leave], [Open and CRFD],[CRFD Days (spells)])) u



INSERT INTO MHDInternal.Dashboard_MH_InpatientDashboard

SELECT
	'Discharges & LOS' AS DashboardSection
	,ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,[Bed Type]
	,[Bed Type Category]
	,'Main' AS BreakdownGroup
	,BreakdownCategory1
	,Breakdown1
	,BreakdownCategory2
	,Breakdown2
	,MeasureName
	,MeasureValue
	,CASE 
		WHEN MeasureName = 'Readmitted 14 days' THEN [Discharges eligible for readmission] 
		WHEN MeasureName IN ('LOS over 60 days','LOS over 90 days','Total LOS','Total LOS excl CRFD','Total ln LOS','LOS less than 3 days') THEN Discharges2 
	ELSE NULL 
	END AS Denominator 

FROM MHDInternal.Temp_AcuteDash_Agg_Discharge 

UNPIVOT (MeasureValue FOR MeasureName IN 
		([Discharges],[Readmitted 14 days], [LOS over 60 days],[LOS over 90 days],[LOS less than 3 days],[Total LOS],[Total LOS excl CRFD])) u -- leave ln LOS for now... 


INSERT INTO MHDInternal.Dashboard_MH_InpatientDashboard

SELECT 
	'CRfD' AS DashboardSection
	,ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,[Bed Type]
	,[Bed Type Category]
	,'Main' AS BreakdownGroup
	,BreakdownCategory1
	,Breakdown1
	,BreakdownCategory2
	,Breakdown2
	,MeasureName
	,MeasureValue
	,CASE 
		WHEN MeasureName = 'CRFD closed length' THEN [CRFD ended] 
	ELSE NULL 
	END AS Denominator 

FROM MHDInternal.Temp_AcuteDash_Agg_CRFD

UNPIVOT (MeasureValue FOR MeasureName IN 
		([CRFD started],[CRFD open],[CRFD closed length],[CRFD Days])) u -- leave ln LOS for now... 


INSERT INTO MHDInternal.Dashboard_MH_InpatientDashboard

SELECT 
	'Wards' AS DashboardSection
	,ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,BedType AS [Bed Type]
	,BedType_Category AS [Bed Type Category]
	,'Main' AS BreakdownGroup
	,BreakdownCategory1
	,Breakdown1
	,BreakdownCategory2
	,Breakdown2
	,MeasureName
	,MeasureValue
	,CASE 
		WHEN MeasureName IN ('Val_AvailableBedDays','Val_TotalBedDays') THEN [WardMonthCount]
		WHEN MeasureName IN ('ClosedBedDays') THEN Total_BedDays -- closed bed days denom needs to be adjusted to also include numerator 
        	WHEN MeasureName IN ('Occupied_BedDays','Unoccupied_BedDays') THEN AvailBedDays2
	ELSE NULL 
	END AS Denominator 

FROM MHDInternal.Temp_AcuteDash_Agg_Wards

UNPIVOT (MeasureValue FOR MeasureName IN 
		([Val_AvailableBedDays],[Val_TotalBedDays],[AvailBedDays],[ClosedBedDays],[Occupied_BedDays],[Unoccupied_BedDays],[WS_Started],[WS_Open],[WS_Ended])) u  

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
UNPIVOT FOR DASHBOARD OUTPUT - DEMOGRAPHIC BREAKDOWNS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO MHDInternal.Dashboard_MH_InpatientDashboard
SELECT
	'Hospital admissions' AS DashboardSection
	,ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,[Bed Type]
	,[Bed Type Category]
	,'Demo' AS BreakdownGroup
	,CAST(BreakdownCategory1 AS nvarchar(35)) AS BreakdownCategory1
	,CAST(Breakdown1 AS nvarchar(95)) AS Breakdown1
	,CAST(BreakdownCategory2 AS nvarchar(35)) AS BreakdownCategory2
	,CAST(Breakdown2 AS nvarchar(95)) AS Breakdown2
	,MeasureName
	,MeasureValue
	,CASE 
		WHEN MeasureName = 'NoPrevContact' THEN NoContactAdm_flag 
		WHEN MeasureName = 'DTA complete' THEN Admissions2
		WHEN MeasureName IN ('DTA - same time', 'DTA - <1 hour', 'DTA - 1-24 hours', 'DTA - 1-7 days', 'DTA - 7+ days') THEN [DTA complete2]
	ELSE NULL 
	END AS Denominator 

FROM MHDInternal.Temp_AcuteDash_Agg_Admissions_Demo 

UNPIVOT (MeasureValue FOR MeasureName IN 
		(Admissions, NoPrevContact, [DTA complete], [DTA - same time], [DTA - <1 hour], [DTA - 1-24 hours], [DTA - 1-7 days],[DTA - 7+ days])) u 


INSERT INTO MHDInternal.Dashboard_MH_InpatientDashboard

SELECT
	'Open spells' as DashboardSection
	,ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,[Bed Type]
	,[Bed Type Category]
	,'Demo' AS BreakdownGroup
	,BreakdownCategory1
	,Breakdown1
	,BreakdownCategory2
	,Breakdown2
	,MeasureName
	,MeasureValue
	,CASE 
		WHEN MeasureName = 'Open and CRFD' THEN [Open spells2]
		WHEN MeasureName = 'CRFD Days (spells)' THEN [Total bed days2]
	ELSE NULL 
	END AS Denominator 

FROM MHDInternal.Temp_AcuteDash_Agg_OpenSpells_Demo

UNPIVOT (MeasureValue FOR MeasureName IN 
		([Open spells],[Total bed days],[Total bed days less leave], [Open and CRFD],[CRFD Days (spells)])) u



INSERT INTO MHDInternal.Dashboard_MH_InpatientDashboard

SELECT
	'Discharges & LOS' AS DashboardSection
	,ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,[Bed Type]
	,[Bed Type Category]
	,'Demo' AS BreakdownGroup
	,BreakdownCategory1
	,Breakdown1
	,BreakdownCategory2
	,Breakdown2
	,MeasureName
	,MeasureValue
	,CASE 
		WHEN MeasureName = 'Readmitted 14 days' THEN [Discharges eligible for readmission] 
		WHEN MeasureName IN ('LOS over 60 days','LOS over 90 days','Total LOS','Total LOS excl CRFD','Total ln LOS','LOS less than 3 days') THEN Discharges2 
	ELSE NULL 
	END AS Denominator 

FROM MHDInternal.Temp_AcuteDash_Agg_Discharge_Demo 

UNPIVOT (MeasureValue FOR MeasureName IN 
		([Discharges],[Readmitted 14 days], [LOS over 60 days],[LOS over 90 days],[LOS less than 3 days],[Total LOS],[Total LOS excl CRFD])) u -- leave ln LOS for now... 


INSERT INTO MHDInternal.Dashboard_MH_InpatientDashboard

SELECT 
	'CRfD' AS DashboardSection
	,ReportingPeriodStartDate
	,ReportingPeriodEndDate
	,[Provider code]
	,[Provider name]
	,[subICB code]
	,[subICB name]
	,[ICB code]
	,[ICB name]
	,[Region code]
	,[Region name]
	,[Bed Type]
	,[Bed Type Category]
	,'Demo' AS BreakdownGroup
	,BreakdownCategory1
	,Breakdown1
	,BreakdownCategory2
	,Breakdown2
	,MeasureName
	,MeasureValue
	,CASE 
		WHEN MeasureName = 'CRFD closed length' THEN [CRFD ended] 
	ELSE NULL 
	END AS Denominator 

FROM MHDInternal.Temp_AcuteDash_Agg_CRFD_Demo

UNPIVOT (MeasureValue FOR MeasureName IN 
		([CRFD started],[CRFD open],[CRFD closed length],[CRFD Days])) u -- leave ln LOS for now...




/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
DROP TEMP TABLES 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DROP TABLE MHDInternal.Temp_AcuteDash_PatInd 
DROP TABLE MHDInternal.Temp_AcuteDash_FirstWS
DROP TABLE MHDInternal.Temp_AcuteDash_LatestWard
DROP TABLE MHDInternal.Temp_AcuteDash_Diag
DROP TABLE MHDInternal.Temp_AcuteDash_Spells
DROP TABLE MHDInternal.Temp_AcuteDash_PrevContact
DROP TABLE MHDInternal.Temp_AcuteDash_ReAdm
DROP TABLE MHDInternal.Temp_AcuteDash_HomeLeave
DROP TABLE MHDInternal.Temp_AcuteDash_LeaveofAbsence
DROP TABLE MHDInternal.Temp_AcuteDash_Restraint
DROP TABLE MHDInternal.Temp_AcuteDash_MHA
DROP TABLE MHDInternal.Temp_AcuteDash_CRFD
--DROP TABLE MHDInternal.Temp_AcuteDash_Master -- keep this, might be useful
DROP TABLE MHDInternal.Temp_AcuteDash_Wards
DROP TABLE MHDInternal.Temp_AcuteDash_WardStays
DROP TABLE MHDInternal.Temp_AcuteDash_WardCombined
DROP TABLE MHDInternal.Temp_AcuteDash_CRFDMaster
DROP TABLE MHDInternal.Temp_AcuteDash_Agg_Admissions
DROP TABLE MHDInternal.Temp_AcuteDash_Agg_OpenSpells
DROP TABLE MHDInternal.Temp_AcuteDash_Agg_Discharge
DROP TABLE MHDInternal.Temp_AcuteDash_Agg_CRFD
DROP TABLE MHDInternal.Temp_AcuteDash_Agg_Wards
DROP TABLE MHDInternal.Temp_AcuteDash_Agg_Admissions_Demo
DROP TABLE MHDInternal.Temp_AcuteDash_Agg_OpenSpells_Demo
DROP TABLE MHDInternal.Temp_AcuteDash_Agg_Discharge_Demo
DROP TABLE MHDInternal.Temp_AcuteDash_Agg_CRFD_Demo




DECLARE @EndRP INT

SET @EndRP = (SELECT UniqMonthID
FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header]
WHERE Der_MostRecentFlag = 'Y')

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP TWO - REFERRALS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
REFERRALS - DROP EXISTING INDEXES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Referral Drop Index Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - DROP INDEXES

DROP INDEX ix_Referral ON [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Referral]

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Referral Drop Index End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
REFERRALS - DELETE DATA THAT HAS BEEN SUPERCEDED BY OTHER DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Referral Delete Data Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - DELETE DATA

DELETE FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Referral] WHERE CONCAT(OrgIDProv,UniqMonthID) IN (SELECT CONCAT(OrgIDProvider,UniqMonthID) FROM NHSE_MH_PrePublication.Test.MHS000Header)

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Referral Delete Data End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
REFERRALS - JOIN MHS001 AND MHS102 TO MHS101 						
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Referral Insert Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - ALL DATA FROM LATEST WINDOW

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Referral] 

SELECT
	--header
	h.[ReportingPeriodStartDate],
    h.[ReportingPeriodEndDate],
	h.[Der_FY],
	--MPI
	m.[UniqSubmissionID],
	m.[NHSEUniqSubmissionID],
	m.[UniqMonthID],
	m.[OrgIDProv],
	m.[Der_Person_ID] AS Person_ID,
	m.[Der_Pseudo_NHS_Number],
	m.[RecordNumber],
	m.[MHS001UniqID],
	m.[OrgIDCCGRes],
	m.[OrgIDEduEstab],
	m.[EthnicCategory],
	NULL AS [EthnicCategory2021], --new for v5
	m.[Gender],
	NULL AS [GenderSameAtBirth], -- new for v5
	m.[MaritalStatus],
	m.[PersDeathDate],
	m.[AgeDeath],
	m.[LanguageCodePreferred],
	m.[ElectoralWard],
	m.[LADistrictAuth],
	m.[LSOA2011],
	m.[County],
	m.[NHSNumberStatus],
	m.[OrgIDLocalPatientId],
	m.[PostcodeDistrict],
	m.[DefaultPostcode],
	m.[AgeRepPeriodStart],
	m.[AgeRepPeriodEnd],
	--referral
	r.[MHS101UniqID],
	r.[UniqServReqID],
	r.[OrgIDComm],
	r.[ReferralRequestReceivedDate],
	r.[ReferralRequestReceivedTime],
	LEFT([NHSServAgreeLineNum],10) AS [NHSServAgreeLineNum],
	r.[SpecialisedMHServiceCode],
	r.[SourceOfReferralMH],
	r.[OrgIDReferring],
	r.[ReferringCareProfessionalStaffGroup],
	r.[ClinRespPriorityType],
	r.[PrimReasonReferralMH],
	r.[ReasonOAT],
	NULL AS [DecisionToTreatDate], --new for v5
	NULL AS [DecisionToTreatTime], --new for v5
	r.[DischPlanCreationDate],
	r.[DischPlanCreationTime],
	r.[DischPlanLastUpdatedDate],
	r.[DischPlanLastUpdatedTime],
	r.[ServDischDate],
	r.[ServDischTime],
	r.[AgeServReferRecDate],
	r.[AgeServReferDischDate],
	--serv / team type
	s.[MHS102UniqID],
	s.[UniqCareProfTeamID],
	s.[ServTeamTypeRefToMH],
	s.[ReferClosureDate],
	s.[ReferClosureTime],
	s.[ReferRejectionDate],
	s.[ReferRejectionTime],
	s.[ReferClosReason],
	s.[ReferRejectReason],
	s.[AgeServReferClosure],
	s.[AgeServReferRejection]

FROM NHSE_MH_PrePublication.Test.MHS101Referral r

INNER JOIN NHSE_MH_PrePublication.Test.MHS001MPI m ON r.RecordNumber = m.RecordNumber

LEFT JOIN NHSE_MH_PrePublication.Test.MHS102ServiceTypeReferredTo s ON r.UniqServReqID = s.UniqServReqID AND r.RecordNumber = s.RecordNumber 

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Header h ON h.UniqMonthID = r.UniqMonthID

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Referral Insert End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'
	
/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
REFERRALS - RECREATE INDEXES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Referral Create Index Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - CREATE INDEXES

CREATE INDEX ix_Referral ON [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Referral] ([UniqMonthID], [RecordNumber], [OrgIDProv], [Person_ID], [UniqServReqID])

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Referral Create Index End' AS Step,
	GETDATE() AS [TimeStamp]

USE [NHSE_Sandbox_MentalHealth]
GO

/****** Object:  Table [dbo].[PreProc_Referral]    Script Date: 27/05/2021 13:36:43 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[PreProc_Referral](
	--core bits	
	[Der_RecordID] [int] IDENTITY(1,1) NOT NULL,
	[ReportingPeriodStartDate] [date] NULL,
	[ReportingPeriodEndDate] [date] NULL,
	[Der_FY] [varchar](10) NULL,
	[UniqSubmissionID] [bigint] NULL, 
	[NHSEUniqSubmissionID] [varchar] (30) NULL,
	[UniqMonthID] [bigint] NULL,
	[OrgIDProv] [varchar](6) NULL,
	[Person_ID] [varchar](100) NULL,	
	[Der_Pseudo_NHS_Number] [bigint] NULL,
	[RecordNumber] [bigint] NULL,
	--MPI
	[MHS001UniqID] [bigint] NOT NULL,
	[OrgIDCCGRes] [varchar](6) NULL,
	[OrgIDEduEstab] [varchar](10) NULL,
	[EthnicCategory] [varchar](3) NULL,
	[EthnicCategory2021] [varchar](3) NULL,
	[Gender] [varchar](2) NULL,
	[GenderSameAtBirth] [varchar](2) NULL,
	[MaritalStatus] [varchar](2) NULL,
	[PersDeathDate] [date] NULL,
	[AgeDeath] [int] NULL,
	[LanguageCodePreferred] [varchar](2) NULL,
	[ElectoralWard] [varchar](10) NULL,
	[LADistrictAuth] [varchar](10) NULL,
	[LSOA2011] [varchar](10) NULL,
	[County] [varchar](10) NULL,
	[NHSNumberStatus] [varchar](2) NULL,
	[OrgIDLocalPatientId] [varchar](6) NULL,
	[PostcodeDistrict] [varchar](4) NULL,
	[DefaultPostcode] [varchar](8) NULL,
	[AgeRepPeriodStart] [int] NULL,
	[AgeRepPeriodEnd] [int] NULL,
	--referral
	[MHS101UniqID] [bigint] NOT NULL,
	[UniqServReqID] [varchar](30) NULL,
	[OrgIDComm] [varchar](6) NULL,
	[ReferralRequestReceivedDate] [date] NULL,
	[ReferralRequestReceivedTime] [varchar](8) NULL,
	[NHSServAgreeLineNum] [varchar](10) NULL,
	[SpecialisedMHServiceCode] [varchar](50) NULL,
	[SourceOfReferralMH] [varchar](50) NULL,
	[OrgIDReferring] [varchar](6) NULL,
	[ReferringCareProfessionalStaffGroup] [varchar](3) NULL,
	[ClinRespPriorityType] [varchar](1) NULL,
	[PrimReasonReferralMH] [varchar](2) NULL,
	[ReasonOAT] [varchar](2) NULL,
	[DecisionToTreatDate] [date] NULL,
	[DecisionToTreatTime] [varchar](8) NULL,
	[DischPlanCreationDate] [date] NULL,
	[DischPlanCreationTime] [varchar](8) NULL,
	[DischPlanLastUpdatedDate] [date] NULL,
	[DischPlanLastUpdatedTime] [varchar](8) NULL,
	[ServDischDate] [date] NULL,
	[ServDischTime] [varchar](8) NULL,
	[AgeServReferRecDate] [int] NULL,
	[AgeServReferDischDate] [int] NULL,
	--team type
	[MHS102UniqID] [bigint] NULL,
	[UniqCareProfTeamID] [varchar](30) NULL,
	[ServTeamTypeRefToMH] [varchar](3) NULL,
	[ReferClosureDate] [date] NULL,
	[ReferClosureTime] [varchar](8) NULL,
	[ReferRejectionDate] [date] NULL,
	[ReferRejectionTime] [varchar](8) NULL,
	[ReferClosReason] [varchar](2) NULL,
	[ReferRejectReason] [varchar](2) NULL,
	[AgeServReferClosure] [int] NULL,
	[AgeServReferRejection] [int] NULL,

PRIMARY KEY CLUSTERED 
(
	[Der_RecordID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
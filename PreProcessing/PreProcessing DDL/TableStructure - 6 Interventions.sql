USE [NHSE_Sandbox_MentalHealth]
GO

/****** Object:  Table [dbo].[PreProc_Interventions]    Script Date: 17/06/2021 19:58:16 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[PreProc_Interventions](
	-- core bits
	[Der_RecordID] [int] IDENTITY(1,1) NOT NULL,
	[ReportingPeriodStartDate] [date] NULL,
	[ReportingPeriodEndDate] [date] NULL,
	[Der_FY] [varchar](10) NULL,
	[UniqSubmissionID] [bigint] NULL, 
	[NHSEUniqSubmissionID] [varchar] (30) NULL,
	[UniqMonthID] [bigint] NULL,
	[OrgIDProv] [varchar](6) NULL,
	[Person_ID] [varchar](100) NULL,	
	[RecordNumber] [bigint] NULL,
	--interventions
	[UniqServReqID] [varchar](30) NULL,
	[UniqCareContID] [varchar](30) NULL,
	[UniqCareActID] [varchar](30) NULL,
	[FindSchemeInUse] [varchar](2) NULL,
	[CodeFind] [varchar](20) NULL,
	[ObsSchemeInUse] [varchar](2) NULL,
	[CodeObs] [varchar](20) NULL,
	[ObsValue] [varchar](10) NULL,
	[UnitMeasure] [varchar](10) NULL,
	[CodeProcAndProcStatus] [varchar](60) NULL,
	--derivations
	[Der_InterventionType] [varchar](10) NULL,
	[Der_InterventionUniqID] [bigint] NOT NULL,
	[Der_ContactDate] [date] NULL,
	[Der_InterventionDuration] [int] NULL,	
	[Der_SNoMEDFindTerm] [varchar](255) NULL,
	[Der_SNoMEDFindValidity] [varchar](7) NULL,
	[Der_SNoMEDObsTerm] [varchar](255) NULL,
	[Der_SNoMEDObsValidity] [varchar](7) NULL,	
	[Der_SNoMEDProcCode] [varchar](60) NULL,
	[Der_SNoMEDProcQual] [varchar](60) NULL,
	[Der_SNoMEDProcTerm] [varchar](255) NULL,
	[Der_SNoMEDProcValidity] [varchar](7) NULL,

PRIMARY KEY CLUSTERED 
(
	[Der_RecordID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
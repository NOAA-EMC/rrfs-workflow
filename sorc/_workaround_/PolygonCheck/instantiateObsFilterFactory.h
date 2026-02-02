/*
 * (C) Copyright 2019-2024 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef UFO_INSTANTIATEOBSFILTERFACTORY_H_
#define UFO_INSTANTIATEOBSFILTERFACTORY_H_

#include "ufo/filters/AcceptList.h"
#include "ufo/filters/AverageObsToGeoValLevels.h"
#include "ufo/filters/BackgroundCheck.h"
#include "ufo/filters/BayesianBackgroundCheck.h"
#include "ufo/filters/BayesianBackgroundQCFlags.h"
#include "ufo/filters/BlackList.h"
#include "ufo/filters/ConventionalProfileProcessing.h"
#include "ufo/filters/CopyFlagsFromExtendedToOriginalSpace.h"
#include "ufo/filters/CreateDiagnosticFlags.h"
#include "ufo/filters/DifferenceCheck.h"
#include "ufo/filters/EnsembleStatistics.h"
#include "ufo/filters/FinalCheck.h"
#include "ufo/filters/Gaussian_Thinning.h"
#include "ufo/filters/GeoVaLsWriter.h"
#include "ufo/filters/gnssroonedvarcheck/GNSSROOneDVarCheck.h"
#include "ufo/filters/HistoryCheck.h"
#include "ufo/filters/ImpactHeightCheck.h"
#include "ufo/filters/MetOfficeBuddyCheck.h"
#include "ufo/filters/MetOfficeDuplicateCheck.h"
#include "ufo/filters/MetOfficePressureConsistencyCheck.h"
#include "ufo/filters/ModelBestFitPressure.h"
#include "ufo/filters/ModelObThreshold.h"
#include "ufo/filters/MWCLWCheck.h"
#include "ufo/filters/ObsBoundsCheck.h"
#include "ufo/filters/ObsDerivativeCheck.h"
#include "ufo/filters/ObsDiagnosticsWriter.h"
#include "ufo/filters/ObsDomainCheck.h"
#include "ufo/filters/ObsDomainErrCheck.h"
#include "ufo/filters/ObsPolygonCheck.h"
#include "ufo/filters/ObsRefractivityGradientCheck.h"
#include "ufo/filters/ParameterSubstitution.h"
#include "ufo/filters/PerformAction.h"
#include "ufo/filters/PoissonDiskThinning.h"
#include "ufo/filters/PreQC.h"
#include "ufo/filters/PrintFilterData.h"
#include "ufo/filters/ProbabilityGrossErrorWholeReport.h"
#include "ufo/filters/ProcessAMVQI.h"
#include "ufo/filters/ProfileAverageObsToModLevels.h"
#include "ufo/filters/ProfileBackgroundCheck.h"
#include "ufo/filters/ProfileFewObsCheck.h"
#include "ufo/filters/ProfileMaxDifferenceCheck.h"
#include "ufo/filters/ProfileUnFlagObsCheck.h"
#include "ufo/filters/QCmanager.h"
#include "ufo/filters/refractivityonedvarcheck/RefractivityOneDVarCheck.h"
#include "ufo/filters/SatName.h"
#include "ufo/filters/SatwindInversionCorrection.h"
#include "ufo/filters/SpikeAndStepCheck.h"
#include "ufo/filters/StuckCheck.h"
#include "ufo/filters/SuperOb.h"
#include "ufo/filters/SuperRefractionCheckImpactParameter.h"
#include "ufo/filters/SuperRefractionCheckNBAM.h"
#include "ufo/filters/TemporalThinning.h"
#include "ufo/filters/Thinning.h"
#include "ufo/filters/TrackCheck.h"
#include "ufo/filters/TrackCheckShip.h"
#include "ufo/filters/VariableAssignment.h"
#include "ufo/filters/VariableTransforms.h"
#include "ufo/ObsFilterBase.h"
#include "ufo/operators/gnssro/QC/BackgroundCheckRONBAM.h"
#include "ufo/operators/gnssro/QC/ROobserror.h"

#if defined(GSW_FOUND)
  #include "ufo/filters/OceanVerticalStabilityCheck.h"
#endif

#if defined(RTTOV_FOUND)
  #include "ufo/filters/rttovonedvarcheck/RTTOVOneDVarCheck.h"
#endif

#include "ufo/ObsTraits.h"

namespace ufo {
void instantiateObsFilterFactory() {
  static FilterMaker<AcceptList>
           acceptListMaker("AcceptList");
  static FilterMaker<BackgroundCheck>
           backgroundCheckMaker("Background Check");
  static FilterMaker<BackgroundCheckRONBAM>
           backgroundCheckRONBAMMaker("Background Check RONBAM");
  static FilterMaker<BayesianBackgroundCheck>
           BayesianBackgroundCheckMaker("Bayesian Background Check");
  static FilterMaker<BayesianBackgroundQCFlags>
           BayesianBackgroundQCFlagsMaker("Bayesian Background QC Flags");
  static FilterMaker<ProbabilityGrossErrorWholeReport>
           ProbabilityGrossErrorWholeReportMaker("Bayesian Whole Report");
  static FilterMaker<BlackList>
           blackListMaker("BlackList");  // same as RejectList
  static FilterMaker<ObsBoundsCheck>
           boundsCheckMaker("Bounds Check");
  static FilterMaker<ConventionalProfileProcessing>
           conventionalProfileProcessingMaker("Conventional Profile Processing");
  static FilterMaker<CreateDiagnosticFlags>
           CreateDiagnosticFlagsMaker("Create Diagnostic Flags");
  static FilterMaker<CopyFlagsFromExtendedToOriginalSpace>
           CopyFlagsFromExtendedToOriginalSpaceMaker("Copy Flags From Extended To Original Space");
  static FilterMaker<ObsDerivativeCheck>
           DerivativeCheckMaker("Derivative Check");
  static FilterMaker<DifferenceCheck>
           differenceCheckMaker("Difference Check");
  static FilterMaker<ObsDomainCheck>
           domainCheckMaker("Domain Check");
  static FilterMaker<ObsDomainErrCheck>
           domainErrCheckMaker("DomainErr Check");
  static FilterMaker<ObsPolygonCheck>
           polygonCheckMaker("Polygon Check");
  static FilterMaker<FinalCheck>
           finalCheckMaker("Final Check");
  static FilterMaker<Gaussian_Thinning>
           gaussianThinningMaker("Gaussian Thinning");
  static FilterMaker<GNSSROOneDVarCheck>
           GNSSROOneDVarCheckMaker("GNSS-RO 1DVar Check");
  static FilterMaker<ImpactHeightCheck>
           ImpactHeightCheckMaker("GNSSRO Impact Height Check");
  static FilterMaker<HistoryCheck>
           historyCheckMaker("History Check");
  static FilterMaker<MetOfficeBuddyCheck>
           MetOfficeBuddyCheckMaker("Met Office Buddy Check");
  static FilterMaker<MetOfficeDuplicateCheck>
           MetOfficeDuplicateCheckMaker("Met Office Duplicate Check");
  static FilterMaker<MetOfficePressureConsistencyCheck>
           MetOfficePressureConsistencyCheckMaker("Met Office Pressure Consistency Check");
  static FilterMaker<ModelBestFitPressure>
           ModelBestFitPressureMaker("Model Best Fit Pressure");
  static FilterMaker<ModelObThreshold>
           ModelObThresholdMaker("ModelOb Threshold");
  static FilterMaker<MWCLWCheck>
           MWCLWCheckMaker("MWCLW Check");
  static FilterMaker<ObsRefractivityGradientCheck>
           ObsRefractivityGradientCheckMaker("Obs Refractivity Gradient Check");
  static FilterMaker<ParameterSubstitution>
           parameterSubstitutionMaker("Parameter Substitution");
  static FilterMaker<PerformAction>
           performActionMaker("Perform Action");
  static FilterMaker<PoissonDiskThinning>
           poissonDiskThinningMaker("Poisson Disk Thinning");
  static FilterMaker<PreQC>
           preQCMaker("PreQC");
  static FilterMaker<PrintFilterData>
           printFilterDataMaker("Print Filter Data");
  static FilterMaker<ProcessAMVQI>
             ProcessAMVQIMaker("Process AMV QI");
  static FilterMaker<ProfileAverageObsToModLevels>
           ProfileAverageObsToModLevelsMaker("Average Observations To Model Levels");
  static FilterMaker<AverageObsToGeoValLevels>
           AverageObsToGeoValLevelsMaker("Average Observations To GeoVals Model Levels");
  static FilterMaker<ProfileBackgroundCheck>
           ProfileBackgroundCheckMaker("Profile Background Check");
  static FilterMaker<ProfileFewObsCheck>
           ProfileFewObsCheckMaker("Profile Few Observations Check");
  static FilterMaker<ProfileMaxDifferenceCheck>
           ProfileMaxDifferenceCheckMaker("Profile Max Difference Check");
  static FilterMaker<ProfileUnFlagObsCheck>
           ProfileUnFlagObsCheckMaker("Profile Unflag Observations Check");
  static FilterMaker<BlackList>
           rejectListMaker("RejectList");  // same as BlackList
  static FilterMaker<RefractivityOneDVarCheck>
           RefractivityOneDVarCheckMaker("Refractivity 1DVar Check");
  static FilterMaker<ROobserror>
           ROobserrorMaker("ROobserror");
  static FilterMaker<QCmanager>
           qcManagerMaker("QCmanager");
  static FilterMaker<SatName>
           satnameCheckMaker("satname");
  static FilterMaker<SatwindInversionCorrection>
             SatwindInversionCorrectionMaker("Satwind Inversion Correction");
  static FilterMaker<TrackCheckShip>
           ShipTrackCheckMaker("Ship Track Check");
  static FilterMaker<SpikeAndStepCheck>
           SpikeAndStepCheckMaker("Spike and Step Check");
  static FilterMaker<StuckCheck>
           StuckCheckMaker("Stuck Check");
  static FilterMaker<SuperRefractionCheckImpactParameter>
           SuperRefractionCheckImpactParameterCheckMaker("Impact Parameter Check");
  static FilterMaker<SuperOb>
           SuperObMaker("SuperOb");
  static FilterMaker<SuperRefractionCheckNBAM>
           SuperRefractionCheckNBAMCheckMaker("Super Refraction Check NBAM");
  static FilterMaker<TemporalThinning>
           temporalThinningMaker("Temporal Thinning");
  static FilterMaker<Thinning>
           thinningMaker("Thinning");
  static FilterMaker<TrackCheck>
           TrackCheckMaker("Track Check");
  static FilterMaker<VariableAssignment>
           variableAssignmentMaker("Variable Assignment");
  static FilterMaker<VariableTransforms>
           VariableTransformsMaker("Variable Transforms");
  static FilterMaker<GeoVaLsWriter> GVWriterMaker("GOMsaver");
  static FilterMaker<ObsDiagnosticsWriter>
           YDIAGsaverMaker("YDIAGsaver");
  static FilterMaker<EnsembleStatistics>
           ensembleStatisticsMaker("Ensemble Statistics");

  // Only include this filter if gsw is present
  #if defined(GSW_FOUND)
  static FilterMaker<OceanVerticalStabilityCheck>
           OceanVerticalStabilityCheckMaker("Ocean Vertical Stability Check");
  #endif

  // Only include this filter if rttov is present
  #if defined(RTTOV_FOUND)
    static FilterMaker<RTTOVOneDVarCheck>
             RTTOVOneDVarCheckMaker("RTTOV OneDVar Check");
  #endif

  // For backward compatibility, register some filters under legacy names used in the past
  static FilterMaker<Gaussian_Thinning>
           legacyGaussianThinningMaker("Gaussian_Thinning");
  static FilterMaker<TemporalThinning>
           legacyTemporalThinningMaker("TemporalThinning");
}

}  // namespace ufo

#endif  // UFO_INSTANTIATEOBSFILTERFACTORY_H_

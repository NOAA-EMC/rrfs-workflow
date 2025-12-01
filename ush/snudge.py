#!/usr/bin/env python
import sys
import numpy as np
import datetime as dt
import netCDF4 as nc


def csza(lats, lons, t):
    d2r = np.pi / 180.
    day = (t - dt.datetime(t.year - 1, 12, 31)).days
    declin = d2r * 23.45 * np.sin(2. * np.pi * (284 + day) / 365.)
    hrang = lons + d2r * (15. * t.hour - 180.)
    csza = np.sin(declin) * np.sin(lats) + np.cos(declin) * np.cos(lats) * np.cos(hrang)
    return (np.max([np.min([csza, np.ones(len(csza))], axis=0), -np.ones(len(csza))], axis=0))


def theta_to_t(theta, pressure):
    p0 = 100000.  # Pa
    return (theta * ((pressure / p0)**0.286))


def calc_qsat(p, t):
    # see /apps/ncl/6.6.2-gcc-13.2.0/lib/ncarg/nclscripts/csm/contributed.ncl
    t0 = 273.15
    ep = 0.622
    onemep = 1. - ep
    pa2mb = 0.01
    es0w = 6.11
    aw = 17.269
    bw = 35.86
    es0i = 6.1128
    ai = 22.571
    bi = 273.71
    est = np.where(t >= t0, es0w * np.exp(aw * (t - t0) / (t - bw)), es0i * np.exp((ai * (t - t0)) / ((t - t0) + bi)))
    return ((ep * est) / ((p * pa2mb) - onemep * est))


def relhum_water_ice(p, t, qw):
    # see /apps/ncl/6.6.2-gcc-13.2.0/lib/ncarg/nclscripts/csm/contributed.ncl
    qst = calc_qsat(p, t)
    return (np.max([np.min([qw / qst, np.ones(len(qw))], axis=0), np.zeros(len(qst))], axis=0))


def update_soil_temp_gsd(atha, athb, landicemask, pa, pb, tslb, snotype, snod, snot, tsk):
    # soil temperature increment produced by GSI subroutine gsd_update_soil_tq
    # adapted from
    # https://github.com/NOAA-EMC/GSI/blob/develop/src/gsi/gsd_update_mod.f90
    # lines 146 - 223 (approximate). The same code appears in
    # https://github.com/NOAA-EMC/HRRR/blob/develop/sorc/hrrr_gsi.fd/src/gsi/gsd_update_mod.f90
    c = [0.6, 0.55, 0.4, 0.3, 0.2]
    ata = theta_to_t(atha, pa)
    atb = theta_to_t(athb, pb)
    atincr = np.where(landicemask == 1, ata - atb, 0)
    temp_fac = np.min([np.max([(ata - 283.) / 15., np.zeros(len(ata))], axis=0), 1.5 * np.ones(len(ata))], axis=0) + 1.
    dts_min = -1.2 * temp_fac
    tincf = atincr * temp_fac
    dtslb = [np.min([np.ones(len(ata)), np.max([dts_min, c[i] * tincf], axis=0)], axis=0) for i in range(5)]
    tslb[:5] = tslb[:5] + dtslb
    if snotype == 'gsd':
        snot, tsk = update_snow_skin_temp_gsd(snod, snot, temp_fac, tincf, tsk, atincr)
    else:
        snot, tsk = update_snow_skin_temp_paper(snod, snot, dtslb[0], tsk)
    return (ata, atb, tslb, snot, tsk)


def update_soil_temp_paper(atha, athb, landicemask, pa, pb, tslb, snotype, snod, snot, tsk):
    # soil temperature increment detailed in
    # Benjamin, S. G., Smirnova, T. G., James, E. P., Lin, L. F., Hu, M., Turner, D. D., & He, S. (2022).
    # Land-snow data assimilation including a moderately coupled initialization method applied to NWP.
    # Journal of Hydrometeorology, 23(6), 825-845.
    # Eq. 1 and 2, Table 5, and surrounding text
    c = [0.6, 0.55, 0.4, 0.3, 0.2]
    ata = theta_to_t(atha, pa)
    atb = theta_to_t(athb, pb)
    atincr = np.where(landicemask == 1, ata - atb, 0)
    temp_fac = np.min([np.max([(ata - 283.) / 15., np.zeros(len(ata))], axis=0), 1.5 * np.ones(len(ata))], axis=0) + 1.
    dtslb = [np.min([np.max([-1.2 * temp_fac, c[i] * atincr], axis=0), np.ones(len(ata))], axis=0) for i in range(5)]
    tslb[:5] = tslb[:5] + dtslb
    if snotype == 'gsd':
        snot, tsk = update_snow_skin_temp_gsd(snod, snot, temp_fac, atincr, tsk, atincr)
    else:
        snot, tsk = update_snow_skin_temp_paper(snod, snot, dtslb[0], tsk)
    return (ata, atb, tslb, snot, tsk)


def update_snow_skin_temp_paper(snod, snot, dtslb0, tsk):
    # snow/skin temperature increment detailed in
    # Benjamin, S. G., Smirnova, T. G., James, E. P., Lin, L. F., Hu, M., Turner, D. D., & He, S. (2022).
    # Land-snow data assimilation including a moderately coupled initialization method applied to NWP.
    # Journal of Hydrometeorology, 23(6), 825-845.
    # First two full sentences at the top of p. 832
    partialSnowThresh = 0.032
    snowThreshold = 1e-10
    dtsk = np.where(snod < partialSnowThresh, dtslb0, 0)
    snot = np.where(snod < snowThreshold, snot, np.where(dtsk == 0, snot, np.where(snot + dtsk > 273.15, 273.15 * np.ones(len(snot)), snot + dtsk)))
    return (snot, tsk + dtsk)


def update_snow_skin_temp_gsd(snod, snot, temp_fac, tincf, tsk, atincr):
    # snow/skin temperature increment produced by GSI subroutine gsd_update_soil_tq
    # adapted from
    # https://github.com/NOAA-EMC/GSI/blob/develop/src/gsi/gsd_update_mod.f90
    # lines 224 - 244 (approximate). The same code appears in
    # https://github.com/NOAA-EMC/HRRR/blob/develop/sorc/hrrr_gsi.fd/src/gsi/gsd_update_mod.f90
    partialSnowThresh = 0.032  # meters
    snowThreshold = 1e-10
    c = 0.6
    dts_min = -1.2 * temp_fac
    dtsk1 = np.min([np.ones(len(tsk)), np.max([dts_min, c * tincf], axis=0)], axis=0)
    dtsk2 = np.min([np.ones(len(tsk)), np.max([-2 * np.ones(len(tsk)), c * tincf], axis=0)], axis=0)
    tsk = np.where(snod < partialSnowThresh, tsk + dtsk1, np.where(atincr < 0, tsk + dtsk2, np.where(tsk < 273.15, np.min([273.15 * np.ones(len(tsk)), tsk + dtsk2], axis=0), tsk)))
    snot = np.where(snod < snowThreshold, snot, np.where(snod < partialSnowThresh, snot + dtsk1, np.where(atincr < 0, snot + dtsk2, np.where(tsk < 273.15, np.min([273.15 * np.ones(len(tsk)), snot + dtsk2], axis=0), snot))))
    return (snot, tsk)


def update_smois_paper(cs, aqwa, aqwb, apa, apb, ata, atb, snod, smois, landmask, dHtype):
    # soil moisture increment detailed in
    # Benjamin, S. G., Smirnova, T. G., James, E. P., Lin, L. F., Hu, M., Turner, D. D., & He, S. (2022).
    # Land-snow data assimilation including a moderately coupled initialization method applied to NWP.
    # Journal of Hydrometeorology, 23(6), 825-845.
    # Eq. 3, Table 6 and surrounding text
    c = [0.2, 0.2, 0.2, 0.1]
    snowThreshold = 1e-10
    dta = ata - atb
    rha = np.where((cs <= 0.3) | (abs(dta) < 0.15) | (snod > snowThreshold) | (landmask == 2), 0, relhum_water_ice(apa, ata, aqwa))
    if dHtype == 'gsd':
        arhincr = np.max([np.min([(aqwa - aqwb) / calc_qsat(apa, ata), 0.15 * np.ones(len(rha))], axis=0), -0.15 * np.ones(len(rha))], axis=0)
        arhincr = np.where((cs <= 0.3) | (abs(dta) < 0.15) | (snod > snowThreshold) | (landmask == 2), 0, arhincr)
    else:
        rhb = np.where((cs <= 0.3) | (abs(dta) < 0.15) | (snod > snowThreshold) | (landmask == 2), 0, relhum_water_ice(apb, atb, aqwb))
        arhincr = np.max([np.min([rha - rhb, 0.15 * np.ones(len(rha))], axis=0), -0.15 * np.ones(len(rha))], axis=0)
    arhincr[arhincr * dta >= 0] = 0
    dsmois = [np.max([np.min([c[i] * arhincr, 0.03 * np.ones(len(arhincr))], axis=0), -0.03 * np.ones(len(arhincr))], axis=0)for i in range(4)]
    smois[:4] = np.max([smois[:4] + dsmois, np.zeros(np.shape(dsmois))], axis=0)
    return (smois)


def update_smois_gsd(cs, aqwa, aqwb, apa, apb, ata, atb, snod, smois, landmask, dHtype, correct):
    # soil moisture increment produced by GSI subroutine gsd_update_soil_tq
    # adapted from
    # https://github.com/NOAA-EMC/GSI/blob/develop/src/gsi/gsd_update_mod.f90
    # lines 254 - 387 (approximate). The same code appears in
    # https://github.com/NOAA-EMC/HRRR/blob/develop/sorc/hrrr_gsi.fd/src/gsi/gsd_update_mod.f90
    c = [0.2, 0.2, 0.2, 0.1]
    snowThreshold = 1e-10
    dta = ata - atb
    rha = np.where((cs <= 0.3) | (abs(dta) < 0.15) | (snod > snowThreshold) | (landmask == 2), 0, relhum_water_ice(apa, ata, aqwa))
    if dHtype == 'gsd':
        arhincr = np.max([np.min([(aqwa - aqwb) / calc_qsat(apa, ata), 0.3 * np.ones(len(rha))], axis=0), -0.3 * np.ones(len(rha))], axis=0)
        arhincr = np.where((cs <= 0.3) | (abs(dta) < 0.15) | (snod > snowThreshold) | (landmask == 2), 0, arhincr)
    else:
        rhb = np.where((cs <= 0.3) | (abs(dta) < 0.15) | (snod > snowThreshold) | (landmask == 2), 0, relhum_water_ice(apb, atb, aqwb))
        arhincr = np.max([np.min([rha - rhb, 0.3 * np.ones(len(rha))], axis=0), -0.3 * np.ones(len(rha))], axis=0)
    arhincr[arhincr * dta >= 0] = 0
    # arhincr = np.min([0.3*np.ones(len(arhincr)),np.max([-0.3*np.ones(len(arhincr)),arhincr],axis=0)],axis=0)
    arhincr = np.where((rha < 0.2) & (arhincr < 0), arhincr * rha / 0.2, arhincr)
    arhincr = np.where((rha < 0.4) & (arhincr < 0), arhincr * rha / 0.4, arhincr)
    arhincr = np.min([0.15 * np.ones(len(arhincr)), np.max([-0.15 * np.ones(len(arhincr)), arhincr], axis=0)], axis=0)
    dsmois = [np.max([np.min([c[i] * arhincr, 0.03 * np.ones(len(arhincr))], axis=0), -0.03 * np.ones(len(arhincr))], axis=0)for i in range(4)]
    if correct == 1:
        for i in range(4)[::-1]:
            smois[i] = np.max([np.min([smois[i] + dsmois[i], np.max([smois[i], smois[i + 1]], axis=0)], axis=0), np.zeros(np.shape(dsmois[i]))], axis=0)
    else:
        smois[:4] = np.max([np.min([smois[:4] + dsmois, np.max([smois[:4], smois[1:5]], axis=0)], axis=0), np.zeros(np.shape(dsmois))], axis=0)
    return (smois)


datestr = sys.argv[1]
increment_types = sys.argv[2]
mpasout = sys.argv[3]

t = dt.datetime(int(datestr[:4]), int(datestr[4:6]), int(datestr[6:8]), int(datestr[8:10]))
soilTtype = 'gsd' if increment_types[0] == 'G' else 'paper'
snowTtype = 'gsd' if increment_types[1] == 'G' else 'paper'
soilQtype = 'gsd' if increment_types[2] == 'G' else 'gsdc' if increment_types[2] == 'S' else 'paper'
if len(increment_types) > 3:
    dHtype = 'gsd' if increment_types[3] == 'G' else 'paper'
else:
    dHtype = 'gsd'
print('soilTtype=' + soilTtype + ' snowTtype=' + snowTtype + ' soilQtype=' + soilQtype + ' dHtype=' + dHtype)

invariant = nc.Dataset('invariant.nc', 'r')
lats = invariant['latCell'][:]
lons = invariant['lonCell'][:]
invariant.close()

background = nc.Dataset('soilbg.nc', 'r')
p_b = background['surface_pressure'][0]
theta_b = background['theta'][0][:, 0]
qw_b = background['qv'][0][:, 0]

tslb = background['tslb'][0].T
smois = background['smois'][0].T
snod = background['snowh'][0]
snot = background['soilt1'][0]
tsk = background['skintemp'][0]
background.close()

analysis = nc.Dataset(mpasout, 'r')
p_a = analysis['surface_pressure'][0]
theta_a = analysis['theta'][0][:, 0]
qw_a = analysis['qv'][0][:, 0]
landicemask = analysis['xland'][0]
analysis.close()

if soilTtype == 'paper':
    ata, atb, tslb, snot, tsk = update_soil_temp_paper(theta_a, theta_b, landicemask, p_a, p_b, tslb, snowTtype, snod, snot, tsk)
else:
    ata, atb, tslb, snot, tsk = update_soil_temp_gsd(theta_a, theta_b, landicemask, p_a, p_b, tslb, snowTtype, snod, snot, tsk)
if soilQtype == 'paper':
    smois = update_smois_paper(csza(lats, lons, t), qw_a, qw_b, p_a, p_b, ata, atb, snod, smois, landicemask, dHtype)
elif soilQtype == 'gsdc':
    smois = update_smois_gsd(csza(lats, lons, t), qw_a, qw_b, p_a, p_b, ata, atb, snod, smois, landicemask, dHtype, 1)
else:
    smois = update_smois_gsd(csza(lats, lons, t), qw_a, qw_b, p_a, p_b, ata, atb, snod, smois, landicemask, dHtype, 0)


fout = nc.Dataset('soil_analyzed.nc', 'w')
fout.createDimension('Time', None)
fout.createDimension('nCells', len(tsk))
fout.createDimension('nSoilLevels', 9)
fout.createVariable('tslb', 'f4', ('Time', 'nCells', 'nSoilLevels',))
fout.createVariable('smois', 'f4', ('Time', 'nCells', 'nSoilLevels',))
fout.createVariable('soilt1', 'f4', ('Time', 'nCells',))
fout.createVariable('skintemp', 'f4', ('Time', 'nCells',))

fout.variables['tslb'][:] = [tslb.T]
fout.variables['smois'][:] = [smois.T]
fout.variables['soilt1'][:] = [snot]
fout.variables['skintemp'][:] = [tsk]

fout.close()

quit()

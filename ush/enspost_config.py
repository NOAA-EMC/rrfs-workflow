# HRRR-E PYTHON GRIB GENERATION
# CONFIGURATION FILE

## CREATE DICTIONARIES ##
grib_discipline = {}
grib_category = {}
grib_number = {}
grib_surface = {}
grib_level = {}

##################################
#  GENERAL ENSEMBLE SETTINGS     #
##################################

# number of members (9=RRFSE only, 10=include RRFS-B control member)
nm = 10
# model resolution (km)
dx = 3


#################################
#  ENS MEAN/PMM/SPREAD SETTINGS #
#################################

# parms to process
mean_parms = ['1hqpf','3hqpf','6hqpf','12hqpf','24hqpf']
std_parms = []
max_parms = []
min_parms = []
pmm_parms = ['1hqpf','3hqpf','6hqpf','12hqpf','24hqpf']
lpmm_parms = ['1hqpf','3hqpf','6hqpf','12hqpf','24hqpf']

# probability-matched mean settings
pmm_smooth = 6  # km width of Gaussian smoother
lpmm_smooth = 6  # km width of Gaussian smoother
lpmm_patch = 6  # patch size in grid points
lpmm_neighborhood = 30  # overlap region in grid points

# create an output grid every X hours
ens_proc_intervals = {}
ens_proc_intervals[1] = 1
ens_proc_intervals[3] = 1
ens_proc_intervals[6] = 1
ens_proc_intervals[12] = 6
ens_proc_intervals[24] = 6

###################
#  GRIB TABLES    #
###################

grib_discipline['qpf'] = 0
grib_category['qpf'] = 1
grib_number['qpf'] = 8
grib_surface['qpf'] = 'sfc'
grib_level['qpf'] = 0

grib_discipline['ref1'] = 0
grib_category['ref1'] = 16
grib_number['ref1'] = 195
grib_surface['ref1'] = 'sfc'
grib_level['ref1'] = 1000


#################
# PQPF SETTINGS #
#################

# QPF accumulation intervals (hours)
pqpf_acc_intervals = [1,3,6,12,24]
# create an output grid every X hours
pqpf_proc_intervals = {}
pqpf_proc_intervals[1] = 1
pqpf_proc_intervals[3] = 1
pqpf_proc_intervals[6] = 1
pqpf_proc_intervals[12] = 6
pqpf_proc_intervals[24] = 6
# PQPF thresholds (inches) for each accumulation interval
pqpf_thresh = {}
pqpf_thresh[1] = [0.5,1.0,2.0]
pqpf_thresh[3] = [0.5,1.0,2.0,3.0]
pqpf_thresh[6] = [1.0,2.0,3.0,5.0]
pqpf_thresh[12] = [1.0,2.0,3.0,5.0]
pqpf_thresh[24] = [1.0,2.0,3.0,5.0]
# product types
#pqpf_types = ['point']
pqpf_types = ['neighbor']
# neighborhood size (km)
pqpf_neighborhood = 40
# gaussian smoother widths (km)
pqpf_smooth = 25
pqpf_neighbor_smooth = 25

# Flash flood guidance accumulation intervals
ffg_acc_intervals = [1,3,6]
# create an output grid every X hours
ffg_proc_intervals = {}
ffg_proc_intervals[1] = 1
ffg_proc_intervals[3] = 3
ffg_proc_intervals[6] = 3
# Probability of exceeding flash flood guidance by X inches
ffg_thresh = [0]
# product types
ffg_types = ['neighbor']
#ffg_types = ['point','neighbor']
# gaussian smoother widths (km)
ffg_smooth = 25
ffg_neighbor_smooth = 25
# neighborhood size (km)
ffg_neighborhood = 40

# Atlas-14 accumulation intervals
ari_acc_intervals = [6,24]
# create an output grid every X hours
ari_proc_intervals = {}
ari_proc_intervals[6] = 3
ari_proc_intervals[24] = 3
# Probability of exceeding Atlas-14 recurrence intervals
ari_years = {}
ari_years[6] = [2,5,10,100]
ari_years[24] = [2,5,10,100]
# product types
ari_types = ['neighbor']
#ari_types = ['point','neighbor']
# gaussian smoother widths (km)
ari_smooth = 25
ari_neighbor_smooth = 25
# neighborhood size (km)
ari_neighborhood = 40


######################
# WINTER WX SETTINGS #
######################

# PROBABILISTIC SNOW
# snow accumulation intervals
psnow_acc_intervals = [24]
# create an output grid every X hours
psnow_proc_intervals = {}
psnow_proc_intervals[1] = 1
psnow_proc_intervals[6] = 6
psnow_proc_intervals[24] = 24
# snow thresholds (inches)
psnow_thresh = {}
psnow_thresh[1] = [0.5,1.0]
psnow_thresh[6] = [1.0,3.0,6.0]
psnow_thresh[24] = [1.0,6.0,12.0]
# probability types
#psnow_types = ['neighbor']
psnow_types = ['point']
# neighborhood size (km)
psnow_neighborhood = 40
# gaussian smoother width (km)
psnow_neighbor_smooth = 25
psnow_smooth = 0

# PROBABILISTIC PTYPE
# create an output grid every X hours
ptype_proc_interval = 1
# gaussian smoother width (km)
ptype_smooth = 25
# precipitation rate threshold (in/h)
#prate_thresh = 0.01
prate_thresh = -0.0001

# PROBABILISTIC REFLECTIVITY
# create an output grid every X hours
ref_proc_interval = 1
# reflectivity probabilities
ref_thresh = [20]
# gaussian smoother width (km)
ref_smooth = 25

#####################
# AVIATION SETTINGS #
#####################

# create an output grid every X hours
aviation_proc_interval = 1
# aviation thresholds
echotop_thresh = [32,40]  #kft
vis_thresh = [1,3,5]  # mi
ceil_thresh = [500,1000,3000]  # ft
flr_cat = ['lifr','ifr','mvfr','vfr']
flr_num = {}
flr_num['lifr'] = 1
flr_num['ifr'] = 2
flr_num['mvfr'] = 3
flr_num['vfr'] = 4
flr_vis_thresh = {}
flr_vis_thresh['lifr'] = 1.0
flr_vis_thresh['ifr'] = 3.0
flr_vis_thresh['mvfr'] = 5.0
flr_ceil_thresh = {}
flr_ceil_thresh['lifr'] = 500
flr_ceil_thresh['ifr'] = 1000
flr_ceil_thresh['mvfr'] = 3000
icing_vlev_min = 10
icing_vlev_max = 25
icing_clw_thresh = 0.1 # g/kg
avn_eas_radii = [6,12,20,40,80,120]
avn_alpha = 0.1
avn_dcrit_exp = 3
avn_rad_smooth = 12
avn_p_smooth = 25
# gaussian smoother width (km)
aviation_smooth = 25






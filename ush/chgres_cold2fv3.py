"""The purpose of this code is to convert a cold start file from
chgres_cube into a FV3 warm start (restart) file, enabling data
blending operators that require a warm start format. The code performs
essential transformations, including wind rotation and vertical
remapping of atmospheric scalars and winds, ensuring the cold start
data aligns with the FV3 model's restart format. Reason: The global 6
h background from chgres_cube is a cold start and must be converted to
a warm start file to be able to blend with the 1 h EnKF restarts.

"""
import numpy as np
from netCDF4 import Dataset
import remap_dwinds
import remap_scalar
import chgres_winds   # might need to rename in the future
import sys

def nan_check(arr, name, check_id):
    """NAN check function.

    This function checks a given array for NaN (Not a Number) values,
    counts the total number of NaNs, and prints their indices if any
    are found. It helps identify problematic data in the array that
    may disrupt further processing.

    After all nan_checks are done, if there is at least one nan then
    the code fails. I put a note right after the vertical remapping of
    the wind that says "Perform a NaN check - sometimes will get NaNs
    at this point". I don't think it should fail. I think it was more
    of an issue in development and I kept the check there just to be
    safe.

    Parameters:
    arr: numpy array to be checked for NaN values.
    name: string used to label the array in the output for identification.
    check_id: integer or string identifier to differentiate between multiple checks in the output.

    Returns:
    nan_count: integer representing the total number of NaN values found in the array.

    """
    nan_count = 0
    nan_count = np.sum(np.isnan(arr))
    print(f"coldstartwinds({check_id}) nan_count({name}): {nan_count}")
    if nan_count > 0:
        nan_indices = np.argwhere(np.isnan(arr))
        print("Indices of NaN values:")
        for index in nan_indices:
            print(index)
    return nan_count

print("Reading in NETCDF4 Files...")
cold = str(sys.argv[1])
grid = str(sys.argv[2])
akbk = str(sys.argv[3])
akbkcold = str(sys.argv[4])
orog = str(sys.argv[5])

coldnc = Dataset(cold, mode="a")
akbknc = Dataset(akbk)
gridnc = Dataset(grid)
akbkcoldnc = Dataset(akbkcold)
orognc = Dataset(orog)
print("Reading in NETCDF4 Files... Done.")

ColdStartWinds = True
VertRemapScalar = True
VertRemapWinds = True
WriteData = True

# STEP 1. ROTATE THE WINDS FROM CHGRES
if ColdStartWinds:
    print("Starting ColdStartWinds....")
    nlev = len(akbknc["ak"][0,:]) - 1
    nlev = coldnc.createDimension("nlev", nlev) # 65

    # Data from cold chgres
    u_s = np.float64(coldnc["u_s"][:, :, :])    # (66, 2701, 3950)
    v_s = np.float64(coldnc["v_s"][:, :, :])    # (66, 2701, 3950)
    u_w = np.float64(coldnc["u_w"][:, :, :])    # (66, 2700, 3951)
    v_w = np.float64(coldnc["v_w"][:, :, :])    # (66, 2700, 3951)

    # grid data - usually has 2x as many grid points, so we need every other value.
    gridx = np.float64(gridnc["x"][0:-1:2, 0:-1:2])
    gridy = np.float64(gridnc["y"][0:-1:2, 0:-1:2])

    # Fortran wants everything transposed and in fortran array type
    gridx = np.asfortranarray(gridx.transpose())
    gridy = np.asfortranarray(gridy.transpose())
    u_s = np.asfortranarray(u_s.transpose())
    v_s = np.asfortranarray(v_s.transpose())
    u_w = np.asfortranarray(u_w.transpose())
    v_w = np.asfortranarray(v_w.transpose())

    # Initialize some computed fields to zero
    ud = np.zeros_like(u_s, dtype=np.float64)  # (3950, 2701, 66)
    vd = np.zeros_like(u_w, dtype=np.float64)  # (3951, 2700, 66)

    # rotate winds to model d-grid
    chgres_winds.main(gridx, gridy, u_s, v_s, u_w, v_w, ud, vd)

    print("Starting ColdStartWinds.... Done.")

# STEP 2. VERTICAL REMAPPING OF SCALARS
if VertRemapScalar:
    print("Starting VertRemapScalar...")

    # Data from cold restarts
    ak0 = np.float64(akbkcoldnc["vcoord"][0, :])     # (67,         )
    bk0 = np.float64(akbkcoldnc["vcoord"][1, :])     # (67,         )
    ak = ak0[1:]
    bk = bk0[1:]
    ps = np.float64(coldnc["ps"][:, :])              # (    2700, 3950)
    zh = np.float64(coldnc["zh"][:, :, :])           # (67, 2700, 3950)
    omga = np.float64(coldnc["w"][:, :, :])          # (66, 2700, 3950)
    delp_cold = np.float64(coldnc["delp"][:, :, :])  # (66, 2700, 3950)
    t_cold = np.float64(coldnc["t"][:, :, :])        # (66, 2700, 3950)
    Atm_phis = np.float64(orognc["orog_filt"][:, :])*9.80665  # (2700, 3950)

    ak0[0] = 1.000000000000000E-009
    bk0[0] = 1.000000000000000E-009

    sphum_cold = np.float64(coldnc["sphum"][:, :, :])     # (66, 2700, 3950)
    ntracers = 1

    # Fortran wants everything transposed and in fortran array type
    ak = np.asfortranarray(ak)   # Don't transpose 1D array
    bk = np.asfortranarray(bk)   # Don't transpose 1D array
    ak0 = np.asfortranarray(ak0) # Don't transpose 1D array
    bk0 = np.asfortranarray(bk0) # Don't transpose 1D array
    Atm_phis = np.asfortranarray(np.transpose(Atm_phis))
    ps = np.asfortranarray(ps.transpose())
    zh = np.asfortranarray(zh.transpose())
    omga = np.asfortranarray(omga.transpose())
    sphum_cold = np.asfortranarray(sphum_cold.transpose())
    delp_cold = np.asfortranarray(delp_cold.transpose())
    t_cold = np.asfortranarray(t_cold.transpose())

    isrt = 1
    jsrt = 1
    iend = np.shape(t_cold)[0]
    jend = np.shape(t_cold)[1]
    npz = np.shape(t_cold)[2]-1
    levp = npz + 1  # (km)

    # Initialize some computed fields
    Atm_delp = np.zeros_like(delp_cold[:, :, 1:], order="F")  # delp for sfcp
    Atm_q =    np.zeros_like(sphum_cold[:, :, 1:], order="F") # tracers... sphum=1
    Atm_pt =   np.zeros_like(t_cold[:, :, 1:], order="F")     # temperature
    Atm_ps =   np.zeros_like(ps, order="F")

    # Run the scalar remapping Fortran code
    remap_scalar.main(levp, npz, ntracers, ak0, bk0, ak, bk, ps, sphum_cold, zh, omga, t_cold,
                      isrt, iend, jsrt, jend, Atm_pt, Atm_q, Atm_delp, Atm_phis, Atm_ps)

    print("Starting VertRemapScalar... Done.")


# STEP 3. VERTICAL REMAPPING OF WINDS
if VertRemapWinds:
    print("Starting VertRemapWinds....")

    # ud and vd have an extra level compared to Atm_u/v
    Atm_u = np.zeros_like(ud[:, :, 1:], order="F")  # (3950, 2701, 65)
    Atm_v = np.zeros_like(vd[:, :, 1:], order="F")  # (3951, 2700, 65)

    # vertically remap the dwinds with Fortran code
    remap_dwinds.main(levp, npz, ak0, bk0, ak, bk, ps, ud, vd,
                      isrt, iend, jsrt, jend, Atm_u, Atm_v, Atm_ps)

    # Perform a NaN check - sometimes will get NaNs at this point.
    nan_count1 = nan_check(Atm_u, "Atm_u", 1)
    nan_count2 = nan_check(Atm_v, "Atm_v", 2)
    nan_count = nan_count1 + nan_count2
    if nan_count > 0:
       print(f"NaNs present after remap_dwinds")
       err = 1
       sys.exit(err)

    print("Starting VertRemapWinds.... Done.")

else:
    Atm_u = ud[:, :, 1:]
    Atm_v = vd[:, :, 1:]


# STEP 4. WRITE OUT DATA
if WriteData:
    # tranpose ud, vd back to original shape, cutoff one of levels (there is an extra level),
    # add a new variable to the nc file by duplicating the corresponding u/v variable and
    # redefine the shape of the array, finally, assign ud/vd into the u/v variable in nc file.

    if ColdStartWinds:
        # For ud
        new_var = "u_cold2fv3"
        ud = np.transpose(Atm_u) # (66, 2701, 3950)
        var_to_duplicate = coldnc.variables["u_s"]
        coldnc.createVariable(new_var, var_to_duplicate.datatype, ('nlev', 'latp', 'lon'))
        coldnc.variables[new_var][:, :, :] = ud

        # For vd
        new_var = "v_cold2fv3"
        vd = np.transpose(Atm_v) # (66, 2700, 3951)
        var_to_duplicate = coldnc.variables["v_w"]
        coldnc.createVariable(new_var, var_to_duplicate.datatype, ('nlev', 'lat', 'lonp'))
        coldnc.variables[new_var][:, :, :] = vd

    if VertRemapScalar:
        # For Temperature
        new_var = "t_cold2fv3"
        t_cold = np.transpose(Atm_pt) # (66, 2700, 3950)
        var_to_duplicate = coldnc.variables["t"]
        coldnc.createVariable(new_var, var_to_duplicate.datatype, ('nlev', 'lat', 'lon'))
        coldnc.variables[new_var][:, :, :] = t_cold

        # For delp
        new_var = "delp_cold2fv3"
        delp = Atm_delp.T # (66, 2700, 3950)
        var_to_duplicate = coldnc.variables["delp"]
        coldnc.createVariable(new_var, var_to_duplicate.datatype, ('nlev', 'lat', 'lon'))
        coldnc.variables[new_var][:, :, :] = delp

        # For sphum
        new_var = "sphum_cold2fv3"
        sphum = np.transpose(Atm_q) # (66, 2700, 3950)
        var_to_duplicate = coldnc.variables["sphum"]
        coldnc.createVariable(new_var, var_to_duplicate.datatype, ('nlev', 'lat', 'lon'))
        coldnc.variables[new_var][:, :, :] = sphum

# close the nc files
coldnc.close()

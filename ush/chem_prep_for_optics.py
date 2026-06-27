#!/usr/bin/env python
import argparse
import numpy as np


def read_refract_file(path):
    wl = []
    nr = []
    ni = []
    with open(path, "r") as f:
        for line in f:
            s = line.strip()
            if not s:
                continue
            if s.startswith(("!", "#")):
                continue
            parts = s.split()
            if len(parts) < 3:
                continue
            try:
                w = float(parts[0])
                r = float(parts[1])
                im = float(parts[2])
            except ValueError:
                continue
            wl.append(w)
            nr.append(r)
            ni.append(im)

    wl = np.array(wl, dtype=float)
    nr = np.array(nr, dtype=float)
    ni = np.array(ni, dtype=float)

    order = np.argsort(wl)
    wl = wl[order]
    nr = nr[order]
    ni = ni[order]
    return wl, nr, ni


def interp_complex(wl_src, nr_src, ni_src, wl_tgt):
    x = np.log10(wl_src)
    xt = np.log10(wl_tgt)

    nr_t = np.interp(xt, x, nr_src, left=nr_src[0], right=nr_src[-1])
    ni_t = np.interp(xt, x, ni_src, left=ni_src[0], right=ni_src[-1])
    return nr_t, ni_t


def sw_band_centers(wavmin, wavmax):
    wavmin = np.array(wavmin, dtype=float)
    wavmax = np.array(wavmax, dtype=float)
    return np.sqrt(wavmin * wavmax)


def lw_band_centers_um(wn1, wn2):
    wn1 = np.array(wn1, dtype=float)
    wn2 = np.array(wn2, dtype=float)
    wn_c = 0.5 * (wn1 + wn2)
    wl_um = 1.0e4 / wn_c
    return wl_um


def write_tbl(
    outpath,
    nsw,
    nlw,
    naero,
    species_blocks,
    header_string="AERO_OPT_TABLE",
):
    with open(outpath, "w") as f:
        f.write(f"{nsw} {nlw} {naero} ! Header: nswbands, nlwbands, num_aero_spc\n")
        # f.write(f"{header_string}\n")
        for block in species_blocks:
            f.write(f"{block['sw_name']}\n")
            for i, (r, im) in enumerate(zip(block["sw_r"], block["sw_i"]), start=1):
                f.write(f"{r:.6g} {im:.6g} ! Band {i}\n")

            f.write(f"{block['lw_name']}\n")
            for r, im in zip(block["lw_r"], block["lw_i"]):
                f.write(f"{r:.6g} {im:.6g}\n")


def main():
    # ============================================================================
    # CONFIGURATION - Modify these values as needed
    # ============================================================================

    # Input files
    water_file = "refract_water.txt"
    dust_file = "refract_dust_kwcp_fou.txt"
    smoke_file = "refract_biomass_new.txt"
    # nh4so4_file = "refract_ammoniumsulfate.txt"
    # no3_file = "refract_nitrate.txt"
    # unspc_file = "refract_soa_dinar.txt"
    output_file = "AERO_OPT.TBL"

    # Number of bands
    nsw = 4  # Number of shortwave bands , now match with original RRTMG swbands
    nlw = 16  # Number of longwave bands
    naero = 6  # Number of aerosol species

    # Shortwave band edges (micrometers)
    wavmin = [0.25, 0.35, 0.55, 0.998]
    wavmax = [0.35, 0.45, 0.65, 1.000]

    # Longwave wavenumber band edges (cm^-1)
    wavenumber1 = [10., 350., 500., 630., 700., 820., 980., 1080., 1180., 1390., 1480., 1800., 2080., 2250., 2390., 2600.]
    wavenumber2 = [350., 500., 630., 700., 820., 980., 1080., 1180., 1390., 1480., 1800., 2080., 2250., 2390., 2600., 3250.]

    # Header string
    header_string = "AERO_OPT.TBL"

    # ============================================================================
    # Optional: Override configuration with command-line arguments
    # ============================================================================

    p = argparse.ArgumentParser()
    p.add_argument("--water", default=water_file)
    p.add_argument("--dust", default=dust_file)
    p.add_argument("--smoke", default=smoke_file)
    p.add_argument("--nh4so4", default=smoke_file)
    p.add_argument("--no3", default=smoke_file)
    p.add_argument("--unspc", default=smoke_file)
    p.add_argument("--out", default=output_file)
    p.add_argument("--nsw", type=int, default=nsw)
    p.add_argument("--nlw", type=int, default=nlw)
    p.add_argument("--header", default=header_string)

    args = p.parse_args()

    # ============================================================================
    # Processing ! user may change or add sw_name, lw_name as they increase the species
    # ============================================================================

    wl_sw = sw_band_centers(wavmin[: args.nsw], wavmax[: args.nsw])
    wl_lw = lw_band_centers_um(wavenumber1[: args.nlw], wavenumber2[: args.nlw])

    w_wl, w_nr, w_ni = read_refract_file(args.water)
    d_wl, d_nr, d_ni = read_refract_file(args.dust)
    s_wl, s_nr, s_ni = read_refract_file(args.smoke)
    s_wl, s_nr, s_ni = read_refract_file(args.nh4so4)
    s_wl, s_nr, s_ni = read_refract_file(args.no3)
    s_wl, s_nr, s_ni = read_refract_file(args.unspc)

    w_sw_r, w_sw_i = interp_complex(w_wl, w_nr, w_ni, wl_sw)
    w_lw_r, w_lw_i = interp_complex(w_wl, w_nr, w_ni, wl_lw)

    d_sw_r, d_sw_i = interp_complex(d_wl, d_nr, d_ni, wl_sw)
    d_lw_r, d_lw_i = interp_complex(d_wl, d_nr, d_ni, wl_lw)

    s_sw_r, s_sw_i = interp_complex(s_wl, s_nr, s_ni, wl_sw)
    s_lw_r, s_lw_i = interp_complex(s_wl, s_nr, s_ni, wl_lw)

    species_blocks = [
        dict(sw_name="WATER_DATA", lw_name="WATER_LW_PART", sw_r=w_sw_r, sw_i=w_sw_i, lw_r=w_lw_r, lw_i=w_lw_i),
        dict(sw_name="DUST_DATA", lw_name="DUST_LW_DATA", sw_r=d_sw_r, sw_i=d_sw_i, lw_r=d_lw_r, lw_i=d_lw_i),
        dict(sw_name="SMOKE_DATA", lw_name="SMOKE_LW_DATA", sw_r=s_sw_r, sw_i=s_sw_i, lw_r=s_lw_r, lw_i=s_lw_i),
        dict(sw_name="NH4SO4_DATA", lw_name="NH4SO4_LW_DATA", sw_r=s_sw_r, sw_i=s_sw_i, lw_r=s_lw_r, lw_i=s_lw_i),
        dict(sw_name="NO3_DATA", lw_name="NO3_LW_DATA", sw_r=s_sw_r, sw_i=s_sw_i, lw_r=s_lw_r, lw_i=s_lw_i),
        dict(sw_name="UNSPC_DATA", lw_name="UNSPC_LW_DATA", sw_r=s_sw_r, sw_i=s_sw_i, lw_r=s_lw_r, lw_i=s_lw_i),
    ]

    write_tbl(
        outpath=args.out,
        nsw=args.nsw,
        nlw=args.nlw,
        naero=naero,
        species_blocks=species_blocks,
        header_string=args.header,
    )

    print(f"Program End Successfully")


if __name__ == "__main__":
    main()

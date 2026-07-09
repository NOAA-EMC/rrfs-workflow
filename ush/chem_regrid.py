#!/usr/bin/env python
import sys
import time

from pydantic_settings import BaseSettings

from regrid_wrapper.app.chem_regrid.chem_regrid_impl import main as chem_regrid_impl_main
from regrid_wrapper.app.chem_regrid.context import ChemRegridContext
from regrid_wrapper.context.logging import LOGGER


class ChemRegridEnv(BaseSettings):
    ebb_dcycle: int
    fcst_length: int
    mesh_name: str


def main() -> None:
    env = ChemRegridEnv()  # type: ignore[call-arg]
    data = {
        "dataset_name": sys.argv[1],  # Which dataset are we interpolating?
        "workdir": sys.argv[2],  # Directory where operations will be processed
        "input_dir": sys.argv[3],  # Top directory of input data
        "output_dir": sys.argv[4],  # Top directory of output data
        "weight_dir": sys.argv[5],  # Directory that contains the regrid weights
        "cycle": sys.argv[6],  # Cycle Time, YYYYMMDDHH
        "ebb_dcycle": env.ebb_dcycle,
        "fcst_length": env.fcst_length,
        "mesh_name": env.mesh_name,
        "scrip_path": None,
        "dst_path": None,
    }

    try:
        data["scrip_path"] = sys.argv[7]  # Path to the input SCRIP/UGRID domain grid file
        try:
            data["dst_path"] = sys.argv[8]  # Path to the destination grid (e.g., init.nc)
        except IndexError:
            pass
    except IndexError:
        pass

    ctx = ChemRegridContext.model_validate(data)
    LOGGER.info(f"{ctx.model_dump_json(indent=2)=}")
    t1 = time.perf_counter()
    chem_regrid_impl_main(ctx)
    LOGGER.info(f"chem_regrid_impl.main elapsed time: {time.perf_counter() - t1} s")


if __name__ == "__main__":
    main()

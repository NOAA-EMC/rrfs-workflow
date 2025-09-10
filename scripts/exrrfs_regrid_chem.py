import re
import shutil
import subprocess
import sys
import glob
from abc import abstractmethod, ABC
from datetime import datetime, timezone, timedelta
from functools import cached_property
from pathlib import Path
from typing import Literal, Iterable, Any, Union

import esmpy
import numpy as np
import pandas as pd
from pydantic import BaseModel, computed_field
from pyremap import MpasCellMeshDescriptor

from regrid_wrapper.context.comm import COMM, reconcile_bounds
from regrid_wrapper.context.logging import LOGGER
from regrid_wrapper.esmpy.field_wrapper import (
    GridSpec,
    NcToGrid,
    NcToField,
    FieldWrapper,
    GridWrapper,
    open_nc,
    Dimension,
    DimensionCollection,
    set_variable_data,
    HasNcAttrsType,
    copy_nc_variable,
)

_LOGGER = LOGGER.getChild("mpas-regrid")


class AbstractRaveField(ABC, BaseModel):
    name: str
    attrs: dict[str, Any]
    fill_value: float
    dtype: Any
    num_cells: int
    level_out_name: str
    level_out_size: int
    time_size: int

    @computed_field
    @cached_property
    def time_dimension(self) -> Dimension:
        return Dimension(
            name=("Time",),
            size=self.time_size,
            lower=0,
            upper=self.time_size,
            staggerloc=esmpy.StaggerLoc.CENTER,
            coordinate_type="time",
        )

    @computed_field
    @cached_property
    def nklevel_dimension(self) -> Dimension:
        return Dimension(
            name=(self.level_out_name,),
            size=self.level_out_size,
            lower=0,
            upper=self.level_out_size,
            staggerloc=esmpy.StaggerLoc.CENTER,
            coordinate_type="level",
        )

    def create_ncells_dimension(self, bounds: tuple[int, int]) -> Dimension:
        return Dimension(
            name=("nCells",),
            size=self.num_cells,#225636, #130333,  # tdk: pull from origin,
            lower=bounds[0],
            upper=bounds[1],
            staggerloc=esmpy.MeshLoc.ELEMENT,
            coordinate_type="cell",
        )

    @abstractmethod
    def create_dimension_collection(
        self, ncells_bounds: tuple[int, int]
    ) -> DimensionCollection: ...

    @abstractmethod
    def reshape_field_data(self, target: np.ndarray) -> np.ndarray: ...


class RaveField1d(AbstractRaveField):

    def create_dimension_collection(
        self, ncells_bounds: tuple[int,int]
    ) -> DimensionCollection:
        return DimensionCollection(
            value=(self.create_ncells_dimension(ncells_bounds),)
        )

    def reshape_field_data(self, target: np.ndarray) -> np.ndarray:
        return target.reshape(-1)

class RaveField2d(AbstractRaveField):

    def create_dimension_collection(
        self, ncells_bounds: tuple[int, int]
    ) -> DimensionCollection:
        return DimensionCollection(
            value=(self.time_dimension, self.create_ncells_dimension(ncells_bounds))
        )

    def reshape_field_data(self, target: np.ndarray) -> np.ndarray:
        return target.reshape(1, -1)


class RaveField3d(AbstractRaveField):

    def create_dimension_collection(
        self, ncells_bounds: tuple[int, int]
    ) -> DimensionCollection:
        return DimensionCollection(
            value=(
                self.time_dimension,
                self.create_ncells_dimension(ncells_bounds),
                self.nklevel_dimension,
            )
        )
    def reshape_field_data(self, target: np.ndarray) -> np.ndarray:
        return target.reshape(1, -1, 1)

class RaveField2d_plusTime(AbstractRaveField):

    def create_dimension_collection(
        self, ncells_bounds: tuple[int, int]
    ) -> DimensionCollection:
        return DimensionCollection(
            value=(
                self.create_ncells_dimension(ncells_bounds),
                self.time_dimension,
            )
        )
    def reshape_field_data(self, target: np.ndarray) -> np.ndarray:
        return target.reshape(-1, 12)

class RaveField4d(AbstractRaveField):

    def create_dimension_collection(
        self, ncells_bounds: tuple[int, int]
    ) -> DimensionCollection:
        return DimensionCollection(
            value=(
                self.create_ncells_dimension(ncells_bounds),
                self.nklevel_dimension,
                self.time_dimension,
            )
        )
    def reshape_field_data(self, target: np.ndarray) -> np.ndarray:
        return target.reshape(-1, 20, 12)

class RaveToMpasRegridContext(BaseModel):
    dataset_name: str
    src_path: Path
    dst_path: Path
    new_dst_path: Path
    desc_stats_out: Path
    weight_path: Path
    InterpMethod: str
    scrip_path: Path
    num_cells: int
    mesh_name: str
    field_names: tuple
    x_center: str
    y_center: str
    x_dim: str
    y_dim: str
    x_corner: Union[str,None]
    y_corner: Union[str,None]
    x_corner_dim: Union[str,None]
    y_corner_dim: Union[str,None]
    level_in_name: str
    #level_in_size: int
    level_out_name: str
    level_out_size: int
    time_name: str
    time_size: int
    #InterpMask: float

    rank: int = COMM.rank

    @computed_field
    @cached_property
    def rave_fields(self) -> tuple[AbstractRaveField, ...]:
        rave_fields = []
        with open_nc(self.src_path, mode="r") as ds:
            for field_name in self.field_names:
                var = ds.variables[field_name]
                init_data = {
                    "name": field_name,
                    "attrs": self._get_nc_attrs_(var),
                    "fill_value": -1.0,
                    "dtype": var.dtype,
                    "level_out_name" : self.level_out_name,
                    "level_out_size" : self.level_out_size,
                    "time_size": self.time_size,
                    "num_cells": self.num_cells,
                }
                if field_name in ("FRE", "FRP_MEAN","RWC_denominator","ecoregion_ID","10h_dead_fuel_moisture_content"):
                    app = RaveField2d.model_validate(init_data)
                elif field_name in ("PM25", "NH3", "SO2","DBL_POLL","ENL_POLL","GRA_POLL","RAG_POLL","PEC","POC","PMOTHR","PMC","TPM","NOx","CH4"):
                    app = RaveField3d.model_validate(init_data)
                elif field_name in ("albedo_drag","LAI","GVF","PC","fveg","fbare","feff","lcbare","lcveg","clayfrac","sandfrac","uthres_sg","uthres","sep"):
                    app = RaveField2d_plusTime.model_validate(init_data)
# GRAPES anthro data - 12 x 20 x lat x lon --> (latXlon) x (level) x (time) -----(then, back in the shell script)----> Time x nCells x nkemit
                elif field_name in ("HC01","PM25-PRI","PM10-PRI"):
                    app = RaveField4d.model_validate(init_data)
                else:
                    raise NotImplementedError(field_name)
                rave_fields.append(app)
        _LOGGER.debug(f"{rave_fields=}")
        return tuple(rave_fields)

    @staticmethod
    def _get_nc_attrs_(src: HasNcAttrsType) -> dict[str, Any]:
        # tdk: does valid_range matter?
        exclude = ("coordinates", "valid_range")
        return {
            ii: getattr(src, ii)
            for ii in src.ncattrs()
            if not ii.startswith("_") and ii not in exclude
        }


class FileDesc(BaseModel):
    path: Path
    origin: Literal["src", "dst"]
    field_names: tuple[str, ...]


class RaveToMpasRegridProcessor:

    def __init__(self, context: RaveToMpasRegridContext) -> None:
        self.context = context

        self._regridder: esmpy.Regrid | None = None
        self._dst_field: esmpy.Field | None = None
        self._src_gwrap: GridWrapper | None = None

    def initialize(self) -> None:
        _LOGGER.info(f"initialize: {self.context=}")
        esmpy.Manager(debug=True)

        if not self.context.scrip_path.exists() and self.context.rank == 0:
            _LOGGER.info("writing mpas scrip grid")
            mpas_desc = MpasCellMeshDescriptor(
                str(self.context.dst_path), self.context.mesh_name + ".init"
            )
            mpas_desc.to_scrip(str(self.context.scrip_path))

        print("create source grid")
        if self.context.x_corner_dim is None:
            self._src_gwrap = NcToGrid(
                path=self.context.src_path,
                spec=GridSpec(
                x_center=self.context.x_center,
                y_center=self.context.y_center,
                x_dim=(self.context.x_dim,),
                y_dim=(self.context.y_dim,),
                x_corner=self.context.x_corner,
                y_corner=self.context.y_corner,
                x_corner_dim=self.context.x_corner_dim,
                y_corner_dim=self.context.y_corner_dim,
            ),
        ).create_grid_wrapper()
        else:
            self._src_gwrap = NcToGrid(
                path=self.context.src_path,
                spec=GridSpec(
                x_center=self.context.x_center,
                y_center=self.context.y_center,
                x_dim=(self.context.x_dim,),
                y_dim=(self.context.y_dim,),
                x_corner=self.context.x_corner,
                y_corner=self.context.y_corner,
                x_corner_dim=(self.context.x_corner_dim,),
                y_corner_dim=(self.context.y_corner_dim,),
            ),
        ).create_grid_wrapper()
 
        _LOGGER.info("create source field")
        src_fwrap = self.create_src_field_wrapper(self.context.rave_fields[0].name)

        _LOGGER.info("create destination mesh")
        dst_mesh = esmpy.Mesh(
            filename=str(self.context.scrip_path), filetype=esmpy.FileFormat.SCRIP
        )

# Check for extra dims beyond lat/lon
        if self.context.level_out_size > 1 and self.context.time_size > 1:
           print("JLS, creating destination field with multiple levels and multiple times")
           self._dst_field = esmpy.Field(
               dst_mesh, name="dst", meshloc=esmpy.MeshLoc.ELEMENT,ndbounds=(self.context.level_out_size,self.context.time_size)
           )
           print(self._dst_field)
        elif self.context.level_out_size > 1 and self.context.time_size == 1:
           print("JLS, creating destination field with multiple level")
           self._dst_field = esmpy.Field(
               dst_mesh, name="dst", meshloc=esmpy.MeshLoc.ELEMENT,ndbounds=(self.context.level_out_size,)
           )
        elif self.context.level_out_size == 1 and self.context.time_size > 1:
           print("JLS, creating destination field with multiple times")
           self._dst_field = esmpy.Field(
               dst_mesh, name="dst", meshloc=esmpy.MeshLoc.ELEMENT,ndbounds=(self.context.time_size,)
           )
        else:
           _LOGGER.info("create destination field")
           self._dst_field = esmpy.Field(
               dst_mesh, name="dst", meshloc=esmpy.MeshLoc.ELEMENT
           )
    
        _LOGGER.info("create regridder")
        if self.context.weight_path.exists():
            _LOGGER.info("create regridder from file")
            self._regridder = esmpy.RegridFromFile(
                srcfield=src_fwrap.value,
                dstfield=self._dst_field,
                filename=str(self.context.weight_path),
            )
        else:
           _LOGGER.info("create regridder in-memory")
           if self.context.InterpMethod == "CONSERVE":
              _LOGGER.info("using 1st order conservative interp")
              self._regridder = esmpy.Regrid(
                   srcfield=src_fwrap.value,
                   dstfield=self._dst_field,
                   regrid_method=esmpy.RegridMethod.CONSERVE,
                   unmapped_action=esmpy.UnmappedAction.IGNORE,
                   ignore_degenerate=True,
                   filename=str(self.context.weight_path),
               )
           elif self.context.InterpMethod == "CONSERVE_2ND":
              _LOGGER.info("using 2nd order conservative interp")
              self._regridder = esmpy.Regrid(
                   srcfield=src_fwrap.value,
                   dstfield=self._dst_field,
                   regrid_method=esmpy.RegridMethod.CONSERVE_2ND,
                   unmapped_action=esmpy.UnmappedAction.IGNORE,
                   ignore_degenerate=True,
                   filename=str(self.context.weight_path),
               )
           elif self.context.InterpMethod == "BILINEAR":
              _LOGGER.info("using bilinear interp")
              self._regridder = esmpy.Regrid(
                  srcfield=src_fwrap.value,
                  dstfield=self._dst_field,
                  regrid_method=esmpy.RegridMethod.BILINEAR,
                  unmapped_action=esmpy.UnmappedAction.IGNORE,
                  ignore_degenerate=True,
                  filename=str(self.context.weight_path),
              )
           else:
              _LOGGER.info("using nearest_STOD interp")
              self._regridder = esmpy.Regrid(
                  srcfield=src_fwrap.value,
                  dstfield=self._dst_field,
                  regrid_method=esmpy.RegridMethod.NEAREST_STOD,
                  unmapped_action=esmpy.UnmappedAction.IGNORE,
                  ignore_degenerate=True,
                  filename=str(self.context.weight_path),
              )

    def run(self) -> None:
        _LOGGER.info("apply regridding")

        _LOGGER.info("create output file")
        if self.context.rank == 0:
            with open_nc(self.context.new_dst_path, mode="w", clobber=True, parallel=False) as dst_nc:
                dst_nc.createDimension("nCells", self.context.num_cells)
                dst_nc.createDimension(self.context.level_out_name, self.context.level_out_size)
                dst_nc.createDimension("StrLen",64)
                if self.context.time_size > 1:
                   print("creating time dimension with size = " + str(self.context.time_size))
                   dst_nc.createDimension("Time",self.context.time_size)
                else:
                   dst_nc.createDimension("Time")
                dst_nc.setncattr("created_at", str(datetime.now(timezone.utc)))
                dst_nc.setncattr("src_path", str(self.context.src_path))
                dst_nc.setncattr("dst_path", str(self.context.dst_path))
               
                with open_nc(self.context.dst_path, mode="r", parallel=False) as src_nc:
                    if self.context.dataset_name in ("RAVE"):
                        for varname in ("latCell", "lonCell","areaCell","xland","xtime"):
                            copy_nc_variable(src_nc, dst_nc, varname, copy_data=True)
                    else:
                        for varname in ("latCell", "lonCell","xtime"):
                            copy_nc_variable(src_nc, dst_nc, varname, copy_data=True)


        regridder = self.get_regridder()
        for rave_field in self.context.rave_fields:
            _LOGGER.info(f"regridding {rave_field.name=}")
            src_fwrap = self.create_src_field_wrapper(field_name=rave_field.name)

            dst_field = self.get_dst_field()
            # tdk: any more qa stuff? minimum threshold?
            dst_field.data.fill(0.0)
            print("JLS< dst_field.data.shape")
            print(dst_field.data.shape)
            regridder(src_fwrap.value, dst_field)
            # tdk: support NcToMesh
            local_bounds = (dst_field.lower_bounds[0], dst_field.upper_bounds[0])
            print("JLS, local bounds")
            print(local_bounds)
            reconciled_bounds = reconcile_bounds(local_bounds)
            dims = rave_field.create_dimension_collection(reconciled_bounds)
            _LOGGER.info(f"{dims=}")
            print(dims)
            _LOGGER.info(f"writing field to netcdf")
            with open_nc(self.context.new_dst_path, mode="a") as ds:
                print("JLS, rave field name = " + rave_field.name)
                if rave_field.name in ("FRP_MEAN","FRE"):
                   area = np.asarray(ds.variables['areaCell'])
                   area_subset = area[reconciled_bounds[0]:reconciled_bounds[1]]
                var = ds.createVariable(
                    rave_field.name,
                    rave_field.dtype,
                    [dim.name[0] for dim in dims.value],
                    fill_value=rave_field.fill_value,
                )
                for k, v in rave_field.attrs.items():
                    setattr(var, k, v)
                if rave_field.name in ("FRP_MEAN","FRE"):
                    set_variable_data(
                        var,
                        dims,
                        rave_field.reshape_field_data(dst_field.data*area_subset),
                        collective=True,
                    )
                else:
                    print("JLS, field data.shape")
                    print(dst_field.data.shape) 
                    print("dims for field = ")
                    print(dims)
                    set_variable_data(
                        var,
                        dims,
                        rave_field.reshape_field_data(dst_field.data),
                        collective=True,
                    )
                  # Multiply FRE/FRP by output area so it is back to W or J*s
            if rave_field.name == "ENL_POLL":
                 with open_nc(self.context.new_dst_path,mode="a") as ds:
                      _LOGGER.info(f"renaming and combining tree fields")

                      src_fwrap_enl = self.create_src_field_wrapper(field_name='ENL_POLL')
                      dst_field_enl = self.get_dst_field()
                      dst_field_enl.data.fill(0.0)
                      regridder(src_fwrap_enl.value, dst_field_enl)

                      src_fwrap_dbl = self.create_src_field_wrapper(field_name='DBL_POLL')
                      dst_field_dbl = self.get_dst_field()
                      dst_field_dbl.data.fill(0.0)
                      regridder(src_fwrap_dbl.value, dst_field_dbl)
     
                      rave_field =  self.context.rave_fields[0]
     
                      var = ds.createVariable(
                              'TREE_POLL',
                              rave_field.dtype,
                              [dim.name[0] for dim in dims.value],
                              fill_value=rave_field.fill_value,
                      )
                      for k, v in self.context.rave_fields[0].attrs.items():
                          setattr(var, k, v)
                      set_variable_data(
                          var,
                          dims,
                          rave_field.reshape_field_data(dst_field_enl.data+dst_field_dbl.data),
                          collective=True,
                      )
            if rave_field.name == "TPM":
                 with open_nc(self.context.new_dst_path,mode="a") as ds:
                      _LOGGER.info(f"calculating PM10 as TPM - PM25")
                      src_fwrap_ttl = self.create_src_field_wrapper(field_name='TPM')
                      src_fwrap_p25 = self.create_src_field_wrapper(field_name='PM25')
                      
                      dst_field_ttl = self.get_dst_field()
                      dst_field_ttl.data.fill(0.0)
                      regridder(src_fwrap_ttl.value, dst_field_ttl)

                      dst_field_p25 = self.get_dst_field()
                      dst_field_p25.data.fill(0.0)
                      regridder(src_fwrap_p25.value, dst_field_p25)
     
                      rave_field =  self.context.rave_fields[0]
     
                      var = ds.createVariable(
                              'PM10',
                              rave_field.dtype,
                              [dim.name[0] for dim in dims.value],
                              fill_value=rave_field.fill_value,
                      )
                      for k, v in self.context.rave_fields[0].attrs.items():
                          setattr(var, k, v)
                      data1 = rave_field.reshape_field_data(dst_field_ttl.data)
                      data2 = rave_field.reshape_field_data(dst_field_p25.data)
                      data3 = data1 - data2
                      set_variable_data(
                          var,
                          dims,
                          data3, 
                          collective=True,
                      )
            src_fwrap.value.destroy()
            del src_fwrap

        if self.context.rank == 0:
            field_names = tuple(ii.name for ii in self.context.rave_fields)
            targets = [
                FileDesc(
                    path=self.context.new_dst_path,
                    origin="dst",
                    field_names=field_names,
                ),
                FileDesc(
                    path=self.context.src_path,
                    origin="src",
                    field_names=field_names,
                ),
            ]
            data_frame = self.create_desc_stuff(targets)
            data_frame.to_csv(self.context.desc_stats_out, index=False)

    def finalize(self) -> None:
        _LOGGER.info("finalizing")

    def create_desc_stuff(self, targets: Iterable[FileDesc]) -> pd.DataFrame:
        _LOGGER.info("entering create_desc_stuff")
        if self.context.rank > 0:
            raise ValueError

        to_concat = []
        for target in targets:
            with open_nc(target.path, mode="r", parallel=False) as ds:
                for varname in target.field_names:
                    data = ds.variables[varname][:].filled(np.nan).ravel()
                    data_frame = pd.DataFrame.from_dict({varname: data})
                    desc = data_frame.describe()
                    adds = {
                        varname: [
                            data_frame[varname].sum(),
                            data_frame[varname].isnull().sum(),
                            target.origin,
                            target.path,
                        ]
                    }
                    desc = pd.concat(
                        [
                            desc,
                            pd.DataFrame(
                                data=adds, index=["sum", "count_null", "origin", "path"]
                            ),
                        ]
                    )
                    to_concat.append(desc)
        ret = pd.concat([ii.transpose() for ii in to_concat])
        ret.index.name = "field_name"
        ret.reset_index(inplace=True)
        _LOGGER.info("exiting create_desc_stuff")
        return ret

    def create_src_field_wrapper(self, field_name: str) -> FieldWrapper:
        _LOGGER.info("create source field")
        if field_name in ("PM25-PRI","PM10-PRI","HC01"):
            src_fwrap = NcToField(
                path=self.context.src_path,
                name=field_name,
                gwrap=self.get_src_gwrap(),
                dim_time=(self.context.time_name,),
                dim_level=(self.context.level_in_name,),
            ).create_field_wrapper()
        else:
            src_fwrap = NcToField(
                path=self.context.src_path,
                name=field_name,
                gwrap=self.get_src_gwrap(),
                dim_time=(self.context.time_name,),
            ).create_field_wrapper()
        # Get the area from the RAVE file, need to convert from /grid to /m2
        if field_name in ("PM25", "NH3", "SO2", "FRE","FRP_MEAN","TPM","CH4"):
            area_fwrap = NcToField(
                path=self.context.src_path,
                name='area',
                gwrap=self.get_src_gwrap(),
                dim_time=None,
            ).create_field_wrapper()
            area_data = area_fwrap.value.data
       
        # GRA2PES PM, convert from metric tons/km2/hr to ug/m2/s  
        if field_name in ("PM25-PRI", "PM10-PRI"):
           conv_aer = 1.e6 / 3600.
        # GRA2PES methane, convert from moles/km2/hr to ug/m2/s 
        elif field_name == "HC01":
           conv_aer = 1.e-6 / 3600.
        # RAVE methane, convert from kg/hr to mol/m2/s 
        elif field_name == "CH4":
           conv_aer = (1.0 / 16.0) * 1000.  
        else:
           conv_aer = 1.0


        src_data = src_fwrap.value.data
        if field_name in ("PM25","TPM"):
        # If RAVE aerosol emissions, convert from kg/hr to ug/m2/s
            src_data[:] = np.where(src_data < 0.0, 0.0, src_data*1.e3/area_data[:,:,np.newaxis]/3600.)
        elif field_name in ("CH4","NH3","SO2"):
        # If RAVE gas emissions, convert from kg/hr to mol/m2/s
            src_data[:] = np.where(src_data < 0.0, 0.0, conv_aer*src_data/area_data[:,:,np.newaxis]/3600.)
        elif field_name in ("FRE","FRP_MEAN"):
        # For FRE, FRP, don't multiply area by 1.e6, cancelled out by MW to W conversion
            src_data[:] = np.where(src_data < 0.0, 0.0, src_data/(area_data[:,:,np.newaxis]))
        else:
            src_data[:] = np.where(src_data < 0.0, 0.0, conv_aer * src_data)

        src_data[:] = np.where(np.isnan(src_data), 0.0, src_data)
        return src_fwrap

    def get_src_gwrap(self) -> GridWrapper:
        if self._src_gwrap is None:
            raise ValueError
        return self._src_gwrap

    def get_dst_field(self) -> esmpy.Field:
        if self._dst_field is None:
            raise ValueError
        return self._dst_field

    def get_regridder(self) -> esmpy.Regrid:
        if self._regridder is None:
            raise ValueError
        return self._regridder


def main() -> None:
    dataset_name    = sys.argv[1] # Which dataset are we interpolating?
    workdir         = sys.argv[2] # Directory where operations will be processed
    input_dir       = sys.argv[3] # Top directory of input data
    output_dir      = sys.argv[4] # Top directory of output data
    weight_dir      = sys.argv[5] # Directory that contains the regrid weights
    cycle           = sys.argv[6] # Cycle Time, YYYYMMDDHH
    mesh_name       = sys.argv[7] # Name of the domain
    #
    scrip_path     = Path( workdir + "/mpas_" + dataset_name + "-" + mesh_name + "_scrip.nc")
    dst_path       = Path( workdir + "/" + mesh_name + ".init.nc")       # Name of init file
    desc_stats_out = Path( workdir + "/desc_stats-" +cycle+".csv")
    #
    YYYY = cycle[0:4]
    MM = cycle[4:6]
    DD = cycle[6:8]
    HH = cycle[8:10]
    x = datetime(int(YYYY),int(MM),int(DD),int(HH),0,0)
    JJJ = x.strftime("%j")
    DOWh = int(x.strftime("%u"))
    if DOWh <= 5:
       DOWs = "weekdy"
    elif DOWh == 6:
       DOWs = "satdy"
    else:
       DOWs = "sundy"

    # Calculate the number of cells in the
    with open_nc(dst_path, mode="r", parallel=False) as src_nc:
        foo = src_nc.variables['latCell']
        num_cells = len(foo)
        xland = src_nc.variables['xland']
        #lmask[:] = np.where(xland > 0,1,0)

    if dataset_name == "RAVE":
       field_names = ("TPM","FRE", "FRP_MEAN", "PM25", "NH3", "SO2","CH4")
       # JLS, TODO - NEED TO ACCOUNT FOR EBB1, MORE THAN 24, ETC.
       # Determine the cycle dates to process +%Y%m%d%H
       dates_needed = []
       for i in range(24):
          x = datetime(int(YYYY),int(MM),int(DD),int(HH),0,0) - timedelta(hours=i)
          y = x.strftime("%Y%m%d%H")
          dates_needed.append(y)
       #
       x_center = "grid_lont"
       y_center = "grid_latt"
       x_dim    = "grid_xt"
       y_dim    = "grid_yt"
       x_corner = "grid_lon"
       y_corner = "grid_lat"
       x_corner_dim = "grid_x"
       y_corner_dim = "grid_y"
       level_in_name = "None"
       #level_in_size = None
       level_out_name= "nkfire"
       level_out_size = 1
       time_name  = "time"
       time_size  = 1
       InterpMethod = "CONSERVE"
       #InterpMethod = "BILINEAR"
    elif dataset_name == "GRA2PES":
       field_names = ("PM25-PRI","PM10-PRI") # ,"HC01"=methane BAQMS, summer, 2025
       x_center = "XLONG" #"XLONG_M"
       y_center = "XLAT" #"XLAT_M"
       x_dim    = "west_east"
       y_dim    = "south_north"
       x_corner = "XLONG_C"
       y_corner = "XLAT_C"
       x_corner_dim = "west_east_stag"
       y_corner_dim = "south_north_stag"
       level_in_name = "bottom_top"
       level_out_name = "nkemit"
       level_out_size = 20
       time_name  = "Time"
       time_size  = 12
       InterpMethod = "CONSERVE"
       #InterpMethod = "BILINEAR"
    elif dataset_name == "NEMO":
       field_names = ("POC","PEC","PMOTHR","PMC")
       x_center = "lon"
       y_center = "lat"
       x_dim    = "COL"
       y_dim    = "ROW"
       x_corner = "lonc"
       y_corner = "latc"
       x_corner_dim = "COLC"
       y_corner_dim = "ROWC"
       level_in_name = "None"
       level_out_name = "nkemit"
       level_out_size = 1
       time_name  = "Time"
       time_size  = 1
       InterpMethod = "CONSERVE"
#       InterpMethod = "BILINEAR"
    elif dataset_name == "PECM":
       field_names = ("DBL_POLL","ENL_POLL","GRA_POLL","RAG_POLL")
       x_center = "lon"
       y_center = "lat"
       x_dim    = "COL"
       y_dim    = "ROW"
       x_corner = "lonc"
       y_corner = "latc"
       x_corner_dim = "COLC"
       y_corner_dim = "ROWC"
       level_in_name = "None"
       level_out_name= "nkbio"
       level_out_size = 1
       time_name  = "time"
       time_size  = 1
       InterpMethod = "CONSERVE"
    elif dataset_name == "ECOREGION":
       field_names = ("ecoregion_ID",)
       x_center = "geolon"
       y_center = "geolat"
       x_dim    = "lon"
       y_dim    = "lat"
       x_corner = None
       y_corner = None
       x_corner_dim = None
       y_corner_dim = None
       level_in_name = "None"
       level_out_name = "nkfire"
       level_out_size = 1
       time_name  = "time"
       time_size  = 1
       InterpMethod = "NEAREST_STOD"
    elif dataset_name == "NARR":
       field_names = ("RWC_denominator",)
       x_center = "lon"
       y_center = "lat"
       x_dim    = "x"
       y_dim    = "y"
       x_corner = None
       y_corner = None
       x_corner_dim = None
       y_corner_dim = None
       level_in_name = "None"
       level_out_name = "nkemit"
       level_out_size = 1
       time_name  = "Time"
       time_size  = 1
       InterpMethod = "BILINEAR"
    elif dataset_name == "FENGSHA_1":
       field_names = ("albedo_drag","clayfrac","sandfrac","uthres","uthres_sg","sep")
       x_center = "lon2d"
       y_center = "lat2d"
       x_dim    = "lon"
       y_dim    = "lat"
       x_corner = None
       y_corner = None
       x_corner_dim = None
       y_corner_dim = None
       level_in_name = "None"
       level_out_name = "nkemit"
       level_out_size = 1
       time_name  = "time"
       time_size  = 12
       InterpMethod = "BILINEAR"
    elif dataset_name == "FENGSHA_2":
       field_names = ("feff",)
       x_center = "lon2d"
       y_center = "lat2d"
       x_dim    = "lon"
       y_dim    = "lat"
       x_corner = None
       y_corner = None
       x_corner_dim = None
       y_corner_dim = None
       level_in_name = "None"
       level_out_name = "nkemit"
       level_out_size = 1
       time_name  = "time"
       time_size  = 12
       InterpMethod = "BILINEAR"
    elif dataset_name == "FMC": # fuel moisture content
       field_names = ("10h_dead_fuel_moisture_content",)
       dates_needed = []
       for i in range(25):
          x = datetime(int(YYYY),int(MM),int(DD),int(HH),0,0) - timedelta(hours=i)
          y = x.strftime("%Y%m%d%H")
          dates_needed.append(y)
       print("JLS, dates needed for FMC")
       print(dates_needed)
       x_center = "longitude"
       y_center = "latitude"
       x_dim    = "nx"
       y_dim    = "ny"
       x_corner = None
       y_corner = None
       x_corner_dim = None
       y_corner_dim = None
       level_in_name = "None"
       level_out_name = "nkfire"
       level_out_size = 1
       time_name  = "time"
       time_size  = 1
       InterpMethod = "BILINEAR"
    
    weight_path = Path( weight_dir + "/weights_" + dataset_name + "-to-" + "mpas_" + mesh_name + "_" + InterpMethod + ".nc")

    if dataset_name == "RAVE":
       for date_to_process in dates_needed:
          rave_paths=glob.glob(input_dir + "/RAVE-HrlyEmiss-3km_v2r0_blend_s"+date_to_process+"*")
          if len(rave_paths) == 0:
             print("No matching files found for " + input_dir + "/RAVE-HrlyEmiss-3km_v2r0_blend_s"+date_to_process+"*")
             continue
          rave_path=rave_paths[0]
          new_dst_path = Path(output_dir + "/" + mesh_name + "-RAVE-" +date_to_process + ".nc")
      
          context = RaveToMpasRegridContext(
              dataset_name=dataset_name,
              src_path=rave_path,
              dst_path=dst_path,
              new_dst_path=new_dst_path,
              desc_stats_out=desc_stats_out,
              weight_path=weight_path,
              InterpMethod=InterpMethod,
              scrip_path=scrip_path,
              num_cells=num_cells,
              mesh_name=mesh_name,
              field_names=field_names,
              x_center=x_center,
              y_center=y_center,
              x_dim=x_dim,
              y_dim=y_dim,
              x_corner=x_corner,
              y_corner=y_corner,
              x_corner_dim=x_corner_dim,
              y_corner_dim=y_corner_dim,
              level_in_name=level_in_name,
              #level_in_size=level_in_size,
              level_out_name=level_out_name,
              level_out_size=level_out_size,
              time_name=time_name,
              time_size=time_size

          )
          processor = RaveToMpasRegridProcessor(context=context)
          processor.initialize()
          processor.run()
          processor.finalize()
      
          _LOGGER.info("success")
    
    elif dataset_name == "FMC":
       for date_to_process in dates_needed:
          print("JLS, looking for file " + input_dir + "fmc_" + date_to_process + ".nc")
          rave_paths = glob.glob(input_dir + "fmc_" + date_to_process + ".nc")
          rave_path=rave_paths[0]
          new_dst_path = Path ( output_dir + "fmc_" + date_to_process +"_" + mesh_name + ".nc")

          context = RaveToMpasRegridContext(
              dataset_name=dataset_name,
              src_path=rave_path,
              dst_path=dst_path,
              new_dst_path=new_dst_path,
              desc_stats_out=desc_stats_out,
              weight_path=weight_path,
              InterpMethod=InterpMethod,
              scrip_path=scrip_path,
              num_cells=num_cells,
              mesh_name=mesh_name,
              field_names=field_names,
              x_center=x_center,
              y_center=y_center,
              x_dim=x_dim,
              y_dim=y_dim,
              x_corner=x_corner,
              y_corner=y_corner,
              x_corner_dim=x_corner_dim,
              y_corner_dim=y_corner_dim,
              level_in_name=level_in_name,
              level_out_name=level_out_name,
              level_out_size=level_out_size,
              time_name=time_name,
              time_size=time_size

          )
          processor = RaveToMpasRegridProcessor(context=context)
          processor.initialize()
          processor.run()
          processor.finalize()
      
          _LOGGER.info("success")
#
    elif dataset_name == "GRA2PES":
       rave_path    = Path( input_dir + "/GRA2PESv1.0_total_2021" + MM + "_" + DOWs +"_00to11Z.nc")
       new_dst_path = Path(output_dir + "/" +dataset_name+"_"+mesh_name+"_00to11Z.nc")
       context = RaveToMpasRegridContext(
           dataset_name=dataset_name,
           src_path=rave_path,
           dst_path=dst_path,
           new_dst_path=new_dst_path,
           desc_stats_out=desc_stats_out,
           weight_path=weight_path,
           InterpMethod=InterpMethod,
           scrip_path=scrip_path,
           num_cells=num_cells,
           mesh_name=mesh_name,
           field_names=field_names,
           x_center=x_center,
           y_center=y_center,
           x_dim=x_dim,
           y_dim=y_dim,
           x_corner=x_corner,
           y_corner=y_corner,
           x_corner_dim=x_corner_dim,
           y_corner_dim=y_corner_dim,
           level_in_name=level_in_name,
           level_out_name=level_out_name,
           level_out_size=level_out_size,
           time_name=time_name,
           time_size=time_size

       )
       processor = RaveToMpasRegridProcessor(context=context)
       processor.initialize()
       processor.run()
       processor.finalize()
      
       _LOGGER.info("success")
       
       rave_path    = Path( input_dir + "/GRA2PESv1.0_total_2021" + MM + "_" + DOWs +"_12to23Z.nc")
       new_dst_path = Path(output_dir + "/" +dataset_name+"_"+mesh_name+"_12to23Z.nc")
       context = RaveToMpasRegridContext(
           dataset_name=dataset_name,
           src_path=rave_path,
           dst_path=dst_path,
           new_dst_path=new_dst_path,
           desc_stats_out=desc_stats_out,
           weight_path=weight_path,
           InterpMethod=InterpMethod,
           scrip_path=scrip_path,
           num_cells=num_cells,
           mesh_name=mesh_name,
           field_names=field_names,
           x_center=x_center,
           y_center=y_center,
           x_dim=x_dim,
           y_dim=y_dim,
           x_corner=x_corner,
           y_corner=y_corner,
           x_corner_dim=x_corner_dim,
           y_corner_dim=y_corner_dim,
           level_in_name=level_in_name,
           level_out_name=level_out_name,
           level_out_size=level_out_size,
           time_name=time_name,
           time_size=time_size

       )
       processor = RaveToMpasRegridProcessor(context=context)
       processor.initialize()
       processor.run()
       processor.finalize()
      
       _LOGGER.info("success")

    else:
       if dataset_name == "PECM":
          rave_path    = Path( input_dir  + "/pollen_obs_" + YYYY + "_BELD6_ef_T_" + JJJ +".nc")
          new_dst_path = Path( output_dir + "/pollen_ef_"+mesh_name+"_"+YYYY+"_"+JJJ+".nc")
       elif dataset_name == "NEMO":
          rave_path    = Path ( input_dir + "/NEMO_RWC_POC_PEC_PMOTHR.annual.2017.nc")
          new_dst_path = Path ( output_dir +"/NEMO_RWC_ANNUAL_TOTAL_"+mesh_name+".nc")
       elif dataset_name == "NARR":
          rave_path    = Path ( input_dir + "/rwc_emission_denominator.2017.nc")
          new_dst_path = Path ( output_dir + "/NEMO_RWC_DENOMINATOR_2017_"+mesh_name+".nc")
       elif dataset_name == "ECOREGION":
          rave_path    = Path ( input_dir + "/veg_map.nc") 
          new_dst_path = Path ( output_dir + "ecoregions_"+mesh_name+"_mpas.nc")
       elif dataset_name == "FENGSHA_1":
          rave_path    = Path ( input_dir + "/FENGSHA_2022_NESDIS_inputs_10km_v3.2.nc")
          new_dst_path = Path ( output_dir + "/FENGSHA_2022_NESDIS_inputs_"+mesh_name + "_v3.2.nc")
       elif dataset_name == "FENGSHA_2":
          rave_path    = Path ( input_dir + "/LAI_GVF_PC_DRAG_CLIMATOLOGY_2024v1.0.nc4")
          new_dst_path = Path ( output_dir + "/LAI_GVF_PC_DRAG_CLIMATOLOGY_2024v1.0."+mesh_name + ".nc")
      
    
       context = RaveToMpasRegridContext(
           dataset_name=dataset_name,
           src_path=rave_path,
           dst_path=dst_path,
           new_dst_path=new_dst_path,
           desc_stats_out=desc_stats_out,
           weight_path=weight_path,
           InterpMethod=InterpMethod,
           scrip_path=scrip_path,
           num_cells=num_cells,
           mesh_name=mesh_name,
           field_names=field_names,
           x_center=x_center,
           y_center=y_center,
           x_dim=x_dim,
           y_dim=y_dim,
           x_corner=x_corner,
           y_corner=y_corner,
           x_corner_dim=x_corner_dim,
           y_corner_dim=y_corner_dim,
           level_in_name=level_in_name,
           #level_in_size=level_in_size,
           level_out_name=level_out_name,
           level_out_size=level_out_size,
           time_name=time_name,
           time_size=time_size
      
       )
       processor = RaveToMpasRegridProcessor(context=context)
       processor.initialize()
       processor.run()
       processor.finalize()
       
       _LOGGER.info("success")
   
if __name__ == "__main__":
    main()

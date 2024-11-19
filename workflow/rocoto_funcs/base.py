#!/usr/bin/env python
import subprocess
import os

def source(bash_file,optional=False):
  """
  Source a Bash file and capture the environment variables
  """
  #check if bash_file exists
  command = f"source {bash_file} && env"
  proc = subprocess.Popen(
    ['bash', '-c', command],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    universal_newlines=True
  )
  stdout, stderr = proc.communicate()
  if proc.returncode != 0:
    if optional:
      return #do nothing for optional config files
    else:
      raise Exception(f"Error sourcing bash file: {stderr}")
  env_vars = {}
  for line in stdout.splitlines():
    key, _, value = line.partition("=")
    env_vars[key] = value
  # Update the current environment
  os.environ.update(env_vars)
### end of source(bash_file)

### head_begin
def header_begin(xmlFile):
  text = """<?xml version="1.0"?>
<!DOCTYPE wflow [
"""
  xmlFile.write(text)

### header_entities_
def header_entities(xmlFile,expdir):
  HOMErrfs=os.getenv('HOMErrfs','HOMErrfs_not_defined')
  DATAROOT=os.getenv('DATAROOT','DATAROOT_not_defined')
  COMROOT=os.getenv('COMROOT','COMROOT_not_defined')
  net=os.getenv('NET','rrfs')
  run=os.getenv('RUN','rrfs')
  rrfs_ver=os.getenv('VERSION','v2.0.0')
  account=os.getenv('ACCOUNT','wrfruc')
  queue=os.getenv('QUEUE','bacth')
  partition=os.getenv('PARTITION','hera')
  reservation=os.getenv('RESERVATION','')
  mesh_name=os.getenv('MESH_NAME','na3km')
  keepdata=os.getenv('KEEPDATA','yes')
  mpi_run_cmd=os.getenv('MPI_RUN_CMD','srun')
  wgf=os.getenv('WGF','det')

  text = f'''
<!ENTITY ACCOUNT         "{account}">\n\
<!ENTITY QUEUE_DEFAULT   "{queue}">\n\
<!ENTITY PARTITION       "{partition}">\n\
<!ENTITY RESERVATION     "--reservation={reservation}">\n\

<!ENTITY HOMErrfs        "{HOMErrfs}">\n\
<!ENTITY EXPDIR          "{expdir}">\n\
<!ENTITY DATAROOT        "{DATAROOT}">\n\
<!ENTITY COMROOT         "{COMROOT}">\n\
<!ENTITY LOGROOT         "{COMROOT}/{net}/{rrfs_ver}/logs">\n\

<!ENTITY RUN             "rrfs">\n\
<!ENTITY NET             "{net}">\n\
<!ENTITY rrfs_ver        "{rrfs_ver}">\n\
<!ENTITY WGF             "{wgf}">\n\

'''
  xmlFile.write(text)

  text = f'''
<!ENTITY task_common_vars\n\
"\n\
  <envar><name>HOMErrfs</name><value>&HOMErrfs;</value></envar>\n\
  <envar><name>EXPDIR</name><value>&EXPDIR;</value></envar>\n\
  <envar><name>DATAROOT</name><value><cyclestr>&DATAROOT;/{net}/{rrfs_ver}/{run}.@Y@m@d/@H</cyclestr></value></envar>\n\
  <envar><name>UMBRELLA_DATA</name><value><cyclestr>&DATAROOT;/{net}/{rrfs_ver}/{run}.@Y@m@d/@H/{wgf}</cyclestr></value></envar>\n\
  <envar><name>COMROOT</name><value>&COMROOT;</value></envar>\n\
  <envar><name>COMINrrfs</name><value>&COMROOT;/{net}/{rrfs_ver}</value></envar>\n\
  <envar><name>COMOUT</name><value><cyclestr>&COMROOT;/{net}/{rrfs_ver}/{run}.@Y@m@d/@H</cyclestr></value></envar>\n\
  <envar><name>CDATE</name><value><cyclestr>@Y@m@d@H</cyclestr></value></envar>\n\
  <envar><name>PDY</name><value><cyclestr>@Y@m@d</cyclestr></value></envar>\n\
  <envar><name>cyc</name><value><cyclestr>@H</cyclestr></value></envar>\n\
  <envar><name>NET</name><value>{net}</value></envar>\n\
  <envar><name>rrfs_ver</name><value>{rrfs_ver}</value></envar>\n\
  <envar><name>KEEPDATA</name><value>{keepdata}</value></envar>\n\
  <envar><name>MPI_RUN_CMD</name><value>{mpi_run_cmd}</value></envar>\n\
  <envar><name>MESH_NAME</name><value>{mesh_name}</value></envar>\n\
  <envar><name>WGF</name><value>{wgf}</value></envar>\n\
"\n\
>\n\
'''
  xmlFile.write(text)

### header_end
def header_end(xmlFile):
  text = "]>\n"
  xmlFile.write(text)

### wflow_begin
def wflow_begin(xmlFile):
  realtime=os.getenv("REALTIME","false").upper()
  cyclethrottle=os.getenv("RETRO_CYCLETHROTTLE","3")
  taskthrottle=os.getenv("RETRO_TASKTHROTTLE","30")
  if realtime == "TRUE":
    text='<workflow realtime="T" scheduler="slurm" cyclethrottle="26" cyclelifespan="01:00:00:00">'
  else:
    text=f'<workflow realtime="F" scheduler="slurm" cyclethrottle="{cyclethrottle}" taskthrottle="{taskthrottle}">'
  xmlFile.write(f'\n{text}\n')

### wflow_end
def wflow_end(xmlFile):
  xmlFile.write('\n</workflow>\n')

### wflow_log
def wflow_log(xmlFile,log_fpath):
  text=f'  <log verbosity="10"><cyclestr>{log_fpath}</cyclestr></log>'
  xmlFile.write(f'{text}\n')

### wflow_cycledefs
def wflow_cycledefs(xmlFile,dcCycledef):
  text=""
  for key,value in dcCycledef.items():
    text=text+f'\n  <cycledef group="{key}">{value}</cycledef>'
  xmlFile.write(f'{text}\n')

### objTask
class objTask:
  def __init__(self,task_id,cycledefs,maxtries,dcTaskRes,realtime=False,deadline="",dcTaskEnv={},dependencies=""):
    self.task_id=task_id
    self.cycledefs=cycledefs
    self.maxtries=maxtries
    self.dcTaskRes=dcTaskRes
    self.realtime=realtime
    self.deadline=deadline
    self.dcTaskEnv=dcTaskEnv
    self.dependencies=dependencies

  def wflow_task_divider(self,xmlFile):
    text=f'\n<!--\n'
    text=text+f'************************************************************************************\n'
    text=text+f'************************************************************************************'
    text=text+f'\n-->\n'
    xmlFile.write(text)

  def wflow_task_begin(self,xmlFile):
    text=f'\n<task name="{self.task_id}" cycledefs="{self.cycledefs}" maxtries="{self.maxtries}">\n'
    xmlFile.write(text)

  def wflow_task_part1(self,xmlFile): #write out part1 which excludes dependencies
    text=f'  <command>{self.dcTaskRes["command"]} &HOMErrfs;</command>\n'
    text=text+f'  <join><cyclestr>{self.dcTaskRes["join"]}</cyclestr></join>\n'
    text=text+f'\n  <jobname><cyclestr>{self.dcTaskRes["jobname"]}</cyclestr></jobname>\n'
    text=text+f'  <account>&ACCOUNT;</account>\n'
    text=text+f'  <queue>&QUEUE_DEFAULT;</queue>\n'
    text=text+f'  <partition>&PARTITION;</partition>\n'
    text=text+f'  <walltime>{self.dcTaskRes["walltime"]}</walltime>\n'
    text=text+f'  {self.dcTaskRes["nodes"]}\n' #note: xml tag self included, no need to add <nodes> </nodes>
    #
    if self.dcTaskRes["native"] == "":
      if self.dcTaskRes["reservation"]!="":
        text=text+f'  <native>&RESERVATION;</native>\n'
    else:
      native_text=self.dcTaskRes["native"]
      if self.dcTaskRes["reservation"]!="":
        native_text=native_text+f' &RESERVATION;'
      text=text+f'  <native>{native_text}</native>\n'
    #
    if self.realtime:
      text=text+f'  <deadline><cyclestr offset="{self.deadline}">@Y@m@d@H@M</cyclestr></deadline>\n'
    #
    text=text+"  &task_common_vars;\n" #add an empty line before the <envar> block for readability
    for key,value in self.dcTaskEnv.items():
      text=text+f'  <envar><name>{key}</name><value>{value}</value></envar>\n'
    xmlFile.write(text)

  def wflow_task_end(self,xmlFile):
    xmlFile.write("</task>\n")

  def wflow_task_dependencies(self,xmlFile):
    xmlFile.write(f"{self.dependencies}\n")
### end of objTask

### get_required_env
def get_required_env(env_name):
  env_value=os.getenv(env_name)
  if env_value == None:
    print(f'env variable "{env_name}" not found')
    exit()
  else:
    return env_value

### get_cascade_env
def get_cascade_env(env_name):
  seperator="_" #underscore
  revStr=env_name[::-1]; #reverse the string
  env_value = os.getenv(env_name)
  if env_value != None:
    return env_value

  while seperator in revStr:
    ra,rb=revStr.split(seperator,1) #only split once
    new_name=rb[::-1]
    env_value = os.getenv(new_name)
    if env_value != None:
      return env_value
    else:
      revStr=rb

  #if no env variable is defined in the cascasde
  return f'the cascade env {env_name} not defined'
### end of get_cascade_env(env_name)

### get_yes_or_no
def get_yes_or_no(prompt):
  while True:
    user_input = input(prompt).strip().lower()
    if user_input in ['yes', 'no', 'y', 'n']:
      return user_input
    else:
      print("Please enter 'yes','y','no',or 'n'.")
### end of get_yes_or_no

### xml_task
def xml_task(xmlFile,expdir,task_id,cycledefs,dcTaskEnv={},dependencies="",metatask=False,meta_id='',meta_bgn="",meta_end="",command_id="",do_ensemble=False):
  # for non-meta tasks, task_id=meta_id; for meta tasks, task_id=${meta_id}_xxx
  # metatask is a group of tasks who share a very similar functionality at the same cycle, for example, post_f01, post_f02, ensembles, etc
  # It is recommended to use separate tasks (i.e. non-metatask) for spinup and prod cycles for simplicity
  COMROOT=os.getenv('COMROOT','/COMROOT_NOT_DEFINED')
  HOMErrfs=os.getenv('HOMErrfs','HOMErrfs_not_defined')
  if do_ensemble:
    RUN='ens'
  else:
    RUN='rrfs'
  TAG=os.getenv('TAG','TAG_NOT_DEFINED')
  NET=os.getenv('NET','NET_NOT_DEFINED')
  VERSION=os.getenv('VERSION','VERSION_NOT_DEFINED')
  realtime=os.getenv('REALTIME','false')
  deadline=get_cascade_env(f'DEADLINE_{task_id}'.upper())
  if metatask == False:
    meta_id=task_id
    source(f"{expdir}/config/config.{meta_id}",optional=True)
  else: #True
    source(f"{expdir}/config/config.{meta_id}",optional=True)
    source(f"{expdir}/config/config.{task_id}",optional=True)
  if command_id == "":
    command_id=meta_id
  dcTaskRes={
    'command': f'&HOMErrfs;/workflow/sideload/launch.sh JRRFS_'+f'{command_id}'.upper(),
    'join': f'&LOGROOT;/{RUN}.@Y@m@d/@H/{task_id}_{TAG}_@Y@m@d@H.log',
    'jobname': f'{TAG}_{task_id}_c@H',
    'account': get_cascade_env(f'ACCOUNT_{task_id}'.upper()),
    'queue': get_cascade_env(f'QUEUE_{task_id}'.upper()),
    'partition': get_cascade_env(f"PARTITION_{task_id}".upper()),
    'walltime': get_cascade_env(f"WALLTIME_{task_id}".upper()),
    'nodes': get_cascade_env(f"NODES_{task_id}".upper()),
    'reservation': get_cascade_env(f"RESERVATION_{task_id}".upper()),
    'native': get_cascade_env(f"NATIVE_{task_id}".upper())
  }

  myObjTask=objTask(
          task_id=task_id,
          cycledefs=cycledefs,
          maxtries=get_cascade_env(f"MAXTRIES_{task_id}".upper()),
          dcTaskRes=dcTaskRes,
          realtime=realtime.upper()=="TRUE",
          deadline=deadline,
          dcTaskEnv=dcTaskEnv,
          dependencies=dependencies)
  myObjTask.wflow_task_divider(xmlFile)
  if metatask == True:
    xmlFile.write(meta_bgn)
  myObjTask.wflow_task_begin(xmlFile)
  myObjTask.wflow_task_part1(xmlFile)
  myObjTask.wflow_task_dependencies(xmlFile)
  myObjTask.wflow_task_end(xmlFile)
  if metatask == True:
    xmlFile.write(meta_end)
### end of xml_task


# qrocoto
https://github.com/RRFSx/qrocoto  
    
A collection of scripts that wrap the rocoto* commands to help us check the workflow status **Q**uickly.
    
Available commands and usages:  
**rinfo**  
**rrun**  
**rstat**  
  
**rboot, rcheck, rwind, rcomplete, rstat, rrun** can all run as follows:
```
  rwind <YYYYMMDDHHMM> <tasks> (or <-m=metatasks>)  
  eg. rwind 202405270100 prep_ic,jedivar
```

**rtasks <tasks>**  
`eg. rtasks jedivar`  

**findrrfsdirs**  
**checkrrfsxml**  
**bkg_rrun [seconds]**  
`  eg. bkg_rrun 30`

Check [Detailed Instructions](https://github.com/rrfsx/qrocoto/wiki/qrocoto) for more.

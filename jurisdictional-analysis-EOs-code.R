##BLM SSS jurisdictional analysis for EOs
##Sept 2, 2022
##M Tarjan

##LOAD PACKAGES

##start by installing the package
#install.packages("arcgisbinding", repos="https://r.esri.com", type="win.binary")
library(arcgisbinding)
## Check ArcGIS Pro product is installed locally
arc.check_product()

##install reticulate
##need to first install devtools packages and rtools
#install.packages("devtools")
#library(devtools)
#install_version("reticulate", version = "1.22", repos = "http://cran.us.r-project.org") ##older version required until package is updated to handle space in filepath name for python
library(reticulate)
reticulate::use_condaenv(condaenv='C:/Program Files/ArcGIS/Pro/bin/Python/envs/arcgispro-py3', required = T)
arcpy<-import("arcpy")#; arcpy<-import("arcpy")

#library(sf)
library(tidyverse)
library(readxl)

##CREATE OUTPUT FOLDER
if (!file.exists(str_c("Output-", Sys.Date()))) {
  dir.create(str_c("Output-", Sys.Date()))
}
out.folder<-paste0(getwd(),"/",str_c("Output-", Sys.Date()))
#out.folder<-"C:/Users/max_tarjan/OneDrive - NatureServe/Documents/Partners-In-Conservation/Output-2022-10-24"

##LOAD SPATIAL LAYERS
##blm surface management layer
##same projection as mobi models
#boundary.path <- "C:/Users/max_tarjan/OneDrive - NatureServe/Documents/GIS_data/BLM_National_Surface_Management_Agency/BLM_Lands_NAD83.shp"
##reprojected to same as bld data
boundary.path<-"C:/Users/max_tarjan/OneDrive - NatureServe/Documents/GIS_data/BLM_National_Surface_Management_Agency/BLM_Lands_ProjectionBLD.shp"

##biotics snapshot
bld.path<-"S:/Data/NatureServe/BLD_Occurrences/NS_BLD_GeoDB/Snapshots/Monthly-2022-09/bld-2022-09.gdb/BLD_EO_SPECIES"

## Geodatabase for writing outputs
#gdb.path <- "C:/Users/Max_Tarjan/Documents/ArcGIS/Projects/MyProject/MyProject.gdb"
#gdb.path <- "C:/Users/max_tarjan/OneDrive - NatureServe/Documents/ArcGIS/Projects/ParternsInConservation/ParternsInConservation.gdb"

##load list of blm sss
blmsss<-read_excel("C:/Users/max_tarjan/NatureServe/BLM - BLM SSS Distributions and Rankings Project-FY21/Provided to BLM/BLM - Information for T & E Strategic Decision-Making - April 2021.xlsx", sheet= "BLM SSS Information by State", skip=1)
##subset to only sss (and infrataxa)
blmsss<-subset(blmsss, `Elements Matched between BLM SSS List and NatureServe Data` != "-")

## SUBSET EOS
## Get list of id subset in sql format
id.select<-paste0("(", paste0(blmsss$`Element Global ID`, collapse = ", "), ")")
## Test with one species
id.select<-paste0("(", paste0("104696", collapse = ", "), ")")

## Select EOs that are SSS
## Use feature class to feature class conversion tool (create new layer with SQL selection)
arcpy$conversion$FeatureClassToFeatureClass(in_features = bld.path, out_path = out.folder, out_name = "bld_sub", where_clause = paste0("EGT_ID IN ", id.select))

## Define new bld path
bld.sub.path <- paste0(out.folder, "/bld_sub.shp")
#bld.sub.path <- "C:/Users/max_tarjan/OneDrive - NatureServe/Documents/ArcGIS/Projects/ParternsInConservation/ParternsInConservation.gdb/EOs_EGTID104696.shp"

## Spatial intersect: clip bld by boundary and get attributes from both layers
##need to work out exact syntax. attempts below
arcpy$analysis$PairwiseIntersect(in_features = c(bld.sub.path,boundary.path), out_feature_class = paste0(out.folder, "/bld_intersect.shp"))

#arcpy$analysis$PairwiseIntersect(in_features = [bld.sub.path, boundary.path], out_feature_class = paste0(out.folder, "/bld_intersect.shp"))

##from arcpro
#arcpy.analysis.PairwiseIntersect("EOs_EGTID104696;BLM_Lands_ProjectionBLD", r"C:\Users\max_tarjan\OneDrive - NatureServe\Documents\ArcGIS\Projects\ParternsInConservation\ParternsInConservation.gdb\EGTID104696_BLM", "ALL", None, "INPUT")

## SUBSET AND WRANGLE DATAFRAME FROM EO INTERSECTION
## open clipped bld using arcbridge for wrangling
#bld.intersect.path<-paste0(out.folder, "/bld_intersect.shp")
bld.intersect.path <- paste0(out.folder, "/EGTID104696_BLM.shp")
bld.intersect<-arc.open(bld.intersect.path)

## Add area to each polygon (for subsetting EOs later)

## Subset EOs based on overlap and timescale, quality, etc
bld.intersect.df<-arc.select(bld.intersect, fields = c('EGT_ID', 'EO_ID', 'NATION', 'SUBNATION', 'STD_GRP', 'GNAME', 'GCOMNAME', 'G_RANK', 'EORANK_CD', 'EORANK_D', 'FIRSTOBS_D', 'LASTOBS_D', 'LOBS_Y', 'LOBS_MIN_Y', 'LOBS_MAX_Y', 'BLM_Gen', 'ADMU_NAME'), where_clause = "ID_CONF <> 'N'")

## Summarize results
## Number of EOs for each species that occurs in each BLM_Gen category by eo rank and subnation
eo.ja.rank.subnation <- bld.intersect.df %>% subset(select = c(EGT_ID, EO_ID, SUBNATION, EORANK_CD, BLM_Gen)) %>% unique() %>% group_by(EGT_ID, SUBNATION, EORANK_CD, BLM_Gen) %>% summarise(n_EOs = n()) %>% data.frame()

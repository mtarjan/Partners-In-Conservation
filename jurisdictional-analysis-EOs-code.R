##BLM SSS jurisdictional analysis for EOs
##Sept 2, 2022
##M Tarjan

##HAVEN'T USED THIS CODE YET; JUST A DRAFT

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
arcpy<-import("arcpy"); arcpy<-import("arcpy")

#library(sf)
library(tidyverse)
library(readxl)

##CREATE OUTPUT FOLDER
if (!file.exists(str_c("Output-", Sys.Date()))) {
  dir.create(str_c("Output-", Sys.Date()))
}

##LOAD SPATIAL LAYERS
##blm surface management layer, reprojected to nad83 (same projection as mobi models)
boundary.path<-"Data/BLM_National_Surface_Management_Agency/BLM_Lands_NAD83.shp"

##biotics snapshot
bld.path<-"S:/Data/NatureServe/BLD_Occurrences/NS_BLD_GeoDB/Snapshots/Monthly-2022-03/bld-2022-03.gdb/BLD_EO_SPECIES"

##load list of blm sss
#blmsss<-read_excel("C:/Users/max_tarjan/NatureServe/BLM - BLM SSS Distributions and Rankings Project-FY21/Task 2-List interoperability/BLM - Compiled SSS List Information - September 2021.xlsx", sheet= "1b. BLM-NS SSS Data Summary", skip = 1)
#names(blmsss)<-gsub(names(blmsss), pattern = "...[[:digit:]][[:digit:]]", replacement = "")
blmsss<-read_excel("C:/Users/max_tarjan/NatureServe/BLM - BLM SSS Distributions and Rankings Project-FY21/Provided to BLM/BLM - Information for T & E Strategic Decision-Making - April 2021  .xlsx", sheet= "BLM SSS Information by State", skip=1)
##subset to only sss (and infrataxa)
blmsss<-subset(blmsss, `Elements Matched between BLM SSS List and NatureServe Data` != "-")

##SUBSET EOS
##select EOs that are SSS

##CLIP BLD EOS BY A BOUNDARY LAYER
##result is written out as a shapefile
arcpy$Clip_analysis(in_features = bld.path, clip_features = boundary.path, out_feature_class = str_c("Output-", Sys.Date(), "/bld_intersect"))

##SUBSET AND WRANGLE DATAFRAME FROM EO INTERSECTION
##open clipped bld using arcbridge for wrangling
bld.intersect.path<-str_c("Output-", Sys.Date(), "/bld_intersect.shp")
bld.intersect<-arc.open(bld.intersect.path)

bld.intersect.df<-arc.select(bld.intersect)
bld.intersect.df<-arc.select(bld.intersect, fields = c('EGT_ID', 'SNAME', 'SCOMNAME', 'G_RANK', 'MAJ_GRP1'), where_clause = "MAJ_GRP1 = 'Vascular Plants - Conifers and relatives'")

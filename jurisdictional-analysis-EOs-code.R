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
#blmsss<-read_excel("C:/Users/max_tarjan/NatureServe/BLM - BLM SSS Distributions and Rankings Project-FY21/Task 2-List interoperability/BLM - Compiled SSS List Information - September 2021.xlsx", sheet= "1b. BLM-NS SSS Data Summary", skip = 1)
#names(blmsss)<-gsub(names(blmsss), pattern = "...[[:digit:]][[:digit:]]", replacement = "")
blmsss<-read_excel("C:/Users/max_tarjan/NatureServe/BLM - BLM SSS Distributions and Rankings Project-FY21/Provided to BLM/BLM - Information for T & E Strategic Decision-Making - April 2021.xlsx", sheet= "BLM SSS Information by State", skip=1)
##subset to only sss (and infrataxa)
blmsss<-subset(blmsss, `Elements Matched between BLM SSS List and NatureServe Data` != "-")

## SUBSET EOS
## Get list of id subset in sql format
id.select<-paste0("(", paste0(blmsss$`Element Global ID`, collapse = ", "), ")")

## Select EOs that are SSS
## Use feature class to feature class conversion tool (create new layer with SQL selection)
arcpy$FeatureClassToFeatureClass_conversion(in_features = bld.path, out_path = out.folder, out_name = "bld_sub", where_clause = paste0("EGT_ID IN ", id.select))

## Define new bld path
bld.sub.path <- paste0(out.folder, "/bld_sub.shp")

## CLIP BLD EOS BY A BOUNDARY LAYER
##result is written out as a shapefile
#arcpy$Clip_analysis(in_features = bld.sub.path, clip_features = boundary.path, out_feature_class = paste0(out.folder, "/bld_intersect"))

## Tabulate area
#gdb.path<- "temp_files/geodatabase.gdb/"
gdb.path<- "C:/Users/Max_Tarjan/Documents/ArcGIS/Projects/MyProject/MyProject.gdb/" ##need to write area tables to a geodatabase
arcpy$sa$TabulateArea(boundary.path, "BLM_Gen", bld.sub.path, "Value", paste0(gdb.path, "bld_blm_area"), bld.sub.path)
dat.temp <- arc.open(path = paste0(gdb.path, "bld_blm_area")) %>% arc.select() %>% subset(select = -OBJECTID)

## Spatial Join: add attributes from boundary layer to bld data
arcpy$analysis$SpatialJoin(target_features = bld.sub.path, join_features = boundary.path, out_feature_class = paste0(gdb.path, "bld_join_blm"), join_operation = "JOIN_ONE_TO_ONE", join_type = "KEEP_ALL", match_option = "LARGEST_OVERLAP")
##code from arcpro
#arcpy$analysis$SpatialJoin(bld.sub.path, boundary.path, paste0(gdb.path, "bld_join_blm"), "JOIN_ONE_TO_ONE", "KEEP_ALL", 'NATION "NATION" true true false 2 Text 0 0,First,#,bld_sub,NATION,0,2;SUBNATION "SUBNATION" true true false 3 Text 0 0,First,#,bld_sub,SUBNATION,0,3;EO_ID "EO_ID" true true false 19 Double 0 0,First,#,bld_sub,EO_ID,-1,-1;EO_OU_UID "EO_OU_UID" true true false 19 Double 0 0,First,#,bld_sub,EO_OU_UID,-1,-1;EO_SEQ_UID "EO_SEQ_UID" true true false 19 Double 0 0,First,#,bld_sub,EO_SEQ_UID,-1,-1;EO_UID "EO_UID" true true false 84 Text 0 0,First,#,bld_sub,EO_UID,0,84;SHAPE_JOIN "SHAPE_JOIN" true true false 81 Text 0 0,First,#,bld_sub,SHAPE_JOIN,0,81;PRN_EO_ID "PRN_EO_ID" true true false 19 Double 0 0,First,#,bld_sub,PRN_EO_ID,-1,-1;PRN_EO_SID "PRN_EO_SID" true true false 19 Double 0 0,First,#,bld_sub,PRN_EO_SID,-1,-1;PRN_EO_IND "PRN_EO_IND" true true false 1 Text 0 0,First,#,bld_sub,PRN_EO_IND,0,1;INACTIVE_I "INACTIVE_I" true true false 1 Text 0 0,First,#,bld_sub,INACTIVE_I,0,1;ELCODE_BCD "ELCODE_BCD" true true false 10 Text 0 0,First,#,bld_sub,ELCODE_BCD,0,10;EGT_UID "EGT_UID" true true false 96 Text 0 0,First,#,bld_sub,EGT_UID,0,96;EGT_ID "EGT_ID" true true false 19 Double 0 0,First,#,bld_sub,EGT_ID,-1,-1;EGT_OU_UID "EGT_OU_UID" true true false 19 Double 0 0,First,#,bld_sub,EGT_OU_UID,-1,-1;EGT_SEQ_UI "EGT_SEQ_UI" true true false 19 Double 0 0,First,#,bld_sub,EGT_SEQ_UI,-1,-1;PS_EGT_ID "PS_EGT_ID" true true false 19 Double 0 0,First,#,bld_sub,PS_EGT_ID,-1,-1;EST_ID "EST_ID" true true false 19 Double 0 0,First,#,bld_sub,EST_ID,-1,-1;EST_OU_UID "EST_OU_UID" true true false 19 Double 0 0,First,#,bld_sub,EST_OU_UID,-1,-1;EST_SEQ_UI "EST_SEQ_UI" true true false 19 Double 0 0,First,#,bld_sub,EST_SEQ_UI,-1,-1;EO_NUM "EO_NUM" true true false 19 Double 0 0,First,#,bld_sub,EO_NUM,-1,-1;REC_TYPE "REC_TYPE" true true false 1 Text 0 0,First,#,bld_sub,REC_TYPE,0,1;CLASS_STAT "CLASS_STAT" true true false 20 Text 0 0,First,#,bld_sub,CLASS_STAT,0,20;NAME_LEVEL "NAME_LEVEL" true true false 60 Text 0 0,First,#,bld_sub,NAME_LEVEL,0,60;STD_GRP "STD_GRP" true true false 254 Text 0 0,First,#,bld_sub,STD_GRP,0,254;MAJ_GRP1 "MAJ_GRP1" true true false 254 Text 0 0,First,#,bld_sub,MAJ_GRP1,0,254;MAJ_GRP2 "MAJ_GRP2" true true false 254 Text 0 0,First,#,bld_sub,MAJ_GRP2,0,254;MAJ_GRP3 "MAJ_GRP3" true true false 254 Text 0 0,First,#,bld_sub,MAJ_GRP3,0,254;KINGDOM "KINGDOM" true true false 200 Text 0 0,First,#,bld_sub,KINGDOM,0,200;PHYLUM "PHYLUM" true true false 200 Text 0 0,First,#,bld_sub,PHYLUM,0,200;TAXCLASS "TAXCLASS" true true false 200 Text 0 0,First,#,bld_sub,TAXCLASS,0,200;TAXORDER "TAXORDER" true true false 200 Text 0 0,First,#,bld_sub,TAXORDER,0,200;FAMILY "FAMILY" true true false 200 Text 0 0,First,#,bld_sub,FAMILY,0,200;GENUS "GENUS" true true false 200 Text 0 0,First,#,bld_sub,GENUS,0,200;GNAME "GNAME" true true false 250 Text 0 0,First,#,bld_sub,GNAME,0,250;GCOMNAME "GCOMNAME" true true false 254 Text 0 0,First,#,bld_sub,GCOMNAME,0,254;SNAME "SNAME" true true false 250 Text 0 0,First,#,bld_sub,SNAME,0,250;SCOMNAME "SCOMNAME" true true false 254 Text 0 0,First,#,bld_sub,SCOMNAME,0,254;G_RANK "G_RANK" true true false 12 Text 0 0,First,#,bld_sub,G_RANK,0,12;RND_G_RANK "RND_G_RANK" true true false 15 Text 0 0,First,#,bld_sub,RND_G_RANK,0,15;G_RANK_C_D "G_RANK_C_D" true true false 8 Date 0 0,First,#,bld_sub,G_RANK_C_D,-1,-1;G_RANK_R_D "G_RANK_R_D" true true false 8 Date 0 0,First,#,bld_sub,G_RANK_R_D,-1,-1;USESA_CD "USESA_CD" true true false 30 Text 0 0,First,#,bld_sub,USESA_CD,0,30;USESA_DATE "USESA_DATE" true true false 8 Date 0 0,First,#,bld_sub,USESA_DATE,-1,-1;G_INT_ESA "G_INT_ESA" true true false 20 Text 0 0,First,#,bld_sub,G_INT_ESA,0,20;S_INT_ESA "S_INT_ESA" true true false 20 Text 0 0,First,#,bld_sub,S_INT_ESA,0,20;EO_INT_ESA "EO_INT_ESA" true true false 20 Text 0 0,First,#,bld_sub,EO_INT_ESA,0,20;EO_APP_ESA "EO_APP_ESA" true true false 254 Text 0 0,First,#,bld_sub,EO_APP_ESA,0,254;IUCN_CD "IUCN_CD" true true false 2 Text 0 0,First,#,bld_sub,IUCN_CD,0,2;G_INT_IUCN "G_INT_IUCN" true true false 20 Text 0 0,First,#,bld_sub,G_INT_IUCN,0,20;COSEWIC "COSEWIC" true true false 20 Text 0 0,First,#,bld_sub,COSEWIC,0,20;SARA "SARA" true true false 50 Text 0 0,First,#,bld_sub,SARA,0,50;S_RANK "S_RANK" true true false 20 Text 0 0,First,#,bld_sub,S_RANK,0,20;RND_S_RANK "RND_S_RANK" true true false 24 Text 0 0,First,#,bld_sub,RND_S_RANK,0,24;S_RANK_C_D "S_RANK_C_D" true true false 8 Date 0 0,First,#,bld_sub,S_RANK_C_D,-1,-1;S_RANK_R_D "S_RANK_R_D" true true false 8 Date 0 0,First,#,bld_sub,S_RANK_R_D,-1,-1;S_PROT "S_PROT" true true false 50 Text 0 0,First,#,bld_sub,S_PROT,0,50;EORANK_CD "EORANK_CD" true true false 2 Text 0 0,First,#,bld_sub,EORANK_CD,0,2;EORANK_D "EORANK_D" true true false 50 Text 0 0,First,#,bld_sub,EORANK_D,0,50;SUBRANK_CD "SUBRANK_CD" true true false 2 Text 0 0,First,#,bld_sub,SUBRANK_CD,0,2;ID_CONF "ID_CONF" true true false 1 Text 0 0,First,#,bld_sub,ID_CONF,0,1;MIG_USE_TY "MIG_USE_TY" true true false 254 Text 0 0,First,#,bld_sub,MIG_USE_TY,0,254;FIRSTOBS_D "FIRSTOBS_D" true true false 50 Text 0 0,First,#,bld_sub,FIRSTOBS_D,0,50;LASTOBS_D "LASTOBS_D" true true false 50 Text 0 0,First,#,bld_sub,LASTOBS_D,0,50;LOBS_Y "LOBS_Y" true true false 19 Double 0 0,First,#,bld_sub,LOBS_Y,-1,-1;LOBS_MIN_Y "LOBS_MIN_Y" true true false 19 Double 0 0,First,#,bld_sub,LOBS_MIN_Y,-1,-1;LOBS_MAX_Y "LOBS_MAX_Y" true true false 19 Double 0 0,First,#,bld_sub,LOBS_MAX_Y,-1,-1;LOBS_DSPLY "LOBS_DSPLY" true true false 50 Text 0 0,First,#,bld_sub,LOBS_DSPLY,0,50;SURVEY_D "SURVEY_D" true true false 120 Text 0 0,First,#,bld_sub,SURVEY_D,0,120;PREC_BCD "PREC_BCD" true true false 2 Text 0 0,First,#,bld_sub,PREC_BCD,0,2;EST_REP_AC "EST_REP_AC" true true false 30 Text 0 0,First,#,bld_sub,EST_REP_AC,0,30;CONF_X_CD "CONF_X_CD" true true false 1 Text 0 0,First,#,bld_sub,CONF_X_CD,0,1;CONF_X_DES "CONF_X_DES" true true false 60 Text 0 0,First,#,bld_sub,CONF_X_DES,0,60;S_DATASEN "S_DATASEN" true true false 50 Text 0 0,First,#,bld_sub,S_DATASEN,0,50;EO_DATASEN "EO_DATASEN" true true false 50 Text 0 0,First,#,bld_sub,EO_DATASEN,0,50;SUBEO_DATA "SUBEO_DATA" true true false 50 Text 0 0,First,#,bld_sub,SUBEO_DATA,0,50;S_DATASEN_ "S_DATASEN_" true true false 250 Text 0 0,First,#,bld_sub,S_DATASEN_,0,250;EO_DATAS_1 "EO_DATAS_1" true true false 250 Text 0 0,First,#,bld_sub,EO_DATAS_1,0,250;SUBEO_DA_1 "SUBEO_DA_1" true true false 254 Text 0 0,First,#,bld_sub,SUBEO_DA_1,0,254;EO_TRACK "EO_TRACK" true true false 1 Text 0 0,First,#,bld_sub,EO_TRACK,0,1;DATA_QC "DATA_QC" true true false 20 Text 0 0,First,#,bld_sub,DATA_QC,0,20;DO_NOT_XCH "DO_NOT_XCH" true true false 1 Text 0 0,First,#,bld_sub,DO_NOT_XCH,0,1;DX_LR_DATE "DX_LR_DATE" true true false 8 Date 0 0,First,#,bld_sub,DX_LR_DATE,-1,-1;DX_LR_STAT "DX_LR_STAT" true true false 1 Text 0 0,First,#,bld_sub,DX_LR_STAT,0,1;DX_LS_DATE "DX_LS_DATE" true true false 8 Date 0 0,First,#,bld_sub,DX_LS_DATE,-1,-1;EO_DATA "EO_DATA" true true false 254 Text 0 0,First,#,bld_sub,EO_DATA,0,254;GEN_DESC "GEN_DESC" true true false 254 Text 0 0,First,#,bld_sub,GEN_DESC,0,254;EO_RANK_CO "EO_RANK_CO" true true false 254 Text 0 0,First,#,bld_sub,EO_RANK_CO,0,254;MGMT_COM "MGMT_COM" true true false 254 Text 0 0,First,#,bld_sub,MGMT_COM,0,254;MONITORING "MONITORING" true true false 254 Text 0 0,First,#,bld_sub,MONITORING,0,254;RESEARCH_N "RESEARCH_N" true true false 254 Text 0 0,First,#,bld_sub,RESEARCH_N,0,254;PROTECTION "PROTECTION" true true false 254 Text 0 0,First,#,bld_sub,PROTECTION,0,254;OWNER_COM "OWNER_COM" true true false 254 Text 0 0,First,#,bld_sub,OWNER_COM,0,254;GENERAL_CO "GENERAL_CO" true true false 254 Text 0 0,First,#,bld_sub,GENERAL_CO,0,254;ADDITIONAL "ADDITIONAL" true true false 254 Text 0 0,First,#,bld_sub,ADDITIONAL,0,254;BLM_Gen "BLM_Gen" true true false 30 Text 0 0,First,#,BLM_Lands_ProjectionBLD,BLM_Gen,0,30;ADMU_NAME "ADMU_NAME" true true false 40 Text 0 0,First,#,BLM_Lands_ProjectionBLD,ADMU_NAME,0,40;NEW_ID "NEW_ID" true true false 10 Long 0 10,First,#,BLM_Lands_ProjectionBLD,NEW_ID,-1,-1', "LARGEST_OVERLAP", None, '')

##SUBSET AND WRANGLE DATAFRAME FROM EO INTERSECTION
##open clipped bld using arcbridge for wrangling
bld.intersect.path<-paste0(out.folder, "/bld_intersect.shp")
bld.intersect<-arc.open(bld.intersect.path)

bld.intersect.df<-arc.select(bld.intersect)
bld.intersect.df<-arc.select(bld.intersect, fields = c('EGT_ID', 'SNAME', 'SCOMNAME', 'G_RANK', 'MAJ_GRP1'), where_clause = "MAJ_GRP1 = 'Vascular Plants - Conifers and relatives'")

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
bld.path<-"S:/Data/NatureServe/BLD_Occurrences/NS_BLD_GeoDB/Snapshots/Monthly-2022-10/bld-2022-10.gdb/BLD_EO_SPECIES"

## Geodatabase for writing outputs
#gdb.path <- "C:/Users/Max_Tarjan/Documents/ArcGIS/Projects/MyProject/MyProject.gdb"
#gdb.path <- "C:/Users/max_tarjan/OneDrive - NatureServe/Documents/ArcGIS/Projects/ParternsInConservation/ParternsInConservation.gdb"

##load list of blm sss
blmsss<-read_excel("C:/Users/max_tarjan/NatureServe/BLM - BLM SSS Distributions and Rankings Project-FY21/Provided to BLM/BLM - Information for T & E Strategic Decision-Making - April 2021.xlsx", sheet= "BLM SSS Information by State", skip=1)
##subset to only sss (and infrataxa)
blmsss<-subset(blmsss, `Elements Matched between BLM SSS List and NatureServe Data` != "-")

## Load SSS that are ESA from Bruce for 12/2022 round of prioritization tool
sss.esa<-read_excel("C:/Users/max_tarjan/NatureServe/BLM - BLM SSS Distributions and Rankings Project-FY21/Species Prioritization Tool/ESA Species/ESA listed BLM SSS to score for Prioritization Tool_7Nov2022.xlsx")

## SUBSET EOS
## Get list of id subset in sql format
id.select<-paste0("(", paste0(blmsss$`Element Global ID`, collapse = ", "), ")")
## Test with one species
id.select<-paste0("(", paste0("104696", collapse = ", "), ")")
## Select only ESA species
id.select <- paste0("(", paste0(sss.esa$`NatureServe Element ID`, collapse = ", "), ")")
## IDs to run through in a loop
id.run <- sss.esa$`NatureServe Element ID`

## Run python code
reticulate::repl_python()
import arcpy
arcpy.env.overwriteOutput = True
## Exit out of python command prompt
exit

## Source python script for overlap function
reticulate::source_python("function-overlay.py")

## OPTION 1: LOOP THROUGH SPECIES TO DO OVERLAP ANALYSIS FOR ONE AT A TIME
for (j in 1:length(id.run)) {
  arcpy$conversion$FeatureClassToFeatureClass(in_features = bld.path, out_path = out.folder, out_name = "bld_sub", where_clause = paste0("EGT_ID = ", id.run[j]))
  
  ## Define new bld path
  bld.sub.path <- paste0(out.folder, "/bld_sub.shp")
  
  ## Use function from python script
  overlap(x = bld.sub.path, y = boundary.path, z = "Output-2022-11-17\\bld_intersect.shp")
}

## OPTION 2: COMPLETE OVERLAP ANALYSIS FOR ALL SPECIES
## Select EOs that are SSS
## Use feature class to feature class conversion tool (create new layer with SQL selection)
arcpy$conversion$FeatureClassToFeatureClass(in_features = bld.path, out_path = out.folder, out_name = "bld_sub", where_clause = paste0("EGT_ID IN ", id.select))

## Define new bld path
bld.sub.path <- paste0(out.folder, "/bld_sub.shp")
#bld.sub.path <- "C:/Users/max_tarjan/OneDrive - NatureServe/Documents/ArcGIS/Projects/ParternsInConservation/ParternsInConservation.gdb/EOs_EGTID104696.shp"

## Source python script for overlap function
reticulate::source_python("function-overlap.py")
overlap(x = bld.sub.path, y = boundary.path, z = "Output-2022-11-17\\bld_intersect.shp")

## Calculate area of EO shapes
arcpy$management$CalculateGeometryAttributes(in_features = bld.sub.path, geometry_property = c("EO_AREA", "AREA"), area_unit = "SQUARE_KILOMETERS")#, coordinate_system = 'PROJCS["North_America_Albers_Equal_Area_Conic",GEOGCS["GCS_North_American_1983",DATUM["D_North_American_1983",SPHEROID["GRS_1980",6378137.0,298.257222101]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]],PROJECTION["Albers"],PARAMETER["False_Easting",0.0],PARAMETER["False_Northing",0.0],PARAMETER["Central_Meridian",-96.0],PARAMETER["Standard_Parallel_1",20.0],PARAMETER["Standard_Parallel_2",60.0],PARAMETER["Latitude_Of_Origin",40.0],UNIT["Meter",1.0]]', coordinate_format = "SAME_AS_INPUT")

## Spatial intersect: clip bld by boundary and get attributes from both layers
##need to work out exact syntax. attempts below
arcpy$analysis$PairwiseIntersect(in_features = c(bld.sub.path, boundary.path), out_feature_class = paste0(out.folder, "/bld_intersect.shp"))

#arcpy$analysis$PairwiseIntersect(in_features = [bld.sub.path, boundary.path], out_feature_class = paste0(out.folder, "/bld_intersect.shp"))

##from arcpro
#arcpy.analysis.PairwiseIntersect("EOs_EGTID104696;BLM_Lands_ProjectionBLD", r"C:\Users\max_tarjan\OneDrive - NatureServe\Documents\ArcGIS\Projects\ParternsInConservation\ParternsInConservation.gdb\EGTID104696_BLM", "ALL", None, "INPUT")

## Add area to each polygon (for subsetting EOs later)
arcpy$management$CalculateGeometryAttributes(bld.intersect.path, "AREA AREA", '', "SQUARE_KILOMETERS", 'PROJCS["North_America_Albers_Equal_Area_Conic",GEOGCS["GCS_North_American_1983",DATUM["D_North_American_1983",SPHEROID["GRS_1980",6378137.0,298.257222101]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]],PROJECTION["Albers"],PARAMETER["False_Easting",0.0],PARAMETER["False_Northing",0.0],PARAMETER["Central_Meridian",-96.0],PARAMETER["Standard_Parallel_1",20.0],PARAMETER["Standard_Parallel_2",60.0],PARAMETER["Latitude_Of_Origin",40.0],UNIT["Meter",1.0]]', "SAME_AS_INPUT")

## SUBSET AND WRANGLE DATAFRAME FROM EO INTERSECTION
boundary.fields <- c("BLM_Gen", "ADMU_NAME", "STATE_ABBR") ##define the fields from the boundary layer that are of interest
# Open bld to get original number of EOs per species
bld.path <- "C:/Users/max_tarjan/OneDrive - NatureServe/Documents/ArcGIS/Projects/ParternsInConservation/ParternsInConservation.gdb/BLD_EO_SPECIES"
bld<-arc.open(bld.path)
## open clipped bld using arcbridge for wrangling
#bld.intersect.path<-paste0(out.folder, "/bld_intersect.shp")
bld.intersect.path<-"C:/Users/max_tarjan/OneDrive - NatureServe/Documents/ArcGIS/Projects/ParternsInConservation/ParternsInConservation.gdb/BLD_BLM"
#bld.intersect.path <- paste0(getwd(), "/", out.folder, "/EGTID104696_BLM.shp")
bld.intersect<-arc.open(bld.intersect.path)

## Create dataframes of info
bld.df<-arc.select(bld, fields = c('EGT_ID', 'EO_ID', 'NATION', 'SUBNATION', 'STD_GRP', 'GNAME', 'GCOMNAME', 'G_RANK', 'EORANK_CD', 'EORANK_D', 'ID_CONF', 'FIRSTOBS_D', 'LASTOBS_D', 'LOBS_Y', 'LOBS_MIN_Y', 'LOBS_MAX_Y', 'AREA_KM2'))
## Subnation means the subnation that maintains the EO, not the subnation where the EO occurs

## Get fields from intersect
bld.intersect.df<-arc.select(bld.intersect, fields = c('EGT_ID', 'EO_ID', boundary.fields, 'AREA_INT_M2'))

## Create one dataframe with required fields
## One row per EO
## Assign each EO to a single boundary category (select the boundary category that has the largest section of each EO contained)
## First groups by the boundary areas and calculates total eo area in each category (may add up to more than 100% of EO area because some slivers overlap - there are multiple managers for the area)
# bld.boundary.max <- bld.intersect.df %>% 
#   dplyr::group_by(across(all_of(c("EGT_ID", "EO_ID", boundary.fields)))) %>% 
#   mutate(AREA_INT_GROUPED = sum(AREA_INT_M2)) %>% 
#   group_by(EGT_ID, EO_ID) %>% 
#   dplyr::slice_max(AREA_INT_GROUPED) 

## Remove duplicate BLM_Gen assignments according to a hierarchy (duplicates occur due to overlapping polygons in the BLM admin boundary layer)
## Define order of hierarchy
# bld.boundary.max$BLM_Gen <- factor(bld.boundary.max$BLM_Gen, levels = c("BLM", "US Forest Service", "State", "Other Federal", "Bureau of Indian Affairs", "Private", "Other, Unknown"))
# 
# bld.boundary.max <- bld.boundary.max[order(bld.boundary.max$BLM_Gen),]
# 
# bld.boundary.max <- bld.boundary.max[!duplicated(bld.boundary.max[,c('EGT_ID', 'EO_ID')]),]

## Join the EO data with boundary data
# bld.blm <- left_join(x = bld.df, y = bld.boundary.max)

##ALTERNATIVE TO SELECTING THE AGENCY WITH MOST OF THE EO. INSTEAD ALLOW THE EOS TO BE SPLIT BETWEEN AGENCIES
## Join the EO data with boundary data (there are duplicate rows for EOs if they are in more than 1 jurisdiction)
bld.blm <- left_join(x = bld.df, y = bld.intersect.df)

## Write out results
write.csv(bld.blm, paste0(out.folder, "/EOxBLMBoundary.csv"), row.names = F)

## Read in overall results
bld.blm <- read.csv("Output-2022-12-28/EOxBLMBoundary.csv")

## Read in formatted results from AZ (source("Format-AZ-overlap-results-code.R"))
az.data <- read.csv("C:/Users/max_tarjan/NatureServe/BLM - BLM SSS Distributions and Rankings Project-FY21/Data/AZ_jurisdictional_request/Results-20230119/AZ_data_formatted.csv")

## FILTER EOs
## Remove EOs where the ID confidence is not certain
## EOs must be less than 30 years old
bld.blm.filter <- bld.blm %>%
  filter(ID_CONF %in% c("Y", "?") | is.na(ID_CONF)) %>%
  filter(LOBS_Y >= (format(Sys.Date(), "%Y") %>% as.numeric() - 35) | LOBS_MIN_Y >= as.numeric(format(Sys.Date()-35*365, "%Y")) | (is.na(LOBS_Y) & is.na(LOBS_MIN_Y))) ## should use LOBS_Y instead of LASTOBS_D - text field is not consistent; and should include the NULLS if there is no last obs date

## Skip filter step for testing
#bld.blm.filter <- bld.blm

## Summarize results
## Number of EOs per species and number of EOs on BLM-admin lands
## Assumes each EO is only in 1 jurisdiction
# eo.n <- bld.blm.filter %>% 
#   select(EGT_ID, EO_ID, BLM_Gen) %>% 
#   unique() %>% 
#   group_by(EGT_ID) %>% 
#   mutate(Total_EOs_Rangewide_2023 = n()) %>%
#   ungroup() %>%
#   group_by(EGT_ID, BLM_Gen) %>%
#   mutate(eos_BLM_Gen = n()) %>%
#   select(-EO_ID) %>%
#   unique() %>%
#   arrange(EGT_ID) %>%
#   spread(key = BLM_Gen, value = eos_BLM_Gen, fill = 0) %>%
#   mutate(Percent_EOs_BLM_2023 = BLM/Total_EOs_Rangewide_2023*100)

## Allows EOs to be split between multiple jurisdictions
## Get number of unique EOs for each EGT ID
eos_total <- bld.blm.filter %>%
  select(EGT_ID, EO_ID) %>%
  unique() %>%
  group_by(EGT_ID) %>%
  mutate(Total_EOs_Rangewide_2023 = n()) %>%
  select(-EO_ID) %>%
  unique()
bld.blm.filter <- left_join(bld.blm.filter, eos_total)

## Get number (fraction) of EOs for each jurisdiction
# eo.n <- bld.blm.filter %>%
#   mutate(AREA_INT_M2 = ifelse(is.na(AREA_INT_M2), 0, AREA_INT_M2)) %>%
#   group_by(EO_ID) %>%
#   mutate(eo_n = AREA_INT_M2/sum(AREA_INT_M2)) %>%
#   ungroup() %>%
#   group_by(EGT_ID, BLM_Gen) %>%
#   mutate(eos_BLM_Gen = sum(eo_n)) %>%
#   select(EGT_ID, BLM_Gen, Total_EOs_Rangewide_2023, eos_BLM_Gen) %>%
#   unique() %>%
#   arrange(EGT_ID) %>%
#   spread(key = BLM_Gen, value = eos_BLM_Gen, fill = 0) %>%
#   mutate(Percent_EOs_BLM_2023 = BLM/Total_EOs_Rangewide_2023*100) %>%
#   rename("Total_EOs_BLM_2023" = "BLM") %>%
#   select(-"<NA>")

## Alternative - get number of EOs that overlap with each jurisdiction. The jurisdiction gets a 1 if any fraction of the EO overlaps
eo.n <- bld.blm.filter %>%
  mutate(AREA_INT_M2 = ifelse(is.na(AREA_INT_M2), 0, AREA_INT_M2)) %>%
  select(BLM_Gen, EGT_ID, EO_ID) %>%
  unique() %>%
  group_by(BLM_Gen, EGT_ID) %>%
  mutate(EOs_BLM_Gen = n()) %>%
  select(-EO_ID) %>%
  unique() %>%
  spread(key = BLM_Gen, value = EOs_BLM_Gen, fill = 0) %>%
  left_join(eos_total) %>%
  mutate(Percent_EOs_BLM_2023 = BLM/Total_EOs_Rangewide_2023*100) %>%
  rename("Total_EOs_BLM_2023" = "BLM") %>%
  select(-"<NA>")

## Join results of jurisdictional analysis to esa SSS
#sss.esa <- left_join(sss.esa, eo.n, by = c("NatureServe Element ID"= "EGT_ID"))

#write.csv(sss.esa, paste0(out.folder, "/sss_esa_ja.csv"), row.names = F)

## Number of EOs for each species that occurs in each BLM_Gen category by eo rank and subnation; assumes each EO has one BLM_Gen assigned (no longer the case)
# eo.ja.rank.subnation <- bld.blm.filter %>% 
#   subset(select = c(EGT_ID, EO_ID, STATE_ABBR, EORANK_CD, BLM_Gen)) %>% 
#   unique() %>% 
#   group_by(EGT_ID, STATE_ABBR, EORANK_CD, BLM_Gen) %>% 
#   summarise(n_EOs = n()) %>% 
#   data.frame()

## Percent of A/B ranked EOs on BLM lands
## Get number of unique EOs ranked A/B for each EGT ID
eos_AB_total <- bld.blm.filter %>%
  filter(grepl(EORANK_CD, pattern = "A|B")) %>%
  select(EGT_ID, EO_ID) %>%
  unique() %>%
  group_by(EGT_ID) %>%
  mutate(Total_AB_EOs = n()) %>%
  select(-EO_ID) %>%
  unique()
bld.blm.filter <- left_join(bld.blm.filter, eos_AB_total)

## Get number (fraction) of EOs of rank A/B for each jurisdiction
# eo.ab.n <- bld.blm.filter %>%
#   filter(grepl(EORANK_CD, pattern = "A|B")) %>%
#   mutate(AREA_INT_M2 = ifelse(is.na(AREA_INT_M2), 0, AREA_INT_M2)) %>%
  # group_by(EO_ID) %>%
  # mutate(eo_n = AREA_INT_M2/sum(AREA_INT_M2)) %>%
  # ungroup() %>%
  # group_by(EGT_ID, BLM_Gen) %>%
  # mutate(eos_BLM_Gen = sum(eo_n)) %>%
  # select(EGT_ID, BLM_Gen, Total_AB_EOs, eos_BLM_Gen) %>%
  # unique() %>%
  # arrange(EGT_ID) %>%
  # spread(key = BLM_Gen, value = eos_BLM_Gen, fill = 0) %>%
  # mutate(Percent_AB_EOs_BLM = BLM/Total_AB_EOs*100) %>%
  # rename("Total_AB_EOs_BLM" = "BLM")

## Alternative - give jurisdiction 1 EO for each EO that overlaps (any section of the EO overlaps)
eo.ab.n <- bld.blm.filter %>%
  filter(grepl(EORANK_CD, pattern = "A|B")) %>%
  mutate(AREA_INT_M2 = ifelse(is.na(AREA_INT_M2), 0, AREA_INT_M2)) %>%
  select(BLM_Gen, EGT_ID, EO_ID) %>%
  unique() %>%
  group_by(BLM_Gen, EGT_ID) %>%
  mutate(EOs_BLM_Gen = n()) %>%
  select(-EO_ID) %>%
  unique() %>%
  spread(key = BLM_Gen, value = EOs_BLM_Gen, fill = 0) %>%
  left_join(eos_AB_total) %>%
  mutate(Percent_AB_EOs_BLM = BLM/Total_AB_EOs*100) %>%
  rename("Total_AB_EOs_BLM" = "BLM") %>%
  select(-"<NA>")

eo.n <- left_join(eo.n, subset(eo.ab.n, select = c(EGT_ID, Total_AB_EOs, Total_AB_EOs_BLM, Percent_AB_EOs_BLM)))

write.csv(eo.n, paste0(out.folder, "/blm_eo_jurisdiction_results-", Sys.Date(), ".csv"), row.names = F)

## Compare results to 2019 jurisdictional analysis
ja2019 <- read_excel("C:/Users/max_tarjan/NatureServe/BLM - BLM SSS Distributions and Rankings Project-FY21/Provided to BLM/BLM - Information for T & E Strategic Decision-Making - October 2022.xlsx", sheet = "BLM SSS Information by State", skip = 1) %>% 
  mutate(Percent_EOs_BLM_2019 = ifelse(`Total Occurrences on BLM Lands (West)`==0,0, as.numeric(`Occurrences on BLM Lands (West) / Total Occurrences Rangewide`)*100),
         Percent_Model_Area_BLM = `Percent Suitable Habitat on BLM Lands (West)`*100) %>%
  rename("EGT_ID" = "Element Global ID") %>%
  filter(`Elements Matched between BLM SSS List and NatureServe Data` !="-")
# #bld.ids<-subset(bld.df, EGT_ID %in% ja$NatureServe_Element_ID)$EGT_ID %>% unique() ## SSS IDs in bld dataset
# #bld.intersect.ids<-subset(bld.intersect.df, EGT_ID %in% ja$NatureServe_Element_ID)$EGT_ID %>% unique() ## SSS IDS in bld intersect
# #bld.ids.missing<-bld.ids[which(!bld.ids %in% bld.intersect.ids)] ## SSS ids in bld but missing from intersect

ja <- left_join(subset(ja2019, select= c(EGT_ID, Percent_EOs_BLM_2019, Percent_Model_Area_BLM)), subset(eo.n, select =c(EGT_ID, Percent_EOs_BLM_2023, Percent_AB_EOs_BLM)))
plot(data = ja, Percent_EOs_BLM_2023 ~ Percent_EOs_BLM_2019)

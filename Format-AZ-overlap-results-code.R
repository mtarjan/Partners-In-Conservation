## Format results from AZ for jurisdictional analysis
## BLM SSS
## Feb 9, 023

library(readxl)
library(RODBC)
library(tidyverse)
library(arcgisbinding)
## Check ArcGIS Pro product is installed locally
arc.check_product()

## Read in results from AZ
eo.az<-read_xls("C:/Users/max_tarjan/NatureServe/BLM - BLM SSS Distributions and Rankings Project-FY21/Data/AZ_jurisdictional_request/Results-20230119/AZ_EO_area.xls") #%>% select(c('EGT_ID', 'EO_ID', 'NATION', 'SUBNATION', 'SNAME', 'SCOMNAME', 'EORANK_CD', 'EO_RANK_DATE', 'LASTOBS_D', 'AREA_KM2')) %>% mutate(STD_GRP = NA, GRANK = NA, ID_CONF = NA, FIRSTOBS_D = NA, LOBS_Y = as.numeric(substr(LASTOBS_D, 1, 4)), LOBS_MIN_Y = NA, LOBS_MAX_Y = NA, GNAME=NA, GCOMNAME=NA)

az.intersect<-read_xls("C:/Users/max_tarjan/NatureServe/BLM - BLM SSS Distributions and Rankings Project-FY21/Data/AZ_jurisdictional_request/Results-20230119/AZ_EO_intersect.xls")

az.data <- left_join(y=eo.az, x=az.intersect) %>% rename(EGT_ID_AZ = EGT_ID, EO_ID_AZ=EO_ID)

## Query biotics to get EGT_ID from central
## pull EGT_OU_UID and EGT_SEQ_UID from biotics to find the central biotics egt_id

con<-odbcConnect("centralbiotics", uid="biotics_report", pwd=rstudioapi::askForPassword("Password"))

id.vector <- az.data %>% select(EGT_UID) %>% separate(col = EGT_UID, sep = "\\.", into = c("element", "org_id", "element_global_seq_uid")) %>% unique()
max.length <- 999
x <- 1
y <- min(c(max.length,nrow(id.vector)))
dat<-dim(0)
for (j in 1:ceiling((nrow(id.vector)/max.length))) {
  id.temp<-paste0("(", paste0(id.vector$element_global_seq_uid[x:y], collapse = ", "), ")")
  # org.temp<-paste0("(", paste0(id.vector$org_id[x:y], collapse = ", "), ")")
  
  
  qry <- paste0("SELECT egt.element_global_id, 'ELEMENT_GLOBAL.'||egt.element_global_ou_uid||'.'||egt.element_global_seq_uid egt_uid, egt.ROUNDED_G_RANK G_RANK, sn.SCIENTIFIC_NAME gname, egt.g_primary_common_name GCOMNAME
FROM 
ELEMENT_GLOBAL egt, SCIENTIFIC_NAME sn
WHERE egt.GNAME_ID =  sn.SCIENTIFIC_NAME_ID and egt.element_global_seq_uid in ", id.temp)
  dat.temp <- sqlQuery(con, qry)
  
  dat<-rbind(dat, dat.temp)
  x <- y +1
  y <- min(c(x-1+max.length,nrow(id.vector)))
}

# When finished, close the connection
odbcClose(con)

az.data <- left_join(x=az.data, y = dat)

## Add EO ids from spatial snapshot
## biotics snapshot
bld.path <- "S:/Data/NatureServe/BLD_Occurrences/NS_BLD_GeoDB/Snapshots/Monthly-2022-10/bld-2022-10.gdb/BLD_EO_SPECIES"
bld <- arc.open(bld.path)
## Create dataframe of info
bld.df <- arc.select(bld, fields = c('EGT_ID', 'EO_ID', 'EO_OU_UID', 'EO_UID'))

az.data <- left_join(x=az.data, y = bld.df %>% select(EO_ID, EO_UID) %>% unique())

az.data.sub <- az.data %>% mutate(STD_GRP = NA, ID_CONF = NA, FIRSTOBS_D = NA, LOBS_Y = as.numeric(substr(LASTOBS_D, 1, 4)), LOBS_MIN_Y = NA, LOBS_MAX_Y = NA, EORANK_D = EO_RANK_DA, AREA_INT_M2 = AREA_INT_KM2*1000000, EGT_ID = ELEMENT_GLOBAL_ID, EO_ID = EO_UID) %>% select(names(bld.blm))

write.csv(az.data.sub, "C:/Users/max_tarjan/NatureServe/BLM - BLM SSS Distributions and Rankings Project-FY21/Data/AZ_jurisdictional_request/Results-20230119/AZ_data_formatted.csv")

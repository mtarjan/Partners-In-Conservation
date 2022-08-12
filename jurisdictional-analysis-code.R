##BLM SSS jurisdictional analysis
##overlay models with BLM National Surface Management Agency Area Polygons

##outputs percent of mobi map (1s in mobi map) that is on BLM land
##categorical maps go from 1 (high) to 4 (no habitat). high and medium are used as habitat. probably none where this is applicable
##treasure areas: high probability habitat but no observations within certain distance. would need to load data for that. don't need to do this for prioritization
##output for j analysis: columns
##cutecode, field office (jurisdiction of that office; some field offices cross states), agency group, model category (high, med, low), overlap_km2, total_model_area, percentage range

##land managemange layer https://landscape.blm.gov/geoportal/catalog/search/resource/details.page?uuid=%7B2A8B8906-7711-4AF7-9510-C6C7FD991177%7D
##use land management layer from Anthony/Cameron because there were some adjustments made

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

library(sf)
library(tidyverse)
#library(exactextractr); library(raster) ##only required for internal r functions
library(readxl)

arcpy<-import("arcpy")

##LOAD SPATIAL LAYERS
##layer of spatial extent for selecting species
#boundary.path<-"G:/cameron/BLM_SMA_overlay/03_SMAgrouped_x_AdminUnits_dsslv.shp"
##start with boundary in mobi projection
boundary.path<-"Data/BLM_National_Surface_Management_Agency/BLM_Lands_NAD83.shp"

##biotics snapshot
distribution.data.path <- list.files("H://spp_models/", recursive = TRUE, pattern = "MOBI(.*?).tif$", full.names = TRUE)
mobi.cutecodes <- str_extract(distribution.data.path, "(?<=/)[^/]*$") %>% str_extract("[:alnum:]*")

##SELECT SPECIES FOR OUTPUTS
mobimodels<-read_excel("G:/tarjan/Species-select/Data/MoBI Modeling Summary by Species January 2021.xlsx", sheet = "MoBI_Model_Assessment", skip = 2) %>% data.frame()
colnames(mobimodels)[1:7]<-c("ELEMENT_GLOBAL_ID", "ELEMENT_GLOBAL_ID2", "cutecode", "Broad Group", "Taxonomic Group", "Scientific Name", "Common Name")
#ja.species <- read_excel("Data/BLMSSS-JA-species-shortlist.xlsx") %>% data.frame()
#ja.species <- left_join(x = ja.species, y = subset(mobimodels, select = c(cutecode, `Scientific Name`, ELEMENT_GLOBAL_ID, Included.in.MoBI)), by = c("NatureServe.Element.ID" = "ELEMENT_GLOBAL_ID"))
#ja.cutecodes<-subset(ja.species, !is.na(cutecode))$cutecode
##remove cutecodes that have already been completed
#ja.cutecodes<-subset(data.frame(ja.cutecodes), !(ja.cutecodes %in% out$cutecode) & ja.cutecodes != "myotsept")$ja.cutecodes
#ja.cutecodes<-subset(data.frame(mobi.cutecodes), !(mobi.cutecodes %in% out$cutecode))$mobi.cutecodes ##select only the cutecodes that don't appear in results

dir.create("temp_files"); arcpy$management$CreateFileGDB("temp_files", "geodatabase", "CURRENT") ##only need the geodatabase if going to use tabulate area
jur.dat <- dim(0) ##jurisdictional analysis data output
for (j in 1:length(distribution.data.path)) { ##for each model; length(distribution.data.path)
  ##find species
  sp.temp<-str_split(str_split(distribution.data.path[j], "/")[[1]][length(str_split(distribution.data.path[j], "/")[[1]])], pattern="_")[[1]][1]
  
  ##skip it if it's been done or if it's not on the shortlist
  #if (!sp.temp %in% ja.cutecodes) {next}
  #if (sp.temp %in% output$cutecode) {next} ##if it's already been done then skip it
  
  ##convert model raster to polygon
  #arcpy$conversion$RasterToPolygon(distribution.data.path[j], paste0("temp_files/",sp.temp,"_poly.shp"), "NO_SIMPLIFY", "Value", "SINGLE_OUTER_PART")
  ##plot polygon
  #plot(read_sf(paste0("temp_files/",sp.temp,"_poly.shp")))
  ##clip model by boundary
    #arcpy$Clip_analysis(in_features = boundary.path, clip_features = paste0("temp_files/",sp.temp,"_poly.shp"), out_feature_class = paste0("temp_files/",sp.temp,"_clip"))
  
  ##total area of model
  #total.area.temp <- st_area(read_sf(paste0("temp_files/",sp.temp,"_poly.shp"))) %>% sum()
  ##us sf package to open clipped shapefile
  #sp.manage <- read_sf(paste0("temp_files/",sp.temp,"_clip.shp"))
  ##reproject; not required if project initial input boundary
  #sp.manage <- st_transform(x = sp.manage, st_crs(read_sf(paste0("temp_files/",sp.temp,"_poly.shp"))))
  ##calculate area in each region
  #sp.manage$area_m2 <- st_area(sp.manage)
  
  ##ALTERNATIVE APPROACH; Tabulate Area
  #gdb.path<- "C:/Users/Max_Tarjan/Documents/ArcGIS/Projects/MyProject/MyProject.gdb/" ##need to write area tables to a geodatabase
  gdb.path<- "temp_files/geodatabase.gdb/"
  arcpy$sa$TabulateArea(boundary.path, "BLM_Gen", distribution.data.path[j], "Value", paste0(gdb.path, sp.temp, "_area"), distribution.data.path[j])
  dat.temp <- arc.open(path = paste0(gdb.path, sp.temp, "_area")) %>% arc.select() %>% subset(select = -OBJECTID)
  
  ##add to data.frame
  #dat.temp<-data.frame(sp.manage) %>% subset(select = c(BLM_Gen, ADMU_NAME, area_m2))
  dat.temp$ADMU_NAME<-NA
  names(dat.temp)[2]<-"area_m2"
  dat.temp$total.area<-sum(dat.temp$area_m2)
  #dat.temp$total.area.original<-total.area.temp ##equivalent to sum of management pieces
  dat.temp$cutecode<-sp.temp
  dat.temp$j<-j
  
  ##add to overall data.frame
  jur.dat<-rbind(jur.dat, dat.temp)
  write.csv(jur.dat, paste0("BLMSSS_jurisdictional_analysis_mobi_", Sys.Date(), ".csv"), row.names = F)
  print(j)
}

##ALTERNATIVE APPROACH; R PACKAGE
#boundary<-read_sf(boundary.path) ##only needed if doing internal r functions
##extract sum of raster values and add them up; then convert to area
#mobi.temp<-raster(distribution.data.path[1])
#boundary.nad <- st_transform(x = boundary, st_crs(mobi.temp))
#boundary$sum <- exactextractr::exact_extract(x = mobi.temp, y = boundary.nad, 'sum')

##wrangle data into final output
##add species name and explorer ID from mobi spreadsheet
##sum all BLM_Gen =="BLM" and get a percentage
##read and rbind outputs from all runs
outputs <- list.files(getwd(), recursive = F, pattern = ".csv", full.names = TRUE)
output<-dim(0)
for (j in 1:length(outputs)) {
  out.temp<-read.csv(outputs[j])
  out.temp <- rename(out.temp, c('BLM_Gen'='BLM_GEN'))
  out.temp<-subset(out.temp, select = c(cutecode, BLM_Gen, ADMU_NAME, area_m2, total.area)) ##removes column called "j", which is only present for some
  output<-rbind(output, out.temp)
}

##check whether there are any errors where cutecodes are different but total area is equal
#temp<-table(round(output$total.area,0), output$cutecode) %>% data.frame() %>% subset(Freq>0)
#dups<-temp[which(duplicated(temp$Var1)),]$Var1
#subset(output, round(total.area,0)==dups[j])
#for (j in 2:nrow(output)) {
#  if (output$cutecode[j]!=output$cutecode[j-1] & output$total.area[j]==output$total.area[j-1]) {print(j)} ##print out j if the cutecode is different from the species above but the area is the same
#}
#output %>% group_by(cutecode) %>% summarise(diff=max(total.area)-min(total.area)) %>% subset(diff != 0) %>% head() ##show species that have two different values for total.area, indictating that there was an error in writing out the data (e.g., the got their area value from the previous species in the que)

##summarize results; fills 0s if the combination doesn't occur (blm gen x species)
output <- output[which(!duplicated(subset(output, select = c(BLM_Gen, ADMU_NAME, cutecode)))),] ##remove duplicates
out <- subset(output) %>% group_by(cutecode, BLM_Gen) %>% summarise(model.area = total.area, area_m2 = sum(area_m2)) %>% unique() %>% spread(key = BLM_Gen, value = area_m2, fill = 0) %>% data.frame()
out$percent.model.area.BLM <- round(out$BLM/out$model.area*100, 3)
head(out)
##add other identifiers
out<- left_join(out, subset(mobimodels, select = c(ELEMENT_GLOBAL_ID, cutecode, `Scientific Name`)))

##add to BLM SSS list
blmsss<-read_excel("Data/BLM - Information for T & E Strategic Decision-Making - April 2021.xlsx", sheet= "BLM SSS Information by State", skip = 1)[,1:11]
names(blmsss)
blmsss$percent.EOs.BLM <- round(blmsss$`Total Occurrences on BLM Lands (West)`/blmsss$`Total Occurrences Rangewide`*100, 3)

blmsss.ja<- left_join(blmsss, subset(out, select = c(ELEMENT_GLOBAL_ID, cutecode, model.area, BLM, percent.model.area.BLM)), by = c("Element Global ID" = "ELEMENT_GLOBAL_ID"))

write.csv(blmsss.ja, "Output/BLMSSS-JA-results-20220812.csv", row.names = F, na= "")
  
##output only the species that Bruce needs for preliminary list
#ja.results.shortlist <- left_join(ja.species, subset(out, select = c(cutecode, model.area, BLM, percent.model.area.BLM)))

##add eo and model info to shortlist
#ja.results.shortlist<-left_join(ja.results.shortlist, subset(blmsss, select = c(`Element Global ID`, percent.EOs.BLM)), by = c("NatureServe.Element.ID"="Element Global ID"))

#write.csv(ja.results.shortlist, "Output/BLMSSS-JA-shortlist-results-20220808.csv", row.names = F, na= "")

##compare JA from EOs versus models
plot(data = blmsss.ja, percent.model.area.BLM~percent.EOs.BLM, ylab = "Percent Model on BLM Lands", xlab = "Percent EOs on BLM Lands"); abline(a=0, b=0.7111)
##fit a linear regression
ja.lm <- lm(percent.model.area.BLM ~ 0 + percent.EOs.BLM, data = blmsss.ja); ja.lm

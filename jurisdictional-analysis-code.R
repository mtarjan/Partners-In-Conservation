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

##SELECT SPECIES FOR OUTPUTS
mobimodels<-read_excel("G:/tarjan/Species-select/Data/MoBI Modeling Summary by Species January 2021.xlsx", sheet = "MoBI_Model_Assessment", skip = 2) %>% data.frame()
colnames(mobimodels)[1:7]<-c("ELEMENT_GLOBAL_ID", "ELEMENT_GLOBAL_ID2", "cutecode", "Broad Group", "Taxonomic Group", "Scientific Name", "Common Name")
ja.species <- read_excel("Data/BLMSSS-JA-species-shortlist.xlsx") %>% data.frame()
ja.species <- left_join(x = ja.species, y = subset(mobimodels, select = c(cutecode, `Scientific Name`, ELEMENT_GLOBAL_ID)), by = c("NatureServe.Element.ID" = "ELEMENT_GLOBAL_ID"))
ja.cutecodes<-subset(ja.species, !is.na(cutecode))$cutecode
##remove cutecodes that have already been completed
ja.cutecodes<-subset(data.frame(ja.cutecodes), !(ja.cutecodes %in% out$cutecode) & ja.cutecodes != "myotsept")$ja.cutecodes

dir.create("temp_files")
jur.dat <- dim(0) ##jurisdictional analysis data output
for (j in 1:length(distribution.data.path)) { ##for each model; length(distribution.data.path)
  ##find species
  sp.temp<-str_split(str_split(distribution.data.path[j], "/")[[1]][length(str_split(distribution.data.path[j], "/")[[1]])], pattern="_")[[1]][1]
  
  ##skip it if it's been done or if it's not on the shortlist
  if (!sp.temp %in% ja.cutecodes) {next}
  
  ##convert model raster to polygon
  arcpy$conversion$RasterToPolygon(distribution.data.path[j], paste0("temp_files/",sp.temp,"_poly.shp"), "NO_SIMPLIFY", "Value", "SINGLE_OUTER_PART")
  ##plot polygon
  #plot(read_sf(paste0("temp_files/",sp.temp,"_poly.shp")))
  ##clip model by boundary
    arcpy$Clip_analysis(in_features = boundary.path, clip_features = paste0("temp_files/",sp.temp,"_poly.shp"), out_feature_class = paste0("temp_files/",sp.temp,"_clip"))
  
  ##total area of model
  total.area.temp <- st_area(read_sf(paste0("temp_files/",sp.temp,"_poly.shp"))) %>% sum()
  ##us sf package to open clipped shapefile
  sp.manage <- read_sf(paste0("temp_files/",sp.temp,"_clip.shp"))
  ##reproject; not required if project initial input boundary
  sp.manage <- st_transform(x = sp.manage, st_crs(read_sf(paste0("temp_files/",sp.temp,"_poly.shp"))))
  ##calculate area in each region
  sp.manage$area_m2 <- st_area(sp.manage)
  ##add to data.frame
  dat.temp<-data.frame(sp.manage) %>% subset(select = c(BLM_Gen, ADMU_NAME, area_m2))
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

##ALTERNATIVE APPROACH; Tabulate Area
#arcpy$sa$TabulateArea(boundary.path, "BLM_Gen", distribution.data.path[j], "Value", paste0("temp_files/",sp.temp,"_area"), distribution.data.path[j])


##wrangle data into final output
##add species name and explorer ID from mobi spreadsheet
##sum all BLM_Gen =="BLM" and get a percentage
##read and rbind outputs from all runs
outputs <- list.files(getwd(), recursive = F, pattern = ".csv", full.names = TRUE)
output<-dim(0)
for (j in 1:length(outputs)) {
  out.temp<-read.csv(outputs[j])
  out.temp<-out.temp[,1:5] ##removes column called "j", which is only present for some
  output<-rbind(output, out.temp)
}

##summarize results; need a way to add 0s
output<-unique(output) ##remove duplicates
out <- subset(output) %>% group_by(cutecode, BLM_Gen) %>% summarise(model.area = total.area, area_m2 = sum(area_m2)) %>% unique() %>% spread(key = BLM_Gen, value = area_m2, fill = 0) %>% data.frame()
out$percent.model.area.BLM <- round(out$BLM/out$model.area*100, 3)
head(out)

##output only the species that Bruce needs for preliminary list
ja.results.shortlist <- left_join(ja.species, subset(out, select = c(cutecode, model.area, BLM, percent.model.area.BLM)))
write.csv(ja.results.shortlist, "Output/BLMSSS-JA-shortlist-results-20220804.csv", row.names = F)

##add to 
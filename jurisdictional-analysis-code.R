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
#library(readxl)

arcpy<-import("arcpy")

##CREATE OUTPUT FOLDER
if (!file.exists(str_c("Output-", Sys.Date()))) {
  dir.create(str_c("Output-", Sys.Date()))
}

##LOAD SPATIAL LAYERS
##layer of spatial extent for selecting species
boundary.path<-"G:/cameron/BLM_SMA_overlay/03_SMAgrouped_x_AdminUnits_dsslv.shp"

##biotics snapshot
distribution.data.path <- list.files("H://spp_models/", recursive = TRUE, pattern = "MOBI.tif$", full.names = TRUE)

dir.create("temp_files")
jur.dat <- dim(0) ##jurisdictional analysis data output
for (j in 1:length(distribution.data.path)) { ##for each model; length(distribution.data.path)
  ##find species
  sp.temp<-str_split(distribution.data.path[j], "/")[[1]][length(str_split(distribution.data.path[j], "/")[[1]])] %>% str_sub(start = 1, end = 8)
  ##convert model raster to polygon
  arcpy$conversion$RasterToPolygon(distribution.data.path[j], paste0("temp_files/",sp.temp,"_poly.shp"), "NO_SIMPLIFY", "Value", "SINGLE_OUTER_PART")
  ##clip model by boundary
    arcpy$Clip_analysis(in_features = boundary.path, clip_features = paste0("temp_files/",sp.temp,"_poly.shp"), out_feature_class = paste0("temp_files/",sp.temp,"_clip"))
  ##remove overlaps in jurisdictional boundaries; doesn't fix area issue
    #arcpy$analysis$RemoveOverlapMultiple(in_features = paste0("temp_files/",sp.temp,"_clip.shp"), out_feature_class = paste0("temp_files/",sp.temp,"_RemoveOverlap"), method = "CENTER_LINE", join_attributes = "ALL")
  
  ##total area of model
  total.area.temp <- st_area(read_sf(paste0("temp_files/",sp.temp,"_poly.shp"))) %>% sum()
  ##us sf package to open clipped shapefile
  sp.manage <- read_sf(paste0("temp_files/",sp.temp,"_clip.shp"))
  ##reproject
  sp.manage <- st_transform(x = sp.manage, st_crs(read_sf(paste0("temp_files/",sp.temp,"_poly.shp"))))
  ##calculate area in each region
  sp.manage$area_m2 <- st_area(sp.manage)
  ##add to data.frame
  dat.temp<-data.frame(sp.manage) %>% subset(select = c(BLM_Gen, ADMU_NAME, area_m2))
  dat.temp$total.area<-sum(dat.temp$area_m2)
  #dat.temp$total.area.original<-total.area.temp ##equivalent to sum of management pieces
  dat.temp$cutecode<-sp.temp
  
  ##add to overall data.frame
  jur.dat<-rbind(jur.dat, dat.temp)
  write.csv(jur.dat, paste0("BLMSSS_jurisdictional_analysis_mobi_", Sys.Date(), ".csv"), row.names = F)
  print(j)
}

##wrangle data into final output


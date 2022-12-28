## Figure for BLM SSS year 2 report - jurisdictional analysis
library(tidyverse)
library(readxl)

sss <- read_excel("C:/Users/max_tarjan/NatureServe/BLM - BLM SSS Distributions and Rankings Project-FY21/Provided to BLM/BLM - Information for T & E Strategic Decision-Making - October 2022.xlsx", sheet= "BLM SSS Information by State", skip=1)

data.plot <- sss %>%
  subset(!is.na(`Percent Suitable Habitat on BLM Lands (West)`)) %>%
  arrange(desc(`Percent Suitable Habitat on BLM Lands (West)`)) %>%
  head(20) %>%
  mutate(Species = paste0(ifelse(is.na(`Common Name`), `Scientific Name`, `Common Name`), " (", `Scientific Name`, ")")) %>%
  rename(`G Rank`= `Global Rank (18July2020)`,
         `Occurrences` = `Occurrences on BLM Lands (West) / Total Occurrences Rangewide`,
         `Predicted Habitat` = `Percent Suitable Habitat on BLM Lands (West)`) %>%
  gather(key = `Overlap Type`, value = `Percent Overlap`, c(`Predicted Habitat`, `Occurrences`)) %>%
  select(c("Taxonomic Group", "Species", "G Rank", "Overlap Type", "Percent Overlap")) %>%
  mutate(`Percent Overlap` = ifelse(`Percent Overlap` == "-", 0, as.numeric(`Percent Overlap`)))
data.plot$`Species` <- factor(data.plot$`Species`, levels = data.plot %>% arrange(`Percent Overlap`, `Overlap Type`) %>% pull(`Species`) %>% unique())
data.plot %>% data.frame() 

fig <- ggplot(data = data.plot, aes(x = Species, y = `Percent Overlap`*100, fill=`Overlap Type`)) +
  geom_bar(stat="identity", position = "dodge", color = grey(0.2), size = 0.5) +
  coord_flip() +
  theme_bw() +
  theme(rect = element_blank(), 
        panel.grid.major.y = element_blank(),
        axis.ticks = element_blank(),
        axis.title.y = element_blank(),
        axis.text.y = element_text(hjust = 0),
        legend.title = element_blank()#,
        #legend.position = "none"
  ) +
  #geom_text(aes(label = `Taxonomic Group`), size = 3, y=data.plot$`Percent Overlap`*100/2) +
  scale_fill_brewer(palette = "Greens", direction = -1) +
  ylab("Percent overlap with BLM Lands West")
fig

png(filename = "fig.blmsss.jurisdiction.results.barplot.png", width = 6.5, height = 7, units = "in", res=200)
print(fig)
dev.off()

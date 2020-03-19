library(tidyverse)
library(rvest)
library(sf)
library(rcartocolor)
library(ggpmthemes)
library(ggforce)

theme_set(theme_maven())

url <-
  "https://www.quebec.ca/sante/problemes-de-sante/a-z/coronavirus-2019/#c46333"

df <- read_html(url) %>%
  html_nodes("table") %>%
  .[[1]] %>%
  html_table() %>%
  as_tibble() %>%
  janitor::clean_names() %>%
  filter(str_detect(regions, "^\\d{2}")) %>%
  type_convert() %>%
  extract(regions,
    into = c("region_no", "region_nom"),
    regex = "(\\d{2})\\W+(.*)"
  ) %>%
  rename(n = 3)

df

# https://www.donneesquebec.ca/recherche/fr/dataset/decoupages-administratifs
region_sf <- st_read("data/raw/SHP/SHP/regio_s.shp")

df_viz <- df %>%
  full_join(region_sf %>% as_tibble(), by = c("region_no" = "RES_CO_REG")) %>%
  st_as_sf() %>%
  st_transform(crs = 6624)

lab <- df_viz %>%
  mutate(center = st_centroid(geometry)) %>%
  drop_na(n) %>%
  as_tibble() %>%
  cbind(st_coordinates(.$center))

lab

df_viz %>%
  ggplot() +
  geom_sf(aes(fill = n), show.legend = FALSE, size = 0.25, color = "gray75") +
  scale_fill_carto_c(palette = "SunsetDark") +
  geom_mark_circle(
    data = lab,
    aes(
      x = X,
      y = Y,
      label = str_wrap(region_nom, 10),
      description = glue::glue("Cas confirmés: {n}"),
      group = region_no
    ),
    label.fontsize = 10,
    label.buffer = unit(1, "cm"),
    expand = unit(0.1, "cm"),
    label.fill = "transparent",
    con.size = 0.25,
    con.colour = "gray65",
    con.border = "none"
  ) +
  coord_sf() +
  labs(
    title = str_wrap("Nombre de cas de coronavirus confirmés au Québec", 40),
    subtitle = glue::glue("En date du {Sys.Date()}"),
    caption = "Données: https://www.quebec.ca/sante/problemes-de-sante/a-z/coronavirus-2019/"
  ) +
  theme(
    plot.background = element_blank(),
    panel.background = element_blank(),
    axis.title = element_blank(),
    axis.ticks = element_blank(),
    axis.text = element_blank(),
    panel.grid = element_blank(),
    panel.border = element_blank(),
    plot.title.position = "plot"
  )

ggsave(
  here::here("graphs", "covid19_map_quebec.png"),
  type = "cairo",
  dpi = 600,
  width = 8,
  height = 8
)
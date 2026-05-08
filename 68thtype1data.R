# Load Libraries
library(vroom)
library(dplyr)
library(readxl)

# Set Working Directory
setwd("~/Downloads/Nss68_1.0_Type1")

#read nss files

# Level 1
lvl01 = vroom_fwf(
  file = "Data/R6801T1L01.TXT",
  fwf_cols(
    fsu   = c(4,8),
    hgsb  = c(32,32),
    sss   = c(33,33),
    hhn   = c(34,35),
    sctr  = c(15,15),
    state = c(16,17),
    dist  = c(19,19),
    mlt   = c(133,142)))

# Level 2
lvl02 = vroom_fwf(
  file = "Data/R6801T1L02.TXT",
  fwf_cols(
    fsu   = c(4,8),
    hgsb  = c(32,32),
    sss   = c(33,33),
    hhn   = c(34,35),
    hhsz  = c(43,44)))

# Level 3 (MPCE data)
lvl03 = vroom_fwf(
  file = "Data/R6801T1L03.TXT",
  fwf_cols(
    fsu       = c(4,8),
    hgsb      = c(32,32),
    sss       = c(33,33),
    hhn       = c(34,35),
    mpce_urp  = c(55,63),
    mpce_mpr  = c(64,72)))

# Convert MPCE to numeric
lvl03 = lvl03 %>%
  mutate(
    mpce_urp = as.numeric(mpce_urp)/100,
    mpce_mpr = as.numeric(mpce_mpr)/100)


# read poverty line data

povl = read_xlsx("Tendulkar Povertyline (1).xlsx")

povl = povl %>%
  na.omit() %>%
  select(-'2004-05', -'2009-10') %>%
  rename(povline = '2011-12') %>%
  select(-statenm)


# merge all levels

lvl123 = lvl01 %>%
  left_join(lvl02, by=c("fsu","hgsb","sss","hhn")) %>%
  left_join(lvl03, by=c("fsu","hgsb","sss","hhn"))

# convert sector levels
lvl123 = lvl123 %>%
  mutate( sctr = case_when(sctr == 1 ~ "Rural",sctr == 2 ~ "Urban"),
    state = as.numeric(state))

# merge poverty line
lvl123 = lvl123 %>%
  left_join(povl, by=c("state","sctr"))


# create poverty variable

lvl123 = lvl123 %>%
  mutate(poor = case_when(
      mpce_mpr < povline ~ 1,
      mpce_mpr >= povline ~ 0))


# create weights

lvl123 = lvl123 %>%
  mutate(
    weight = mlt / 100)


# add state names

stcode = read_xlsx("statecode.xlsx")

lvl123 = lvl123 %>%
  left_join(stcode, by="state")


# calculate poverty ratio

pov = lvl123 %>%
  group_by(state3, sctr) %>%
  summarise(
    povert = weighted.mean(poor,
      weight * hhsz,
      na.rm = TRUE))

View(pov)


# plot poverty

pov %>%
  filter(sctr == "Rural") %>%
  arrange(desc(povert)) %>%
  ggplot(aes(x = reorder(state3, povert),y = povert)) +
  geom_bar(stat = "identity") + coord_flip() + labs(title = "Rural Poverty Across States (NSS 68th Round)",x = "State",y = "Poverty Ratio")

write.xlsx(pov, "state_poverty_estimates.xlsx")
getwd()
write.csv(pov, "state_poverty_estimates.csv", row.names = FALSE)

ggsave("rural_poverty_states.png",
  width = 10,
  height = 7,
  dpi = 300)

#rural-urban gap plot

pov %>%
  pivot_wider(names_from = sctr, values_from = povert) %>%
  mutate(gap = Rural - Urban) %>%
  ggplot(aes(x = reorder(state3, gap), y = gap)) +
  geom_col() +
  coord_flip() +
  labs(title = "Rural–Urban Poverty Gap Across States",
    x = "State", y = "Rural - Urban Poverty Ratio" ) 

ggsave("rural_urban_gap.png")
  
library(ineq)
ineq_state <- lvl123 %>%
  group_by(state3, sctr) %>%
  summarise( gini_mpr = ineq(mpce_mpr, type = "Gini"),
    p90 = quantile(mpce_mpr, 0.9, na.rm = TRUE),
    p10 = quantile(mpce_mpr, 0.1, na.rm = TRUE)) 






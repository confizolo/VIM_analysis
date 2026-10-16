#!/usr/bin/env Rscript
# --- generate_visuals.R ---
# Generates high-quality ggplot2 visualizations for the VIM Analysis

library(ggplot2)
library(dplyr)
library(tidyr)
library(forcats)

dir.create("results/figures/power_and_density", showWarnings = FALSE, recursive = TRUE)

ha_data <- read.csv("results/tables/ha_analysis_results.csv")
null_data <- read.csv("results/tables/null_analysis_results.csv")

# Single source of truth for VIM publication labels
source("utils/vim_map.R")

all_vims <- unname(VIM_MAP)

ha_data   <- ha_data   %>% mutate(VIM = factor(recode(VIM, !!!VIM_MAP), levels = all_vims))
null_data <- null_data %>% mutate(VIM = factor(recode(VIM, !!!VIM_MAP), levels = all_vims))

intro_text <- "Variable Importance Measure (VIM) Glossary"

p0 <- ggplot() + 
  annotate("text", x = 0, y = 0, label = intro_text, hjust = 0, vjust = 0.5, size = 4) + 
  theme_void() + 
  xlim(0, 10) + ylim(-1, 1)
ggsave("results/figures/power_and_density/0_intro.png", plot = p0, width = 11, height = 8, bg = "white")

ha_main <- ha_data %>% filter(!grepl("int", Scenario) & !grepl("null", Scenario)) %>%
  mutate(
    BlockSize = ifelse(grepl("03", Scenario), "3 correlated noise variables", "33 correlated noise variables"),
    CorrLevel = ifelse(grepl("05", Scenario), "Correlation intensity: 0.05", "Correlation intensity: 0.9"),
    EffectSize = ifelse(grepl("strong", Scenario), "Strong Effect", "Weak Effect")
  )

for (metric in c("Power_Null1", "Power_CNull")) {
  ha_power <- ha_main %>%
    select(VIM, CorrLevel, BlockSize, EffectSize, all_of(metric)) %>%
    pivot_wider(names_from = BlockSize, values_from = metric) %>%
    pivot_longer(cols = c("3 correlated noise variables", "33 correlated noise variables"), names_to = "BlockSize", values_to = "Power")

  # 3A. Primary Power (WEAK)
  p1_weak <- ggplot(ha_power %>% filter(EffectSize == "Weak Effect") %>% mutate(VIM = fct_drop(VIM)), aes(x = Power, y = fct_reorder(VIM, Power, .fun = min, na.rm = TRUE))) +
    geom_line(aes(group = VIM), color = "gray50", linewidth = 1) +
    geom_point(aes(color = BlockSize), size = 3) +
    scale_color_manual(values = c("3 correlated noise variables" = "#1b9e77", "33 correlated noise variables" = "#d95f02")) +
    facet_wrap(~ CorrLevel) +
    theme_minimal() +
    labs(x = "Power", y = "VIM", color = "Noise Variables")
  ggsave(paste0("results/figures/power_and_density/3a_", tolower(metric), "_weak.png"), plot = p1_weak, width = 10, height = 6, bg = "white")

  # 3B. Primary Power (STRONG)
  p1_strong <- ggplot(ha_power %>% filter(EffectSize == "Strong Effect") %>% mutate(VIM = fct_drop(VIM)), aes(x = Power, y = fct_reorder(VIM, Power, .fun = min, na.rm = TRUE))) +
    geom_line(aes(group = VIM), color = "gray50", linewidth = 1) +
    geom_point(aes(color = BlockSize), size = 3) +
    
    scale_color_manual(values = c("3 correlated noise variables" = "#1b9e77", "33 correlated noise variables" = "#d95f02")) +
    facet_wrap(~ CorrLevel) +
    theme_minimal() +
    labs(x = "Power", y = "VIM", color = "Noise Variables")
  ggsave(paste0("results/figures/power_and_density/3b_", tolower(metric), "_strong.png"), plot = p1_strong, width = 10, height = 6, bg = "white")
}

# 4. Dumbbell Plot: Diff_HA Correlation Comparison
ha_corr_diff <- ha_main %>%
  select(VIM, CorrLevel, BlockSize, EffectSize, Diff_HA) %>%
  pivot_wider(names_from = BlockSize, values_from = Diff_HA) %>%
  pivot_longer(cols = c("3 correlated noise variables", "33 correlated noise variables"), names_to = "BlockSize", values_to = "Diff_HA")

p4 <- ggplot(ha_corr_diff %>% mutate(VIM = fct_drop(VIM)), aes(x = Diff_HA, y = fct_reorder(VIM, Diff_HA, .fun = min, na.rm = TRUE))) +
  geom_line(aes(group = VIM), color = "gray50", linewidth = 1) +
  geom_point(aes(color = BlockSize), size = 3) +
  scale_color_manual(values = c("3 correlated noise variables" = "#1b9e77", "33 correlated noise variables" = "#d95f02")) +
  facet_grid(EffectSize ~ CorrLevel) +
  theme_minimal() +
  labs(x = "Diff HA", y = "VIM", color = "Noise Variables")
ggsave("results/figures/power_and_density/4_diff_ha.png", plot = p4, width = 11, height = 8, bg = "white")

# 6. Dumbbell Plot: 1D VIM Failure on Interaction (Main vs Int)
ha_1d_int <- ha_data %>% 
  filter(grepl("int", Scenario)) %>%
  mutate(EffectSize = ifelse(grepl("strong", Scenario), "Strong Effect", "Weak Effect")) %>%
  select(Scenario, VIM, EffectSize, Power_Null1, Power_Null2) %>%
  rename(Power_Main = Power_Null1, Power_Int_1D = Power_Null2) %>%
  pivot_longer(cols = c(Power_Main, Power_Int_1D), names_to = "EffectType", values_to = "Power")

# 6A. Dumbbell Plot: 1D VIM Failure on Interaction (Main vs Int) - WEAK
order_weak <- ha_1d_int %>% filter(Scenario == "weakint3390" & EffectType == "Power_Main") %>% arrange(Power) %>% pull(VIM) %>% as.character()
p6_weak <- ggplot(ha_1d_int %>% filter(EffectSize == "Weak Effect") %>% mutate(VIM = factor(VIM, levels = order_weak)), aes(x = Power, y = VIM)) +
  geom_line(aes(group = VIM), color = "gray50", linewidth = 1) +
  geom_point(aes(color = EffectType), size = 3) +
  scale_color_manual(values = c("Power_Main" = "#377eb8", "Power_Int_1D" = "#e41a1c"),
                     labels = c("Power_Main" = "X1", "Power_Int_1D" = "X100")) +
  facet_wrap(~Scenario, ncol = 2) +
  theme_minimal() +
  labs(x = "Power", y = "VIM", color = "Effect Type") +
  theme(axis.text.y = element_text(size = 8))
ggsave("results/figures/power_and_density/6a_1d_interaction_weak.png", plot = p6_weak, width = 8, height = 8, bg = "white")

# 6B. Dumbbell Plot: 1D VIM Failure on Interaction (Main vs Int) - STRONG
order_strong <- ha_1d_int %>% filter(Scenario == "strongint3390" & EffectType == "Power_Main") %>% arrange(Power) %>% pull(VIM) %>% as.character()
p6_strong <- ggplot(ha_1d_int %>% filter(EffectSize == "Strong Effect") %>% mutate(VIM = factor(VIM, levels = order_strong)), aes(x = Power, y = VIM)) +
  geom_line(aes(group = VIM), color = "gray50", linewidth = 1) +
  geom_point(aes(color = EffectType), size = 3) +
  scale_color_manual(values = c("Power_Main" = "#377eb8", "Power_Int_1D" = "#e41a1c"),
                     labels = c("Power_Main" = "X1", "Power_Int_1D" = "X100")) +
  facet_wrap(~Scenario, ncol = 2) +
  theme_minimal() +
  labs(x = "Power", y = "VIM", color = "Effect Type") +
  theme(axis.text.y = element_text(size = 8))
ggsave("results/figures/power_and_density/6b_1d_interaction_strong.png", plot = p6_strong, width = 8, height = 8, bg = "white")

# 7. Bar Chart: Interaction Power (2D VIMs only)
ha_int <- ha_data %>% filter(grepl("int", Scenario) & !is.na(Power_Int))
if(nrow(ha_int) > 0) {
  p3 <- ggplot(ha_int, aes(x = Scenario, y = Power_Int, fill = VIM)) +
    geom_bar(stat = "identity", position = position_dodge(width=0.8), width=0.7) +
    scale_fill_brewer(palette = "Set1") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
    labs(x = "Scenario", y = "Power")
  ggsave("results/figures/power_and_density/7_interaction_power.png", plot = p3, width = 11, height = 8, bg = "white")
}

cat("Plots successfully generated in results/figures/power_and_density/\n")

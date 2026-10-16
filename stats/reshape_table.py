import glob
import pandas as pd
import numpy as np

files = glob.glob("results/tables/bias_coverage/results_*.csv")
data = []

var_map = {"v1": "X1 (Main)", "v100": "X100 (Main)", "Int": "X1:X100 (Int)"}

for f in files:
    scenario = f.split("_")[-1].replace(".csv", "")
    df = pd.read_csv(f)
    
    for var, label in var_map.items():
        row = {"Scenario": scenario, "Variable": label}
        
        if f"Bias_{var}" in df.columns:
            bias = df[f"Bias_{var}"].dropna()
            if len(bias) > 0:
                row["Bias (2.5%)"] = np.percentile(bias, 2.5)
                row["Bias (50%)"] = np.percentile(bias, 50)
                row["Bias (97.5%)"] = np.percentile(bias, 97.5)
            else:
                row["Bias (2.5%)"] = np.nan
                row["Bias (50%)"] = np.nan
                row["Bias (97.5%)"] = np.nan
                
            cover = df[f"Cover_{var}"].dropna()
            row["Coverage"] = cover.mean() if len(cover) > 0 else np.nan
            
            p_vals = df.get(f"P_{var}")
            if p_vals is not None:
                p = p_vals.dropna()
                row["Median P-value"] = p.median() if len(p) > 0 else np.nan
            else:
                row["Median P-value"] = np.nan
                
            data.append(row)

df_out = pd.DataFrame(data).sort_values(by=["Scenario", "Variable"])

out_md = []
out_md.append("| Scenario | Variable | Bias (2.5%) | Bias (50%) | Bias (97.5%) | Coverage | Median P-value |")
out_md.append("|---|---|---|---|---|---|---|")

current_scenario = ""
for idx, row in df_out.iterrows():
    vals = []
    
    if row["Scenario"] != current_scenario:
        vals.append(f"**{row['Scenario']}**")
        current_scenario = row["Scenario"]
    else:
        vals.append("")
        
    vals.append(row["Variable"])
    
    for col in ["Bias (2.5%)", "Bias (50%)", "Bias (97.5%)", "Coverage", "Median P-value"]:
        val = row[col]
        if pd.isna(val):
            vals.append("NA")
        elif "P-value" in col:
            vals.append(f"{val:.2e}")
        elif "Coverage" in col:
            vals.append(f"{val:.3f}")
        else:
            vals.append(f"{val:.3f}")
            
    out_md.append("| " + " | ".join(vals) + " |")

with open("results/tables/Regression_Bias_Coverage_Table.md", "w") as f:
    f.write("\n".join(out_md) + "\n")

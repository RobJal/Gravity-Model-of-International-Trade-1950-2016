"""
README figure: U.S. trade vs. distance in 2016, before and after netting out
partner GDP. Reads the cross-section exported by gravity_model.do.

Usage (from the project root):
    pip install pandas numpy matplotlib
    python code/us_bias_figure.py
"""

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "output" / "tables" / "us_2016.csv"
OUT = ROOT / "output" / "figures" / "us_distance_bias_2016.png"

SURFACE, INK, INK_2, BLUE, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#2a78d6", "#e4e3df"
LABELS = {"CAN": ("Canada", (7, 0)), "MEX": ("Mexico", (7, -11)), "CHN": ("China", (7, -3))}


def main() -> None:
    d = pd.read_csv(DATA)
    # Imposes a unit GDP elasticity to net out partner size
    d["ln_trade_adj"] = d["ln_trade"] - d["ln_gdp_j"]

    plt.rcParams.update({
        "font.family": "DejaVu Sans", "font.size": 11,
        "axes.edgecolor": INK_2, "axes.labelcolor": INK,
        "xtick.color": INK_2, "ytick.color": INK_2,
    })
    fig, axes = plt.subplots(1, 2, figsize=(11, 4.6), facecolor=SURFACE)
    panels = [
        ("ln_trade", "Log total trade", "Unadjusted"),
        ("ln_trade_adj", "Log trade minus log partner GDP", "Adjusted for partner GDP"),
    ]

    for ax, (y, ylabel, title) in zip(axes, panels):
        ax.set_facecolor(SURFACE)
        ax.scatter(d["ln_dist"], d[y], s=36, color=BLUE, alpha=0.55,
                   edgecolor=SURFACE, linewidth=0.8, zorder=3)

        slope, intercept = np.polyfit(d["ln_dist"], d[y], 1)
        xs = np.linspace(d["ln_dist"].min(), d["ln_dist"].max(), 50)
        ax.plot(xs, intercept + slope * xs, color=INK, lw=2, zorder=4)
        ax.text(0.03, 0.05, f"Slope = {slope:.2f}", transform=ax.transAxes,
                ha="left", va="bottom", fontsize=12, fontweight="bold", color=INK)

        for code, (name, offset) in LABELS.items():
            row = d[d["j"] == code]
            if not row.empty:
                ax.annotate(name, (row["ln_dist"].iloc[0], row[y].iloc[0]),
                            xytext=offset, textcoords="offset points",
                            fontsize=9, color=INK_2, zorder=5)

        ax.set_title(title, loc="left", fontsize=12.5, color=INK, pad=10)
        ax.set_xlabel("Log distance from the U.S.")
        ax.set_ylabel(ylabel)
        ax.grid(axis="y", color=GRID, lw=0.8)
        ax.set_axisbelow(True)
        for side in ("top", "right"):
            ax.spines[side].set_visible(False)

    fig.suptitle("U.S. trade and distance, 2016: controlling for partner size "
                 "more than triples the distance effect",
                 x=0.01, ha="left", fontsize=13.5, fontweight="bold", color=INK)
    fig.text(0.01, 0.005,
             f"Each point is one U.S. trading partner (n = {len(d)}). Source: author's "
             "calculations from course trade data and Penn World Table 11.0.",
             fontsize=8.5, color=INK_2)
    fig.tight_layout(rect=(0, 0.03, 1, 0.97))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUT, dpi=200, facecolor=SURFACE)
    print(f"Saved {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

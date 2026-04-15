#!/usr/bin/env bash
#SBATCH --job-name=grid_study_3d
#SBATCH --partition=gpu
#SBATCH --gres=gpu:a100:1
#SBATCH --mem=40G
#SBATCH --time=12:00:00
#SBATCH --output=slurm-%j.out
#SBATCH --open-mode=append
#SBATCH --signal=B:USR1@120

# ============================================================================
# GPU CONFIGURATION
# ============================================================================
# GPU_TYPE: "a100" or "v100" — single variable controls everything.
# IMPORTANT: also update the #SBATCH --gres line above to match!
GPU_TYPE="a100"

case "${GPU_TYPE}" in
  a100)  NV_ARCH="Ampere" ;;
  v100)  NV_ARCH="Volta"  ;;
  *)     echo "ERROR: Unknown GPU_TYPE='${GPU_TYPE}'"; exit 1 ;;
esac

# If not running inside SLURM, re-submit with the correct --gres
if [[ -z "${SLURM_JOB_ID:-}" ]]; then
  exec sbatch --gres="gpu:${GPU_TYPE}:1" "$0"
fi

set -euxo pipefail

# Disable output buffering for real-time logging
export PYTHONUNBUFFERED=1

OPS_ROOT="${HOME}/OPS_Benchmark/OPS"
OPS_CORE="${OPS_ROOT}/ops/c"


# Date stamp for unique output folders (to avoid overwriting)
# To resume/append to an existing run, set a fixed stamp: DATE_STAMP="20260101_120000"
DATE_STAMP=$(date +%Y%m%d_%H%M%S)

# Grid configurations for 3D apps (X > Y, X > Z constraint)
# Format: "X:Y:Z:LABEL"
# Based on pre_calc.py output for 100^3, 200^3

# 100^3 = 1,000,000 cells - EXACT factorizations only
# 1,000,000 = 2^6 × 5^6, all X × Y × Z = 1,000,000 exactly
# Constraint: X >= Y >= Z
# COMMENTED OUT - 100^3 configurations disabled
# GRIDS_100=(
#   # Group 1: X = 100-125 (most balanced)
#   "100:100:100:100^3_cfg1"
#   "125:100:80:100^3_cfg2"
#   "125:80:100:100^3_cfg3"
#   # Group 2: X = 160-200
#   "160:125:50:100^3_cfg4"
#   "200:100:50:100^3_cfg5"
#   "200:125:40:100^3_cfg6"
#   "200:50:100:100^3_cfg7"
#   # Group 3: X = 250
#   "250:100:40:100^3_cfg8"
#   "250:80:50:100^3_cfg9"
#   "250:50:80:100^3_cfg10"
#   # Group 4: X = 250 (cont)
#   "250:40:100:100^3_cfg11"
#   "250:125:32:100^3_cfg12"
#   "250:200:20:100^3_cfg13"
#   # Group 4: X = 320-400
#   "320:125:25:100^3_cfg14"
#   "400:100:25:100^3_cfg15"
#   "400:50:50:100^3_cfg16"
#   "400:125:20:100^3_cfg17"
#   "400:25:100:100^3_cfg18"
#   # Group 5: X = 500
#   "500:100:20:100^3_cfg19"
#   "500:80:25:100^3_cfg20"
#   "500:50:40:100^3_cfg21"
#   "500:40:50:100^3_cfg22"
#   "500:25:80:100^3_cfg23"
#   "500:20:100:100^3_cfg24"
#   "500:125:16:100^3_cfg25"
#   "500:200:10:100^3_cfg26"
#   # Group 6: X = 625
#   "625:100:16:100^3_cfg27"
#   "625:80:20:100^3_cfg28"
#   "625:64:25:100^3_cfg29"
#   "625:50:32:100^3_cfg30"
#   "625:40:40:100^3_cfg31"
#   "625:32:50:100^3_cfg32"
#   "625:25:64:100^3_cfg33"
#   "625:20:80:100^3_cfg34"
#   "625:16:100:100^3_cfg35"
#   # Group 7: X = 800
#   "800:125:10:100^3_cfg36"
#   "800:50:25:100^3_cfg37"
#   "800:25:50:100^3_cfg38"
#   # Group 8: X = 1000
#   "1000:100:10:100^3_cfg39"
#   "1000:50:20:100^3_cfg40"
#   "1000:40:25:100^3_cfg41"
#   "1000:25:40:100^3_cfg42"
#   "1000:20:50:100^3_cfg43"
#   "1000:125:8:100^3_cfg44"
#   # Group 9: X = 1250
#   "1250:100:8:100^3_cfg45"
#   "1250:80:10:100^3_cfg46"
#   "1250:50:16:100^3_cfg47"
#   "1250:40:20:100^3_cfg48"
#   "1250:32:25:100^3_cfg49"
#   "1250:25:32:100^3_cfg50"
#   "1250:20:40:100^3_cfg51"
#   "1250:16:50:100^3_cfg52"
#   # Group 10: X = 1600
#   "1600:125:5:100^3_cfg53"
#   "1600:25:25:100^3_cfg54"
#   # Group 11: X = 2000
#   "2000:50:10:100^3_cfg55"
#   "2000:25:20:100^3_cfg56"
#   "2000:20:25:100^3_cfg57"
#   "2000:100:5:100^3_cfg58"
#   # Group 12: X = 2500
#   "2500:50:8:100^3_cfg59"
#   "2500:40:10:100^3_cfg60"
#   "2500:25:16:100^3_cfg61"
#   "2500:20:20:100^3_cfg62"
#   "2500:16:25:100^3_cfg63"
#   # Group 13: X = 3125
#   "3125:40:8:100^3_cfg64"
#   "3125:32:10:100^3_cfg65"
#   "3125:20:16:100^3_cfg66"
#   "3125:16:20:100^3_cfg67"
#   # Group 14: X = 4000-5000
#   "4000:25:10:100^3_cfg68"
#   "4000:50:5:100^3_cfg69"
#   "5000:25:8:100^3_cfg70"
#   "5000:20:10:100^3_cfg71"
#   "5000:40:5:100^3_cfg72"
#   # Group 15: X = 6250+
#   "6250:20:8:100^3_cfg73"
#   "6250:16:10:100^3_cfg74"
#   "8000:25:5:100^3_cfg75"
#   "10000:20:5:100^3_cfg76"
#   "10000:10:10:100^3_cfg77"
#   "12500:16:5:100^3_cfg78"
#   "12500:10:8:100^3_cfg79"
#   "15625:16:4:100^3_cfg80"
# )
GRIDS_100=()

# 200^3 = 8,000,000 cells - EXACT factorizations only
# 8,000,000 = 2^9 × 5^6, all X × Y × Z = 8,000,000 exactly
#
# === 231-class distribution ===
# All configs have X>=1024 AND Y>=1024 to guarantee all 231 (bx,by,bz) classes
# Total 3D: 4 + 14 + 14 = 32 grids × 5 apps = 160
# Total 2D: 30 grids × 3 apps = 90
# Grand total: 160 + 90 = 250 configurations
#
# Old configs (X<1024 or Y<1024, only 217/231 classes):
# "200:200:200:200^3_cfg1"
# "250:200:160:200^3_cfg2"
# "250:160:200:200^3_cfg3"
# "320:250:100:200^3_cfg4"
# "320:200:125:200^3_cfg5"
# "320:125:200:200^3_cfg6"
# "320:100:250:200^3_cfg7"
# "400:200:100:200^3_cfg8"
# "400:250:80:200^3_cfg9"
# "400:160:125:200^3_cfg10"
# GRIDS_200=(
#   # All 4 valid factorizations with X>=1024, Y>=1024 (Z=4-5)
#   "1250:1280:5:200^3_cfg1"
#   "1280:1250:5:200^3_cfg2"
#   "1250:1600:4:200^3_cfg3"
#   "1600:1250:4:200^3_cfg4"
# )
GRIDS_200=()

# 300^3 = 27,000,000 cells - EXACT factorizations only
# 27,000,000 = 2^3 × 3^3 × 5^6, all X × Y × Z = 27,000,000 exactly
# All configs have X>=1024 AND Y>=1024 to guarantee all 231 (bx,by,bz) classes
# Distribution: 14 configs (sorted by Z descending, varied ratio_xy)
#
# Old configs (X<1024 or Y<1024, only 223/231 classes):
# "300:300:300:300^3_cfg1"
# "375:300:240:300^3_cfg2"
# "400:300:225:300^3_cfg3"
# "360:300:250:300^3_cfg4"
# "375:240:300:300^3_cfg5"
# "450:300:200:300^3_cfg6"
# "450:400:150:300^3_cfg7"
# "450:200:300:300^3_cfg8"
# "450:250:240:300^3_cfg9"
# "450:240:250:300^3_cfg10"
# GRIDS_300=(
#   # Z=20 (largest Z available)
#   "1125:1200:20:300^3_cfg1"
#   "1200:1125:20:300^3_cfg2"
#   "1080:1250:20:300^3_cfg3"
#   "1250:1080:20:300^3_cfg4"
#   # Z=18
#   "1200:1250:18:300^3_cfg5"
#   "1250:1200:18:300^3_cfg6"
#   # Z=16
#   "1250:1350:16:300^3_cfg7"
#   "1350:1250:16:300^3_cfg8"
#   "1125:1500:16:300^3_cfg9"
#   "1500:1125:16:300^3_cfg10"
#   # Z=15 (varied ratios)
#   "1250:1440:15:300^3_cfg11"
#   "1440:1250:15:300^3_cfg12"
#   "1200:1500:15:300^3_cfg13"
#   "1500:1200:15:300^3_cfg14"
# )
GRIDS_300=()

# 400^3 = 64,000,000 cells - EXACT factorizations only
# 64,000,000 = 2^12 × 5^6, all X × Y × Z = 64,000,000 exactly
# All configs have X>=1024 AND Y>=1024 to guarantee all 231 (bx,by,bz) classes
# Distribution: 14 configs (sorted by Z descending, varied ratio_xy)
#
# Old configs (X<1024 or Y<1024, only 226/231 classes):
# "400:400:400:400^3_cfg1"
# "500:400:320:400^3_cfg2"
# "500:320:400:400^3_cfg3"
# "512:400:312:400^3_cfg4"
# "512:320:390:400^3_cfg5"
# "640:400:250:400^3_cfg6"
# "640:500:200:400^3_cfg7"
# "640:320:312:400^3_cfg8"
# "640:250:400:400^3_cfg9"
# "640:200:500:400^3_cfg10"
# GRIDS_400=(
#   # Z=50
#   "1024:1250:50:400^3_cfg1"
#   "1250:1024:50:400^3_cfg2"
#   # Z=40
#   "1250:1280:40:400^3_cfg3"
#   "1280:1250:40:400^3_cfg4"
#   # Z=32
#   "1250:1600:32:400^3_cfg5"
#   "1600:1250:32:400^3_cfg6"
#   # Z=25 (varied ratios)
#   "1600:1600:25:400^3_cfg7"
#   "1280:2000:25:400^3_cfg8"
#   "2000:1280:25:400^3_cfg9"
#   "1024:2500:25:400^3_cfg10"
#   # Z=20
#   "1600:2000:20:400^3_cfg11"
#   "2000:1600:20:400^3_cfg12"
#   "1280:2500:20:400^3_cfg13"
#   "2500:1280:20:400^3_cfg14"
  # "800:400:200:400^3_cfg11"
  # "800:500:160:400^3_cfg12"
  # "800:320:250:400^3_cfg13"
  # "800:256:312:400^3_cfg14"
  # "800:200:400:400^3_cfg15"
  # "800:160:500:400^3_cfg16"
  # "800:250:320:400^3_cfg17"
  # "1000:400:160:400^3_cfg18"
  # "1000:500:128:400^3_cfg19"
  # "1000:640:100:400^3_cfg20"
  # "1000:320:200:400^3_cfg21"
  # "1000:256:250:400^3_cfg22"
  # "1000:200:320:400^3_cfg23"
  # "1000:160:400:400^3_cfg24"
  # "1000:128:500:400^3_cfg25"
  # "1250:400:128:400^3_cfg26"
  # "1250:512:100:400^3_cfg27"
  # "1250:320:160:400^3_cfg28"
  # "1250:256:200:400^3_cfg29"
  # "1250:200:256:400^3_cfg30"
  # "1250:160:320:400^3_cfg31"
  # "1250:128:400:400^3_cfg32"
  # "1600:400:100:400^3_cfg33"
  # "1600:500:80:400^3_cfg34"
  # "1600:320:125:400^3_cfg35"
  # "1600:250:160:400^3_cfg36"
  # "1600:200:200:400^3_cfg37"
  # "1600:160:250:400^3_cfg38"
  # "1600:125:320:400^3_cfg39"
  # "1600:100:400:400^3_cfg40"
  # "2000:400:80:400^3_cfg41"
  # "2000:500:64:400^3_cfg42"
  # "2000:320:100:400^3_cfg43"
  # "2000:256:125:400^3_cfg44"
  # "2000:200:160:400^3_cfg45"
  # "2000:160:200:400^3_cfg46"
  # "2000:128:250:400^3_cfg47"
  # "2000:100:320:400^3_cfg48"
  # "2000:80:400:400^3_cfg49"
  # "2500:400:64:400^3_cfg50"
  # "2500:512:50:400^3_cfg51"
  # "2500:320:80:400^3_cfg52"
  # "2500:256:100:400^3_cfg53"
  # "2500:200:128:400^3_cfg54"
  # "2500:160:160:400^3_cfg55"
  # "2500:128:200:400^3_cfg56"
  # "2500:100:256:400^3_cfg57"
  # "2500:80:320:400^3_cfg58"
  # "3200:400:50:400^3_cfg59"
  # "3200:500:40:400^3_cfg60"
  # "3200:250:80:400^3_cfg61"
  # "3200:200:100:400^3_cfg62"
  # "3200:160:125:400^3_cfg63"
  # "3200:125:160:400^3_cfg64"
  # "3200:100:200:400^3_cfg65"
  # "3200:80:250:400^3_cfg66"
  # "4000:400:40:400^3_cfg67"
  # "4000:500:32:400^3_cfg68"
  # "4000:320:50:400^3_cfg69"
  # "4000:256:62:400^3_cfg70"
  # "4000:200:80:400^3_cfg71"
  # "4000:160:100:400^3_cfg72"
  # "4000:128:125:400^3_cfg73"
  # "4000:100:160:400^3_cfg74"
  # "4000:80:200:400^3_cfg75"
  # "5000:400:32:400^3_cfg76"
  # "5000:512:25:400^3_cfg77"
  # "5000:320:40:400^3_cfg78"
  # "5000:256:50:400^3_cfg79"
  # "5000:200:64:400^3_cfg80"
  # "5000:160:80:400^3_cfg81"
  # "5000:128:100:400^3_cfg82"
  # "5000:100:128:400^3_cfg83"
  # "5000:80:160:400^3_cfg84"
  # "6250:400:25:400^3_cfg85"
  # "6250:320:32:400^3_cfg86"
  # "6250:256:40:400^3_cfg87"
  # "6250:200:51:400^3_cfg88"
  # "6250:160:64:400^3_cfg89"
  # "6250:128:80:400^3_cfg90"
  # "8000:400:20:400^3_cfg91"
  # "8000:500:16:400^3_cfg92"
  # "8000:320:25:400^3_cfg93"
  # "8000:250:32:400^3_cfg94"
  # "8000:200:40:400^3_cfg95"
  # "8000:160:50:400^3_cfg96"
  # "10000:400:16:400^3_cfg97"
  # "10000:320:20:400^3_cfg98"
  # "10000:256:25:400^3_cfg99"
  # "12500:320:16:400^3_cfg100"
# )
GRIDS_400=()

# 420^3 = 74,088,000 cells - EXACT factorizations only
# 74,088,000 = 2^3 × 3^3 × 5^3 × 7^3, all X × Y × Z = 74,088,000 exactly
# ALL configs have X>=1024, Y>=1024, Z>=64 to GUARANTEE all 231 (bx,by,bz) classes
# Minimum viable problem size for 231 classes
GRIDS_420=(
  # Z=64
  "1029:1125:64:420^3_cfg1"
  "1125:1029:64:420^3_cfg2"
)

# 450^3 = 91,125,000 cells - EXACT factorizations only
# 91,125,000 = 2^2 × 3^6 × 5^6, all X × Y × Z = 91,125,000 exactly
# ALL configs have X>=1024, Y>=1024, Z>=64 to GUARANTEE all 231 (bx,by,bz) classes
GRIDS_450=(
  # Z=72
  "1125:1125:72:450^3_cfg1"
  # Z=75
  "1080:1125:75:450^3_cfg2"
  "1125:1080:75:450^3_cfg3"
)

# ============================================================================
# 2D GRID CONFIGURATIONS (for lattboltz2d, laplace2d)
# Format: "X:Y:1:LABEL" — Z=1 for 2D apps, x*y ≈ equivalent 3D cell count
# Distribution: 30 configs (10 per size) × 3 apps = 90
# 2D apps already reach 51/51 (100%) possible (bx,by) classes — no XL needed
# ============================================================================

# 2D grids matching 100^3 = 1,000,000 cells
# COMMENTED OUT - 100^3 2D configurations disabled
# GRIDS_2D_100=(
#   "1000:1000:1:100^3_2d_cfg1"     # 1.00M  1:1
#   "1250:800:1:100^3_2d_cfg2"      # 1.00M  1.56:1
#   "800:1250:1:100^3_2d_cfg3"      # 1.00M  0.64:1
#   "1600:625:1:100^3_2d_cfg4"      # 1.00M  2.56:1
#   "2000:500:1:100^3_2d_cfg5"      # 1.00M  4:1
#   "500:2000:1:100^3_2d_cfg6"      # 1.00M  0.25:1
#   "2500:400:1:100^3_2d_cfg7"      # 1.00M  6.25:1
#   "400:2500:1:100^3_2d_cfg8"      # 1.00M  0.16:1
#   "3125:320:1:100^3_2d_cfg9"      # 1.00M  9.77:1
#   "625:1600:1:100^3_2d_cfg10"     # 1.00M  0.39:1
# )
GRIDS_2D_100=()

# 2D grids matching 200^3 = 8,000,000 cells
GRIDS_2D_200=(
  "2828:2828:1:200^3_2d_cfg1"     # 8.00M  1:1
  "3536:2263:1:200^3_2d_cfg2"     # 8.00M  1.56:1
  "2263:3536:1:200^3_2d_cfg3"     # 8.00M  0.64:1
  "4000:2000:1:200^3_2d_cfg4"     # 8.00M  2:1
  "2000:4000:1:200^3_2d_cfg10"    # 8.00M  0.5:1
  "3200:2500:1:200^3_2d_cfg5"     # 8.00M  1.28:1
  "2500:3200:1:200^3_2d_cfg6"     # 8.00M  0.78:1
  "3810:2100:1:200^3_2d_cfg7"     # 8.00M  1.81:1
  "2100:3810:1:200^3_2d_cfg8"     # 8.00M  0.55:1
  "1600:5000:1:200^3_2d_cfg9"     # 8.00M  0.32:1
)

# 2D grids matching 300^3 = 27,000,000 cells
GRIDS_2D_300=(
  "5196:5196:1:300^3_2d_cfg1"     # 27.0M  1:1
  "6495:4157:1:300^3_2d_cfg2"     # 27.0M  1.56:1
  "4157:6495:1:300^3_2d_cfg3"     # 27.0M  0.64:1
  "7348:3674:1:300^3_2d_cfg4"     # 27.0M  2:1
  "9000:3000:1:300^3_2d_cfg5"     # 27.0M  3:1
  "3000:9000:1:300^3_2d_cfg6"     # 27.0M  0.33:1
  "10392:2598:1:300^3_2d_cfg7"    # 27.0M  4:1
  "2598:10392:1:300^3_2d_cfg8"    # 27.0M  0.25:1
  "13500:2000:1:300^3_2d_cfg9"    # 27.0M  6.75:1
  "3674:7348:1:300^3_2d_cfg10"    # 27.0M  0.5:1
)

# 2D grids matching 400^3 = 64,000,000 cells
GRIDS_2D_400=(
  "8000:8000:1:400^3_2d_cfg1"     # 64.0M  1:1
  "10000:6400:1:400^3_2d_cfg2"    # 64.0M  1.56:1
  "6400:10000:1:400^3_2d_cfg3"    # 64.0M  0.64:1
  "11314:5657:1:400^3_2d_cfg4"    # 64.0M  2:1
  "16000:4000:1:400^3_2d_cfg5"    # 64.0M  4:1
  "4000:16000:1:400^3_2d_cfg6"    # 64.0M  0.25:1
  "20000:3200:1:400^3_2d_cfg7"    # 64.0M  6.25:1
  "3200:20000:1:400^3_2d_cfg8"    # 64.0M  0.16:1
  "12800:5000:1:400^3_2d_cfg9"    # 64.0M  2.56:1
  "5000:12800:1:400^3_2d_cfg10"   # 64.0M  0.39:1
)

# CloverLeaf 3D settings
CLOVER_DIR="${OPS_ROOT}/apps/c/CloverLeaf_3D"
CLOVER_END_STEP=220

# CloverLeaf 2D settings
CLOVER2D_DIR="${OPS_ROOT}/apps/c/CloverLeaf"
CLOVER2D_END_STEP=300

# TTI settings
TTI_DIR="${OPS_ROOT}/apps/c/tti"

# Maxwell FDTD settings
MAXWELL_DIR="${OPS_ROOT}/apps/c/maxwell_fdtd"
MAXWELL_TIMESTEPS=4000

# LBM (Lattice Boltzmann) settings - 2D app
LBM_DIR="${OPS_ROOT}/apps/c/ops-lbm/step5"
LBM_ITERATIONS=400

# Laplace2D settings - 2D app
LAPLACE2D_DIR="${OPS_ROOT}/apps/c/laplace2d_tutorial/step7"
LAPLACE2D_ITERATIONS=400

# OpenSBLI TGsym_DP settings - 3D app (grid hardcoded: mult*512+1 x 513 x 513)
OPENSBLI_DIR="${OPS_ROOT}/apps/c/TGsym_DP"

# TGV StoreNone settings - 3D app (takes grid_x grid_y grid_z as args)
TGV_DIR="${OPS_ROOT}/apps/c/TGV_StoreNone"

# TGV StoreAll settings - 3D app (takes grid_x grid_y grid_z as args)
TGVSA_DIR="${OPS_ROOT}/apps/c/TGV_StoreAll"


# Set OPS_AUTOTUNE_BX_PRIORITY=1 to require bx >= by (and bx >= bz in 3D), 0 for all candidates
export OPS_AUTOTUNE_BX_PRIORITY=0

# Base directory for precomputed block sizes (mode=2)
# Change this to the directory containing logs with ops_blocksize_best_logmod.csv
OPS_BLOCKSIZE_BASE="${HOME}/OPS_LOGS_PRECOMPUTED"


# ============================================================================
# RUN APPS CONFIGURATION
# ============================================================================
# Set which apps to run (comma-separated): any combination of the apps below
# RUN_APPS="cloverleaf,cloverleaf2d,tti,maxwell,lattboltz2d,laplace2d,opensbli,tgvstorenone,tgvstoreall"
# RUN_APPS="cloverleaf,cloverleaf2d,tti,maxwell,lattboltz2d,laplace2d,tgvstorenone,tgvstoreall"
RUN_APPS="cloverleaf"
# # RUN_APPS="cloverleaf2d,lattboltz2d,laplace2d"
# RUN_APPS="cloverleaf,tti,maxwell,opensbli,tgvstorenone,tgvstoreall"
# RUN_APPS="tgvstorenone,cloverleaf,maxwell,lattboltz2d,laplace2d"
# RUN_APPS="tgvstoreall"

# ============================================================================
# RUN MODES CONFIGURATION
# ============================================================================F
# Set which modes to run (comma-separated): 0,1,2 or any combination
# Mode 0: Default blocks (no tuning)
# Mode 1: Dynamic autotuning
# Mode 2: Precomputed blocks from CSV
RUN_MODES="0,1"

# Persistent log file (appends, never overwrites)
PERSISTENT_LOG="${HOME}/OPS_AUTO/auto_grid_history.log"  # Appends all output for history

echo ""
echo "========================================================================"
echo "  NEW JOB STARTED - SLURM_JOB_ID: ${SLURM_JOB_ID:-local}"
echo "  Date: $(date)"
echo "  RUN_MODES: ${RUN_MODES}"
echo "  OPS_BLOCKSIZE_BASE: ${OPS_BLOCKSIZE_BASE}"
echo "========================================================================"

# Append all output to persistent log file (keeps full history)
exec > >(tee -a "${PERSISTENT_LOG}") 2>&1

run_cmd() {
  echo "+ $*"
  eval "$@"
}


generate_clover_in() {
  local app_dir="$1"
  local x_cells="$2"
  local y_cells="$3"
  local z_cells="$4"
  cat > "${app_dir}/clover.in" << EOF
*clover
 state 1 density=0.2 energy=1.0
 state 2 density=1.0 energy=2.5 geometry=cuboid xmin=0.0 xmax=5.0 ymin=0.0 ymax=2.0 zmin=0.0 zmax=2.0
 x_cells=${x_cells}
 y_cells=${y_cells}
 z_cells=${z_cells}
 xmin=0.0
 ymin=0.0
 zmin=0.0
 xmax=10.0
 ymax=2.0
 zmax=2.0
 initial_timestep=0.04
 max_timestep=0.04
 end_step=${CLOVER_END_STEP}
 test_problem 1
 checkpoint_frequency=1000000
 profiler_on=1
*endclover
EOF
  echo "  >> Generated clover.in: ${x_cells} x ${y_cells} x ${z_cells}, end_step=${CLOVER_END_STEP}"
}

generate_clover2d_in() {
  local app_dir="$1"
  local x_cells="$2"
  local y_cells="$3"
  cat > "${app_dir}/clover.in" << EOF
*clover
 state 1 density=0.2 energy=1.0
 state 2 density=1.0 energy=2.5 geometry=rectangle xmin=0.0 xmax=5.0 ymin=0.0 ymax=2.0
 x_cells=${x_cells}
 y_cells=${y_cells}
 xmin=0.0
 ymin=0.0
 xmax=10.0
 ymax=10.0
 initial_timestep=0.04
 timestep_rise=1.5
 max_timestep=0.04
 end_time=15.5
 end_step=${CLOVER2D_END_STEP}
 test_problem 3
 profiler_on=1
*endclover
EOF
  echo "  >> Generated clover.in (2D): ${x_cells} x ${y_cells}, end_step=${CLOVER2D_END_STEP}"
}


# ============================================================================
# REAL GPU MODE: Build and run applications
# ============================================================================
echo "==== [OPS] Rebuilding core library ===="
run_cmd "cd \"${OPS_CORE}\" && make clean && make -j NV_ARCH=${NV_ARCH}"

if [[ ",${RUN_APPS}," == *",cloverleaf,"* ]]; then
  echo "==== Building CloverLeaf 3D ===="
  run_cmd "cd \"${CLOVER_DIR}\" && make clean && make cloverleaf_cuda  NV_ARCH=${NV_ARCH}"
fi

if [[ ",${RUN_APPS}," == *",cloverleaf2d,"* ]]; then
  echo "==== Building CloverLeaf 2D ===="
  run_cmd "cd \"${CLOVER2D_DIR}\" && make clean && make cloverleaf_cuda  NV_ARCH=${NV_ARCH}"
  ln -sf cloverleaf_cuda "${CLOVER2D_DIR}/cloverleaf2d_cuda"
fi

if [[ ",${RUN_APPS}," == *",tti,"* ]]; then
  echo "==== Building TTI ===="
  run_cmd "cd \"${TTI_DIR}\" && make clean && make tti_cuda  NV_ARCH=${NV_ARCH}"
fi

if [[ ",${RUN_APPS}," == *",maxwell,"* ]]; then
  echo "==== Building Maxwell FDTD ===="
  run_cmd "cd \"${MAXWELL_DIR}\" && make clean && make maxwell_cuda  NV_ARCH=${NV_ARCH}"
fi

if [[ ",${RUN_APPS}," == *",lattboltz2d,"* ]]; then
  echo "==== Building LBM (Lattice Boltzmann) ===="
  run_cmd "cd \"${LBM_DIR}\" && make clean && make lattboltz2d_cuda  NV_ARCH=${NV_ARCH}"
fi

if [[ ",${RUN_APPS}," == *",laplace2d,"* ]]; then
  echo "==== Building Laplace2D ===="
  run_cmd "cd \"${LAPLACE2D_DIR}\" && make clean && make laplace2d_cuda  NV_ARCH=${NV_ARCH}"
fi

if [[ ",${RUN_APPS}," == *",opensbli,"* ]]; then
  echo "==== Building OpenSBLI TGsym_DP ===="
  run_cmd "cd \"${OPENSBLI_DIR}\" && make clean && make opensbli_cuda  NV_ARCH=${NV_ARCH}"
fi

if [[ ",${RUN_APPS}," == *",tgvstorenone,"* ]]; then
  echo "==== Building TGV StoreNone ===="
  run_cmd "cd \"${TGV_DIR}\" && make clean && make opensbli_cuda  NV_ARCH=${NV_ARCH}"
  ln -sf opensbli_cuda "${TGV_DIR}/tgvstorenone_cuda"
fi

if [[ ",${RUN_APPS}," == *",tgvstoreall,"* ]]; then
  echo "==== Building TGV StoreAll ===="
  run_cmd "cd \"${TGVSA_DIR}\" && make clean && make opensbli_cuda  NV_ARCH=${NV_ARCH}"
  ln -sf opensbli_cuda "${TGVSA_DIR}/tgvstoreall_cuda"
fi

echo
echo "========================================================================"
echo "  GRID STUDY: Running 3D apps with multiple grid configurations"
echo "  Constraint: X > Y, X > Z (same total cells per group)"
echo "  Output folder suffix: ${DATE_STAMP}"
echo "========================================================================"

# Function to run app with grid config (follows auto.sh pattern)
run_grid_config() {
  local app_name="$1"
  local app_dir="$2"
  local grid_x="$3"
  local grid_y="$4"
  local grid_z="$5"
  local label="$6"

  # Skip if app is not in RUN_APPS
  if [[ ",${RUN_APPS}," != *",${app_name},"* ]]; then
    return
  fi


  local total_cells=$((grid_x * grid_y * grid_z))
  
  # OPS_LOGS folder with date stamp: {app}_cuda_{label}_{date}/autotune_on, autotune_off
  local LOG_DIR_BASE="${HOME}/OPS_Benchmark/OPS_LOGS/${app_name}_cuda_${label}_${DATE_STAMP}"
  
  echo
  echo "================================================================="
  echo "  ${app_name} - ${label}"
  echo "  Grid: ${grid_x} x ${grid_y} x ${grid_z} = ${total_cells} cells"
  echo "  Logs: ${LOG_DIR_BASE}"
  echo "================================================================="
  
  # Generate config file for CloverLeaf
  if [[ "${app_name}" == "cloverleaf" ]]; then
    generate_clover_in "${app_dir}" "${grid_x}" "${grid_y}" "${grid_z}"
  elif [[ "${app_name}" == "cloverleaf2d" ]]; then
    generate_clover2d_in "${app_dir}" "${grid_x}" "${grid_y}"
  fi
  
  # Build app args
  local APP_ARGS=""
  if [[ "${app_name}" == "tti" ]]; then
    APP_ARGS="${grid_x} ${grid_y} ${grid_z}"
  elif [[ "${app_name}" == "maxwell" ]]; then
    APP_ARGS="${grid_x} ${grid_y} ${grid_z} ${MAXWELL_TIMESTEPS}"
  elif [[ "${app_name}" == "lattboltz2d" ]]; then
    APP_ARGS="-nx=${grid_x} -ny=${grid_y} -iter=${LBM_ITERATIONS}"
  elif [[ "${app_name}" == "laplace2d" ]]; then
    APP_ARGS="-imax=${grid_x} -jmax=${grid_y} -iter=${LAPLACE2D_ITERATIONS}"
  elif [[ "${app_name}" == "opensbli" ]]; then
    APP_ARGS=""
  elif [[ "${app_name}" == "tgvstorenone" ]]; then
    APP_ARGS="${grid_x} ${grid_y} ${grid_z}"
  elif [[ "${app_name}" == "tgvstoreall" ]]; then
    APP_ARGS="${grid_x} ${grid_y} ${grid_z}"
  fi
  
  # Create log directories for each mode
  local AUTOTUNE_LOG_DIR="${LOG_DIR_BASE}/autotune_on"
  local NO_AUTOTUNE_LOG_DIR="${LOG_DIR_BASE}/autotune_off"
  mkdir -p "${AUTOTUNE_LOG_DIR}"
  mkdir -p "${NO_AUTOTUNE_LOG_DIR}"
  
  # Determine iterations based on app
  local iterations="N/A"
  if [[ "${app_name}" == "cloverleaf" ]]; then
    iterations="${CLOVER_END_STEP}"
  elif [[ "${app_name}" == "cloverleaf2d" ]]; then
    iterations="${CLOVER2D_END_STEP}"
  elif [[ "${app_name}" == "lattboltz2d" ]]; then
    iterations="${LBM_ITERATIONS}"
  elif [[ "${app_name}" == "laplace2d" ]]; then
    iterations="${LAPLACE2D_ITERATIONS}"
  fi
  
  # Create config.txt only if it doesn't exist (to preserve existing data)
  local CONFIG_FILE="${LOG_DIR_BASE}/config.txt"
  if [[ ! -f "${CONFIG_FILE}" ]]; then
    cat > "${CONFIG_FILE}" << CONFIG_EOF
# OPS Grid Study Configuration
# Generated: $(date)

APP_NAME=${app_name}
GRID_X=${grid_x}
GRID_Y=${grid_y}
GRID_Z=${grid_z}
GRID_SIZE=${grid_x} x ${grid_y} x ${grid_z}
TOTAL_CELLS=${total_cells}
LABEL=${label}
ITERATIONS=${iterations}
DATE_STAMP=${DATE_STAMP}

# Wall times will be appended after execution
CONFIG_EOF
  fi

  # Create temporary script to run all modes in a single GPU allocation (same as auto.sh)
  RUN_SCRIPT_FILE="${app_dir}/run_modes.sh"
  cat > "${RUN_SCRIPT_FILE}" << SCRIPT_HEADER
#!/bin/bash
set -e

# Helper: wait for GPU memory to be released between runs
gpu_sync() {
  sync
  sleep 3
}
SCRIPT_HEADER

  # Set OPS_LOGS_DIR to write CSVs directly to our date-stamped directory
  # OPS will create {app}_cuda/autotune_on and autotune_off inside this directory
  cat >> "${RUN_SCRIPT_FILE}" << SCRIPT_BODY
# Set OPS_LOGS_DIR so OPS writes CSVs to our date-stamped directory
export OPS_LOGS_DIR="${LOG_DIR_BASE}"
CONFIG_FILE="${CONFIG_FILE}"
RUN_MODES="${RUN_MODES}"

# Mode 0: Default blocks (no tuning)
if [[ "\${RUN_MODES}" == *"0"* ]]; then
  echo ""
  echo "###################################################################"
  echo "# [MODE 0] DEFAULT BLOCKS - ${app_name} - ${label}"
  echo "# Started: \$(date)"
  echo "###################################################################"
  export OPS_AUTOTUNE_LOGS=0
  echo "  >> Running ${app_name}_cuda | mode=0 | grid=${grid_x}x${grid_y}x${grid_z} | args: ${APP_ARGS}"
  OUTPUT_NO_AUTOTUNE=\$(./${app_name}_cuda ${APP_ARGS} -OPS_DIAGS=2 -OPS_AUTOTUNE_MODE=0 2>&1 | tee /dev/stderr)
  WALL_TIME_NO_AUTOTUNE=\$(echo "\${OUTPUT_NO_AUTOTUNE}" | grep -oP 'Total Wall time \K[\d.]+' | tail -1)
  echo "WALL_TIME_NO_AUTOTUNE=\${WALL_TIME_NO_AUTOTUNE}" >> "\${CONFIG_FILE}"
  echo "# [MODE 0] Completed: \$(date) - Wall time: \${WALL_TIME_NO_AUTOTUNE}s"
else
  echo "---- Mode 0: SKIPPED ----"
fi
gpu_sync

# Mode 2: Precomputed blocks from CSV
if [[ "\${RUN_MODES}" == *"2"* ]]; then
  echo ""
  echo "###################################################################"
  echo "# [MODE 2] PRECOMPUTED BLOCKS - ${app_name} - ${label}"
  echo "# Started: \$(date)"
  echo "###################################################################"
  BLOCKSIZE_CSV_PATTERN_BEST="${OPS_BLOCKSIZE_BASE}/${app_name}_cuda_${label}_*/autotune_on/ops_blocksize_best_logmod.csv"
  BLOCKSIZE_CSV_PATTERN_TUNING="${OPS_BLOCKSIZE_BASE}/${app_name}_cuda_${label}_*/autotune_on/ops_blocksize_tuning_logmod.csv"
  BLOCKSIZE_CSV_FOUND=\$(ls \${BLOCKSIZE_CSV_PATTERN_BEST} 2>/dev/null | head -1)
  if [[ -z "\${BLOCKSIZE_CSV_FOUND}" ]]; then
    BLOCKSIZE_CSV_FOUND=\$(ls \${BLOCKSIZE_CSV_PATTERN_TUNING} 2>/dev/null | head -1)
  fi
  if [[ -n "\${BLOCKSIZE_CSV_FOUND}" ]]; then
    export OPS_BLOCKSIZE_CSV="\${BLOCKSIZE_CSV_FOUND}"
    echo "  >> Using precomputed blocks from: \${OPS_BLOCKSIZE_CSV}"
    OUTPUT_PRECOMPUTED=\$(./${app_name}_cuda ${APP_ARGS} -OPS_DIAGS=2 -OPS_AUTOTUNE_MODE=2 2>&1 | tee /dev/stderr)
    WALL_TIME_PRECOMPUTED=\$(echo "\${OUTPUT_PRECOMPUTED}" | grep -oP 'Total Wall time \K[\d.]+' | tail -1)
    echo "WALL_TIME_PRECOMPUTED=\${WALL_TIME_PRECOMPUTED}" >> "\${CONFIG_FILE}"
    echo "# [MODE 2] Completed: \$(date) - Wall time: \${WALL_TIME_PRECOMPUTED}s"
    unset OPS_BLOCKSIZE_CSV
  else
    echo "  >> WARNING: No precomputed CSV found for ${app_name}_cuda_${label}"
    echo "WALL_TIME_PRECOMPUTED=N/A" >> "\${CONFIG_FILE}"
  fi
else
  echo "---- Mode 2: SKIPPED ----"
fi
gpu_sync

# Mode 1: Dynamic autotuning
if [[ "\${RUN_MODES}" == *"1"* ]]; then
  echo ""
  echo "###################################################################"
  echo "# [MODE 1] DYNAMIC AUTOTUNING - ${app_name} - ${label}"
  echo "# Started: \$(date)"
  echo "###################################################################"
  export OPS_AUTOTUNE_LOGS=1
  echo "  >> Running ${app_name}_cuda | mode=1 | grid=${grid_x}x${grid_y}x${grid_z} | args: ${APP_ARGS}"
  OUTPUT_AUTOTUNE=\$(./${app_name}_cuda ${APP_ARGS} -OPS_DIAGS=2 -OPS_AUTOTUNE_MODE=1 2>&1 | tee /dev/stderr)
  WALL_TIME_AUTOTUNE=\$(echo "\${OUTPUT_AUTOTUNE}" | grep -oP 'Total Wall time \K[\d.]+' | tail -1)
  echo "WALL_TIME_AUTOTUNE=\${WALL_TIME_AUTOTUNE}" >> "\${CONFIG_FILE}"
  echo "# [MODE 1] Completed: \$(date) - Wall time: \${WALL_TIME_AUTOTUNE}s"
else
  echo "---- Mode 1: SKIPPED ----"
fi
gpu_sync


# Calculate speedups
if [[ -n "\${WALL_TIME_NO_AUTOTUNE:-}" && -n "\${WALL_TIME_PRECOMPUTED:-}" && "\${WALL_TIME_PRECOMPUTED}" != "N/A" ]]; then
  SPEEDUP_PRECOMPUTED=\$(echo "scale=4; \${WALL_TIME_NO_AUTOTUNE} / \${WALL_TIME_PRECOMPUTED}" | bc)
  echo "SPEEDUP_PRECOMPUTED=\${SPEEDUP_PRECOMPUTED}" >> "\${CONFIG_FILE}"
fi
if [[ -n "\${WALL_TIME_NO_AUTOTUNE:-}" && -n "\${WALL_TIME_AUTOTUNE:-}" ]]; then
  SPEEDUP_AUTOTUNE=\$(echo "scale=4; \${WALL_TIME_NO_AUTOTUNE} / \${WALL_TIME_AUTOTUNE}" | bc)
  echo "SPEEDUP_AUTOTUNE=\${SPEEDUP_AUTOTUNE}" >> "\${CONFIG_FILE}"
fi

echo "" >> "\${CONFIG_FILE}"
echo "# Run completed: \$(date)" >> "\${CONFIG_FILE}"

# Add arrays statistics from metadata CSV
ARRAYS_CSV="${LOG_DIR_BASE}/autotune_on/ops_arrays_metadata.csv"
if [[ -f "\${ARRAYS_CSV}" ]]; then
  echo "" >> "\${CONFIG_FILE}"
  echo "# Arrays Statistics" >> "\${CONFIG_FILE}"
  
  # Total arrays (excluding header)
  TOTAL_ARRAYS=\$(tail -n +2 "\${ARRAYS_CSV}" | wc -l)
  echo "TOTAL_ARRAYS=\${TOTAL_ARRAYS}" >> "\${CONFIG_FILE}"
  
  # Count by access type
  ARRAYS_READ=\$(tail -n +2 "\${ARRAYS_CSV}" | grep -c ',READ$' || true)
  ARRAYS_WRITE=\$(tail -n +2 "\${ARRAYS_CSV}" | grep -c ',WRITE$' || true)
  ARRAYS_RW=\$(tail -n +2 "\${ARRAYS_CSV}" | grep -c ',RW$' || true)
  ARRAYS_INC=\$(tail -n +2 "\${ARRAYS_CSV}" | grep -c ',INC$' || true)
  echo "ARRAYS_READ=\${ARRAYS_READ}" >> "\${CONFIG_FILE}"
  echo "ARRAYS_WRITE=\${ARRAYS_WRITE}" >> "\${CONFIG_FILE}"
  echo "ARRAYS_RW=\${ARRAYS_RW}" >> "\${CONFIG_FILE}"
  ARRAYS_INC=\${ARRAYS_INC:-0}
  if [[ "\${ARRAYS_INC}" -gt 0 ]]; then
    echo "ARRAYS_INC=\${ARRAYS_INC}" >> "\${CONFIG_FILE}"
  fi
  
  # Largest and smallest arrays (by total_bytes, column 19)
  LARGEST_ARRAY=\$(tail -n +2 "\${ARRAYS_CSV}" | sort -t',' -k19 -n -r | head -1)
  SMALLEST_ARRAY=\$(tail -n +2 "\${ARRAYS_CSV}" | sort -t',' -k19 -n | head -1)
  
  if [[ -n "\${LARGEST_ARRAY}" ]]; then
    LARGEST_NAME=\$(echo "\${LARGEST_ARRAY}" | cut -d',' -f3)
    LARGEST_BYTES=\$(echo "\${LARGEST_ARRAY}" | cut -d',' -f19)
    LARGEST_SIZE_X=\$(echo "\${LARGEST_ARRAY}" | cut -d',' -f7)
    LARGEST_SIZE_Y=\$(echo "\${LARGEST_ARRAY}" | cut -d',' -f8)
    LARGEST_SIZE_Z=\$(echo "\${LARGEST_ARRAY}" | cut -d',' -f9)
    LARGEST_MB=\$(echo "scale=2; \${LARGEST_BYTES} / 1048576" | bc)
    echo "LARGEST_ARRAY=\${LARGEST_NAME} (\${LARGEST_SIZE_X}x\${LARGEST_SIZE_Y}x\${LARGEST_SIZE_Z}, \${LARGEST_MB} MB)" >> "\${CONFIG_FILE}"
  fi
  
  if [[ -n "\${SMALLEST_ARRAY}" ]]; then
    SMALLEST_NAME=\$(echo "\${SMALLEST_ARRAY}" | cut -d',' -f3)
    SMALLEST_BYTES=\$(echo "\${SMALLEST_ARRAY}" | cut -d',' -f19)
    SMALLEST_SIZE_X=\$(echo "\${SMALLEST_ARRAY}" | cut -d',' -f7)
    SMALLEST_SIZE_Y=\$(echo "\${SMALLEST_ARRAY}" | cut -d',' -f8)
    SMALLEST_SIZE_Z=\$(echo "\${SMALLEST_ARRAY}" | cut -d',' -f9)
    echo "SMALLEST_ARRAY=\${SMALLEST_NAME} (\${SMALLEST_SIZE_X}x\${SMALLEST_SIZE_Y}x\${SMALLEST_SIZE_Z}, \${SMALLEST_BYTES} bytes)" >> "\${CONFIG_FILE}"
  fi
  
  # Total memory footprint (sum of unique arrays by name)
  TOTAL_BYTES=\$(tail -n +2 "\${ARRAYS_CSV}" | cut -d',' -f3,19 | sort -u | cut -d',' -f2 | awk '{sum+=\$1} END {print sum}')
  TOTAL_MB=\$(echo "scale=2; \${TOTAL_BYTES} / 1048576" | bc)
  echo "TOTAL_UNIQUE_ARRAYS_MB=\${TOTAL_MB}" >> "\${CONFIG_FILE}"
fi
SCRIPT_BODY

  chmod +x "${RUN_SCRIPT_FILE}"
  echo "  >> Running on exclusive GPU node..."
  run_cmd "cd \"${app_dir}\" && ./run_modes.sh"

  # Wait for GPU memory to be fully released before next configuration
  sync
  sleep 3

  echo "==== ${app_name} - ${label} finished ===="
}


# ============================================================================
# Helper: resolve app_name -> app_dir
# ============================================================================
get_app_dir() {
  case "$1" in
    cloverleaf)    echo "${CLOVER_DIR}" ;;
    cloverleaf2d)  echo "${CLOVER2D_DIR}" ;;
    tti)           echo "${TTI_DIR}" ;;
    maxwell)       echo "${MAXWELL_DIR}" ;;
    lattboltz2d)   echo "${LBM_DIR}" ;;
    laplace2d)     echo "${LAPLACE2D_DIR}" ;;
    opensbli)      echo "${OPENSBLI_DIR}" ;;
    tgvstorenone)  echo "${TGV_DIR}" ;;
    tgvstoreall)   echo "${TGVSA_DIR}" ;;
  esac
}

# ============================================================================
# Helper: check if an app is 2D
# ============================================================================
is_2d_app() {
  [[ "$1" == "lattboltz2d" || "$1" == "laplace2d" || "$1" == "cloverleaf2d" ]]
}

# ============================================================================
# Helper: run only 3D apps for one grid config
# ============================================================================
run_3d_apps_for_config() {
  local GX="$1" GY="$2" GZ="$3" LABEL="$4"
  for app_name in ${RUN_APPS//,/ }; do
    if is_2d_app "${app_name}"; then continue; fi
    local app_dir
    app_dir=$(get_app_dir "${app_name}")
    run_grid_config "${app_name}" "${app_dir}" "${GX}" "${GY}" "${GZ}" "${LABEL}"
  done
}

# ============================================================================
# Helper: run only 2D apps for one grid config
# ============================================================================
run_2d_apps_for_config() {
  local GX="$1" GY="$2" GZ="$3" LABEL="$4"
  for app_name in ${RUN_APPS//,/ }; do
    if ! is_2d_app "${app_name}"; then continue; fi
    local app_dir
    app_dir=$(get_app_dir "${app_name}")
    run_grid_config "${app_name}" "${app_dir}" "${GX}" "${GY}" "${GZ}" "${LABEL}"
  done
}

# ============================================================================
# EXECUTION: STANDARD GRID STUDY
# ============================================================================
# Run 100^3 configurations - COMMENTED OUT
# echo
# echo "========================================================================"
# echo "  100^3 GRID CONFIGURATIONS (1,000,000 cells)"
# echo "========================================================================"
#
# # 3D apps
# for grid in "${GRIDS_100[@]}"; do
#   IFS=":" read -r GX GY GZ LABEL <<< "${grid}"
#   run_all_apps_for_config "${GX}" "${GY}" "${GZ}" "${LABEL}"
# done
# # 2D apps
# for grid in "${GRIDS_2D_100[@]}"; do
#   IFS=":" read -r GX GY GZ LABEL <<< "${grid}"
#   run_2d_apps_for_config "${GX}" "${GY}" "${GZ}" "${LABEL}"
# done

# Run 200^3 configurations
echo
echo "========================================================================"
echo "  200^3 GRID CONFIGURATIONS (8,000,000 cells)"
echo "========================================================================"

# 3D apps only (2D apps run with their dedicated GRIDS_2D_* below)
for grid in "${GRIDS_200[@]}"; do
  IFS=":" read -r GX GY GZ LABEL <<< "${grid}"
  run_3d_apps_for_config "${GX}" "${GY}" "${GZ}" "${LABEL}"
done
# 2D apps with dedicated 2D grids
for grid in "${GRIDS_2D_200[@]}"; do
  IFS=":" read -r GX GY GZ LABEL <<< "${grid}"
  run_2d_apps_for_config "${GX}" "${GY}" "${GZ}" "${LABEL}"
done

# Run 300^3 configurations
echo
echo "========================================================================"
echo "  300^3 GRID CONFIGURATIONS (27,000,000 cells)"
echo "========================================================================"

# 3D apps only (2D apps run with their dedicated GRIDS_2D_* below)
for grid in "${GRIDS_300[@]}"; do
  IFS=":" read -r GX GY GZ LABEL <<< "${grid}"
  run_3d_apps_for_config "${GX}" "${GY}" "${GZ}" "${LABEL}"
done
# 2D apps with dedicated 2D grids
for grid in "${GRIDS_2D_300[@]}"; do
  IFS=":" read -r GX GY GZ LABEL <<< "${grid}"
  run_2d_apps_for_config "${GX}" "${GY}" "${GZ}" "${LABEL}"
done

# Run 400^3 configurations
echo
echo "========================================================================"
echo "  400^3 GRID CONFIGURATIONS (64,000,000 cells)"
echo "========================================================================"

# 3D apps only (2D apps run with their dedicated GRIDS_2D_* below)
for grid in "${GRIDS_400[@]}"; do
  IFS=":" read -r GX GY GZ LABEL <<< "${grid}"
  run_3d_apps_for_config "${GX}" "${GY}" "${GZ}" "${LABEL}"
done
# 2D apps with dedicated 2D grids
for grid in "${GRIDS_2D_400[@]}"; do
  IFS=":" read -r GX GY GZ LABEL <<< "${grid}"
  run_2d_apps_for_config "${GX}" "${GY}" "${GZ}" "${LABEL}"
done

# Run 420^3 configurations
echo
echo "========================================================================"
echo "  420^3 GRID CONFIGURATIONS (74,088,000 cells) - ALL 231 CLASSES"
echo "========================================================================"

# 3D apps only
for grid in "${GRIDS_420[@]}"; do
  IFS=":" read -r GX GY GZ LABEL <<< "${grid}"
  run_3d_apps_for_config "${GX}" "${GY}" "${GZ}" "${LABEL}"
done

# Run 450^3 configurations
echo
echo "========================================================================"
echo "  450^3 GRID CONFIGURATIONS (91,125,000 cells) - ALL 231 CLASSES"
echo "========================================================================"

# 3D apps only
for grid in "${GRIDS_450[@]}"; do
  IFS=":" read -r GX GY GZ LABEL <<< "${grid}"
  run_3d_apps_for_config "${GX}" "${GY}" "${GZ}" "${LABEL}"
done

echo "==== END OF SCRIPT REACHED ===="

echo
echo "========================================================================"
echo "  GRID STUDY COMPLETE"
echo "========================================================================"
echo
TOTAL_3D=$((${#GRIDS_100[@]} + ${#GRIDS_200[@]} + ${#GRIDS_300[@]} + ${#GRIDS_400[@]} + ${#GRIDS_420[@]} + ${#GRIDS_450[@]}))
TOTAL_2D=$((${#GRIDS_2D_100[@]} + ${#GRIDS_2D_200[@]} + ${#GRIDS_2D_300[@]} + ${#GRIDS_2D_400[@]}))
TOTAL_CONFIGS=$((TOTAL_3D + TOTAL_2D))
echo "Total configurations run:"
echo "  3D grids:"
echo "    - 100^3: ${#GRIDS_100[@]} configs"
echo "    - 200^3: ${#GRIDS_200[@]} configs"
echo "    - 300^3: ${#GRIDS_300[@]} configs"
echo "    - 400^3: ${#GRIDS_400[@]} configs"
echo "    - 420^3: ${#GRIDS_420[@]} configs"
echo "    - 450^3: ${#GRIDS_450[@]} configs"
echo "    - Subtotal: ${TOTAL_3D} configs"
echo "  2D grids:"
echo "    - 100^3: ${#GRIDS_2D_100[@]} configs"
echo "    - 200^3: ${#GRIDS_2D_200[@]} configs"
echo "    - 300^3: ${#GRIDS_2D_300[@]} configs"
echo "    - 400^3: ${#GRIDS_2D_400[@]} configs"
echo "    - Subtotal: ${TOTAL_2D} configs"
echo "  Total: ${TOTAL_CONFIGS} configs"
echo
echo "All logs saved to: ${HOME}/OPS_Benchmark/OPS_LOGS/*_${DATE_STAMP}/"

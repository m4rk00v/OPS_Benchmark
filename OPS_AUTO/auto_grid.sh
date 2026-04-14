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

OPS_ROOT="${HOME}/OPS"
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

# ML Model paths for modes 4 (XGBoost multi-output), 5 (XGBoost online), 6 (XGBoost single-output)
ML_MODEL_DIR="${HOME}/OPS_DEEP-LEARNING/models"
XGBOOST_BX_PATH="${ML_MODEL_DIR}/xgboost_bx.json"
XGBOOST_BY_PATH="${ML_MODEL_DIR}/xgboost_by.json"
XGBOOST_BZ_PATH="${ML_MODEL_DIR}/xgboost_bz.json"
XGBOOST_SINGLE_PATH="${ML_MODEL_DIR}/xgboost_single.json"
XGBOOST_SINGLE_CLASSES_PATH="${ML_MODEL_DIR}/block_classes.txt"


# Mode 5: ML-guided exploration + online training (explores blocks, trains XGBoost)
ONLINE_UPDATE_INTERVAL=200   # Buffer N samples before updating XGBoost boosters

# Resume from checkpoint (set RESUME_FROM=0 for fresh start)
# RESUME_FROM: number of train configs already completed (0 = fresh start)
# RESUME_DIR:  path to the OPS_LOGS folder from the previous run
RESUME_FROM=0
RESUME_DIR=""

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
# Set which modes to run (comma-separated): 0,1,2,4,5,6 or any combination
# Mode 0: Default blocks (no tuning)
# Mode 1: Dynamic autotuning
# Mode 2: Precomputed blocks from CSV
# Mode 4: XGBoost-predicted blocks (C++ integration)
# Mode 5: ML-guided exploration + online training (explores blocks, trains XGBoost)
# Mode 6: XGBoost single-output predicted blocks (C++ integration)
# RUN_MODES="0,1,2,4,5,6"
RUN_MODES="0,2"

# Persistent log file (appends, never overwrites)
PERSISTENT_LOG="${HOME}/OPS_AUTO/auto_grid_history.log"  # Appends all output for history

echo ""
echo "========================================================================"
echo "  NEW JOB STARTED - SLURM_JOB_ID: ${SLURM_JOB_ID:-local}"
echo "  Date: $(date)"
echo "  RUN_MODES: ${RUN_MODES}"
echo "  OPS_BLOCKSIZE_BASE: ${OPS_BLOCKSIZE_BASE}"
if [[ ${RESUME_FROM} -gt 0 ]]; then
  echo "  RESUME_FROM: ${RESUME_FROM}"
  echo "  RESUME_DIR: ${RESUME_DIR}"
fi
echo "========================================================================"

# Append all output to persistent log file (keeps full history)
exec > >(tee -a "${PERSISTENT_LOG}") 2>&1

run_cmd() {
  echo "+ $*"
  eval "$@"
}

# ============================================================================
# Helper: generate best CSV from tuning CSV for Mode 4 (frozen prediction) runs
# Mode 4 doesn't write ops_blocksize_best_logmod.csv (only Mode 1/5 do in C++),
# but compute_online_metrics() needs it. Extract best-per-kernel from tuning CSV.
# ============================================================================
generate_best_csv_from_tuning() {
  local log_dir="$1"
  local tuning_csv="${log_dir}/autotune_on/ops_blocksize_tuning_logmod.csv"
  local best_csv="${log_dir}/autotune_on/ops_blocksize_best_logmod.csv"

  # Skip if best CSV already exists (don't overwrite Mode 5 data)
  if [[ -f "${best_csv}" ]]; then
    return 0
  fi

  # Skip if tuning CSV doesn't exist
  if [[ ! -f "${tuning_csv}" ]]; then
    return 0
  fi

  python3 - "${tuning_csv}" "${best_csv}" << 'PYEOF'
import sys, csv
from collections import defaultdict

tuning_path, best_path = sys.argv[1], sys.argv[2]

# Group by kernel_id, keep row with min execution_time
best_rows = {}
with open(tuning_path) as f:
    reader = csv.DictReader(f)
    for row in reader:
        try:
            kid = int(row['kernel_id'])
            t = float(row['execution_time'])
            if t <= 0 or t >= 1e100:
                continue
            if kid not in best_rows or t < best_rows[kid]['time']:
                best_rows[kid] = {
                    'time': t,
                    'bx': row['bx'],
                    'by': row['by'],
                    'bz': row['bz'],
                    'default_time': row.get('default_time', '0'),
                    'nargs': row.get('num_read', '0'),
                    'nstencil_args': row.get('nstencil_args', '0'),
                    'max_radius_x': row.get('max_radius_x', '0'),
                    'max_radius_y': row.get('max_radius_y', '0'),
                    'max_radius_z': row.get('max_radius_z', '0'),
                    'total_points': row.get('total_points', '0'),
                    'stencil_sig': row.get('stencil_sig', ''),
                    'max_threads': row.get('max_threads', '1024'),
                }
        except (ValueError, KeyError):
            continue

if not best_rows:
    sys.exit(0)

# Write best CSV matching expected schema
out_cols = ['kernel_id','bx','by','bz','best_time','default_time','points',
            'gpoints_per_s','nargs','nstencil_args','widest_radius',
            'widest_radius_x','widest_radius_y','widest_radius_z',
            'stencil_sig','max_threads_per_block']

with open(best_path, 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(out_cols)
    for kid in sorted(best_rows.keys()):
        r = best_rows[kid]
        pts = float(r['total_points']) if r['total_points'] else 0
        t = r['time']
        gpts = (pts / t / 1e9) if t > 0 and pts > 0 else 0
        rx = int(r['max_radius_x']) if r['max_radius_x'] != '0' else 0
        ry = int(r['max_radius_y']) if r['max_radius_y'] != '0' else 0
        rz = int(r['max_radius_z']) if r['max_radius_z'] != '0' else 0
        widest = max(rx, ry, rz)
        dt = float(r['default_time']) if r['default_time'] and float(r['default_time']) < 1e100 else t
        writer.writerow([kid, r['bx'], r['by'], r['bz'], t, dt, int(pts),
                         f"{gpts:.6f}", r['nargs'], r['nstencil_args'],
                         widest, rx, ry, rz, r['stencil_sig'], r['max_threads']])

print(f"  >> Generated best CSV: {best_path} ({len(best_rows)} kernels)")
PYEOF
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
  local LOG_DIR_BASE="${HOME}/OPS_LOGS/${app_name}_cuda_${label}_${DATE_STAMP}"
  
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
  export OPS_AUTOTUNE_LOGS=0
  echo "  >> Running ${app_name}_cuda | mode=1 | grid=${grid_x}x${grid_y}x${grid_z} | args: ${APP_ARGS}"
  OUTPUT_AUTOTUNE=\$(./${app_name}_cuda ${APP_ARGS} -OPS_DIAGS=2 -OPS_AUTOTUNE_MODE=1 2>&1 | tee /dev/stderr)
  WALL_TIME_AUTOTUNE=\$(echo "\${OUTPUT_AUTOTUNE}" | grep -oP 'Total Wall time \K[\d.]+' | tail -1)
  echo "WALL_TIME_AUTOTUNE=\${WALL_TIME_AUTOTUNE}" >> "\${CONFIG_FILE}"
  echo "# [MODE 1] Completed: \$(date) - Wall time: \${WALL_TIME_AUTOTUNE}s"
else
  echo "---- Mode 1: SKIPPED ----"
fi
gpu_sync

# Mode 4: XGBoost-predicted blocks (C++ integration)
if [[ "\${RUN_MODES}" == *"4"* ]]; then
  echo ""
  echo "###################################################################"
  echo "# [MODE 4] XGBOOST-PREDICTED BLOCKS - ${app_name} - ${label}"
  echo "# Started: \$(date)"
  echo "###################################################################"
  export OPS_XGBOOST_BX="${XGBOOST_BX_PATH}"
  export OPS_XGBOOST_BY="${XGBOOST_BY_PATH}"
  export OPS_XGBOOST_BZ="${XGBOOST_BZ_PATH}"
  echo "  >> Using XGBoost multi-output:"
  echo "  >>   bx: \${OPS_XGBOOST_BX}"
  echo "  >>   by: \${OPS_XGBOOST_BY}"
  echo "  >>   bz: \${OPS_XGBOOST_BZ}"
  echo "  >> Running ${app_name}_cuda | mode=4 | grid=${grid_x}x${grid_y}x${grid_z} | args: ${APP_ARGS}"
  OUTPUT_XGBOOST=\$(./${app_name}_cuda ${APP_ARGS} -OPS_DIAGS=2 -OPS_AUTOTUNE_MODE=4 2>&1 | tee /dev/stderr)
  WALL_TIME_XGBOOST=\$(echo "\${OUTPUT_XGBOOST}" | grep -oP 'Total Wall time \K[\d.]+' | tail -1)
  echo "WALL_TIME_XGBOOST=\${WALL_TIME_XGBOOST}" >> "\${CONFIG_FILE}"
  echo "# [MODE 4] Completed: \$(date) - Wall time: \${WALL_TIME_XGBOOST}s"
  unset OPS_XGBOOST_BX OPS_XGBOOST_BY OPS_XGBOOST_BZ
else
  echo "---- Mode 4: SKIPPED ----"
fi
gpu_sync

# Mode 5: ML-guided exploration + online training
if [[ "\${RUN_MODES}" == *"5"* ]]; then
  echo ""
  echo "###################################################################"
  echo "# [MODE 5] ML-GUIDED EXPLORATION + TRAINING - ${app_name} - ${label}"
  echo "# Started: \$(date)"
  echo "###################################################################"
  export OPS_XGBOOST_BX="${XGBOOST_BX_PATH}"
  export OPS_XGBOOST_BY="${XGBOOST_BY_PATH}"
  export OPS_XGBOOST_BZ="${XGBOOST_BZ_PATH}"
  export OPS_ONLINE_UPDATE_INTERVAL="${ONLINE_UPDATE_INTERVAL}"

  echo "  >> Using XGBoost multi-output (exploration + training):"
  echo "  >>   bx: \${OPS_XGBOOST_BX}"
  echo "  >>   by: \${OPS_XGBOOST_BY}"
  echo "  >>   bz: \${OPS_XGBOOST_BZ}"
  echo "  >>   update_interval: \${OPS_ONLINE_UPDATE_INTERVAL}"
  echo "  >> Running ${app_name}_cuda | mode=5 | grid=${grid_x}x${grid_y}x${grid_z} | args: ${APP_ARGS}"
  TMPOUT_EXPLORE=\$(mktemp)
  ./${app_name}_cuda ${APP_ARGS} -OPS_DIAGS=2 -OPS_AUTOTUNE_MODE=5 2>&1 | tee "\${TMPOUT_EXPLORE}" || true
  WALL_TIME_EXPLORE=\$(grep -oP 'Total Wall time \K[\d.]+' "\${TMPOUT_EXPLORE}" | tail -1 || true)
  rm -f "\${TMPOUT_EXPLORE}"
  if [[ -z "\${WALL_TIME_EXPLORE}" ]]; then
    WALL_TIME_EXPLORE="CRASHED"
    echo "  >> WARNING: Mode 5 crashed or produced no wall time"
  fi
  echo "WALL_TIME_EXPLORE=\${WALL_TIME_EXPLORE}" >> "\${CONFIG_FILE}"
  echo "# [MODE 5] Completed: \$(date) - Wall time: \${WALL_TIME_EXPLORE}s"
  unset OPS_XGBOOST_BX OPS_XGBOOST_BY OPS_XGBOOST_BZ OPS_ONLINE_UPDATE_INTERVAL
else
  echo "---- Mode 5: SKIPPED ----"
fi
gpu_sync

# Mode 6: XGBoost single-output predicted blocks (C++ integration, 231 combined classes)
if [[ "\${RUN_MODES}" == *"6"* ]]; then
  echo ""
  echo "###################################################################"
  echo "# [MODE 6] XGBOOST SINGLE-OUTPUT PREDICTED BLOCKS - ${app_name} - ${label}"
  echo "# Started: \$(date)"
  echo "###################################################################"
  export OPS_XGBOOST_SINGLE="${XGBOOST_SINGLE_PATH}"
  export OPS_XGBOOST_SINGLE_CLASSES="${XGBOOST_SINGLE_CLASSES_PATH}"
  echo "  >> Using XGBoost single-output model: \${OPS_XGBOOST_SINGLE}"
  echo "  >> Using class mapping: \${OPS_XGBOOST_SINGLE_CLASSES}"
  echo "  >> Running ${app_name}_cuda | mode=6 | grid=${grid_x}x${grid_y}x${grid_z} | args: ${APP_ARGS}"
  OUTPUT_XGB_SINGLE=\$(./${app_name}_cuda ${APP_ARGS} -OPS_DIAGS=2 -OPS_AUTOTUNE_MODE=6 2>&1 | tee /dev/stderr)
  WALL_TIME_XGB_SINGLE=\$(echo "\${OUTPUT_XGB_SINGLE}" | grep -oP 'Total Wall time \K[\d.]+' | tail -1)
  echo "WALL_TIME_XGB_SINGLE=\${WALL_TIME_XGB_SINGLE}" >> "\${CONFIG_FILE}"
  echo "# [MODE 6] Completed: \$(date) - Wall time: \${WALL_TIME_XGB_SINGLE}s"
  unset OPS_XGBOOST_SINGLE
  unset OPS_XGBOOST_SINGLE_CLASSES
else
  echo "---- Mode 6: SKIPPED ----"
fi

# Calculate speedups
if [[ -n "\${WALL_TIME_NO_AUTOTUNE:-}" && -n "\${WALL_TIME_PRECOMPUTED:-}" && "\${WALL_TIME_PRECOMPUTED}" != "N/A" ]]; then
  SPEEDUP_PRECOMPUTED=\$(echo "scale=4; \${WALL_TIME_NO_AUTOTUNE} / \${WALL_TIME_PRECOMPUTED}" | bc)
  echo "SPEEDUP_PRECOMPUTED=\${SPEEDUP_PRECOMPUTED}" >> "\${CONFIG_FILE}"
fi
if [[ -n "\${WALL_TIME_NO_AUTOTUNE:-}" && -n "\${WALL_TIME_AUTOTUNE:-}" ]]; then
  SPEEDUP_AUTOTUNE=\$(echo "scale=4; \${WALL_TIME_NO_AUTOTUNE} / \${WALL_TIME_AUTOTUNE}" | bc)
  echo "SPEEDUP_AUTOTUNE=\${SPEEDUP_AUTOTUNE}" >> "\${CONFIG_FILE}"
fi
if [[ -n "\${WALL_TIME_NO_AUTOTUNE:-}" && -n "\${WALL_TIME_XGBOOST:-}" ]]; then
  SPEEDUP_XGBOOST=\$(echo "scale=4; \${WALL_TIME_NO_AUTOTUNE} / \${WALL_TIME_XGBOOST}" | bc)
  echo "SPEEDUP_XGBOOST=\${SPEEDUP_XGBOOST}" >> "\${CONFIG_FILE}"
fi
if [[ -n "\${WALL_TIME_NO_AUTOTUNE:-}" && -n "\${WALL_TIME_EXPLORE:-}" && "\${WALL_TIME_EXPLORE}" != "CRASHED" ]]; then
  SPEEDUP_EXPLORE=\$(echo "scale=4; \${WALL_TIME_NO_AUTOTUNE} / \${WALL_TIME_EXPLORE}" | bc)
  echo "SPEEDUP_EXPLORE=\${SPEEDUP_EXPLORE}" >> "\${CONFIG_FILE}"
fi
if [[ -n "\${WALL_TIME_NO_AUTOTUNE:-}" && -n "\${WALL_TIME_XGB_SINGLE:-}" && "\${WALL_TIME_XGB_SINGLE}" != "N/A" ]]; then
  SPEEDUP_XGB_SINGLE=\$(echo "scale=4; \${WALL_TIME_NO_AUTOTUNE} / \${WALL_TIME_XGB_SINGLE}" | bc)
  echo "SPEEDUP_XGB_SINGLE=\${SPEEDUP_XGB_SINGLE}" >> "\${CONFIG_FILE}"
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
# Helper: compute per-config online metrics (appends to METRICS_CSV)
# ============================================================================
compute_online_metrics() {
  local log_dir="$1" phase="$2" config_idx="$3" label="$4" app_name="$5" metrics_csv="$6"

  python3 - "${log_dir}" "${phase}" "${config_idx}" "${label}" "${app_name}" "${metrics_csv}" << 'PYEOF'
import sys, os, csv
log_dir, phase, config_idx, label, app_name, metrics_csv = sys.argv[1:7]

best_off = os.path.join(log_dir, "autotune_off", "ops_blocksize_best_logmod.csv")
best_on  = os.path.join(log_dir, "autotune_on",  "ops_blocksize_best_logmod.csv")
tuning5  = os.path.join(log_dir, "autotune_on",  "ops_blocksize_tuning_logmod.csv")

if not os.path.isfile(best_off) or not os.path.isfile(best_on):
    print(f"  >> Metrics: best CSV not found for {app_name}/{label}, skipping")
    sys.exit(0)

# Read best_time per kernel from a best CSV (one row per kernel)
def read_best_csv(path):
    times = {}
    with open(path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                kid = int(row['kernel_id'])
                t = float(row['best_time'])
                if t > 0 and t < 1e100:
                    times[kid] = t
            except (ValueError, KeyError):
                continue
    return times

# Read pred_time and pred_rank from Mode 5 tuning CSV
def read_pred_metrics(path):
    pred_times = {}
    best_ranks = {}
    if not os.path.isfile(path):
        return pred_times, best_ranks
    with open(path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                kid = int(row['kernel_id'])
                if 'pred_time' in row:
                    pt = float(row['pred_time'])
                    if pt > 0:
                        pred_times[kid] = pt
                if 'pred_rank' in row:
                    pr = int(row['pred_rank'])
                    if pr > 0:
                        best_ranks[kid] = pr
            except (ValueError, KeyError):
                continue
    return pred_times, best_ranks

# default_time = best_time from autotune_off (time with default blocks)
# explored_best = best_time from autotune_on (time from Mode 5 exploration)
t_default = read_best_csv(best_off)
t_explored = read_best_csv(best_on)
pred_times, best_ranks = read_pred_metrics(tuning5)

# Mode 4 fallback: ML prediction IS the only block used, so pred_time = best_time, rank = 1
if not pred_times and t_explored:
    pred_times = dict(t_explored)
    best_ranks = {k: 1 for k in t_explored}

# Autotunable: kernels in both CSVs where exploration found a better block
common = set(t_default.keys()) & set(t_explored.keys())
autotunable = set(k for k in common if t_explored[k] < t_default[k])

# Explore metrics: explored_best / default
explore_ratios = []
for kid in common:
    if t_default[kid] > 0:
        explore_ratios.append(t_explored[kid] / t_default[kid])

# ML prediction metrics: pred_time / default_time (ONLY autotunable kernels)
pred_ratios = []
for kid in pred_times:
    if kid in autotunable and kid in t_default and t_default[kid] > 0:
        pred_ratios.append(pred_times[kid] / t_default[kid])

# Rank metrics (ONLY autotunable kernels)
ranks = [best_ranks[kid] for kid in best_ranks if kid in autotunable]

if not explore_ratios:
    print(f"  >> Metrics: no matching kernels for {app_name}/{label}")
    sys.exit(0)

avg_r       = sum(explore_ratios) / len(explore_ratios)
pct_faster  = sum(1 for r in explore_ratios if r < 1.0) / len(explore_ratios) * 100

n_autotunable = len(autotunable)
pred_loss = sum(pred_ratios) / len(pred_ratios) if pred_ratios else -1.0
pred_acc  = sum(1 for r in pred_ratios if r < 1.0) / len(pred_ratios) * 100 if pred_ratios else -1.0
avg_rank  = sum(ranks) / len(ranks) if ranks else -1.0

with open(metrics_csv, 'a') as f:
    f.write(f"{config_idx},{phase},{label},{app_name},{avg_r:.6f},{pct_faster:.1f},{pred_loss:.6f},{pred_acc:.1f},{avg_rank:.1f}\n")

out = f"  >> Metrics [{phase}] {app_name}/{label}: explore_r={avg_r:.4f} ({pct_faster:.1f}% faster)"
if pred_ratios:
    out += f" | ML pred_loss={pred_loss:.4f} pred_acc={pred_acc:.1f}% avg_rank={avg_rank:.1f} ({n_autotunable}/{len(common)} autotunable)"
else:
    out += f" ({len(explore_ratios)} kernels)"
print(out)
PYEOF
}

# ============================================================================
# Helper: print running summary from metrics CSV (for real-time log output)
# ============================================================================
print_online_summary() {
  local metrics_csv="$1" config_idx="$2" total_configs="$3" phase="$4"

  python3 - "${metrics_csv}" "${config_idx}" "${total_configs}" "${phase}" << 'PYEOF'
import sys, csv
from collections import defaultdict

metrics_csv, config_idx, total_configs, requested_phase = sys.argv[1:5]

rows = []
with open(metrics_csv) as f:
    reader = csv.DictReader(f)
    for row in reader:
        rows.append(row)

if not rows:
    sys.exit(0)

def phase_summary(phase_rows):
    if not phase_rows:
        return None, None, None, None, None
    rs = [float(r['avg_r']) for r in phase_rows]
    pcts = [float(r['pct_faster']) for r in phase_rows]
    # ML prediction metrics (may not exist in older data)
    pred_ls = [float(r['pred_loss']) for r in phase_rows if 'pred_loss' in r and float(r.get('pred_loss', -1)) > 0]
    pred_as = [float(r['pred_acc']) for r in phase_rows if 'pred_acc' in r and float(r.get('pred_acc', -1)) >= 0]
    avg_rks = [float(r['avg_rank']) for r in phase_rows if 'avg_rank' in r and float(r.get('avg_rank', -1)) > 0]
    pl = sum(pred_ls)/len(pred_ls) if pred_ls else None
    pa = sum(pred_as)/len(pred_as) if pred_as else None
    ar = sum(avg_rks)/len(avg_rks) if avg_rks else None
    return sum(rs)/len(rs), sum(pcts)/len(pcts), pl, pa, ar

train_rows = [r for r in rows if r['phase'] == 'train']
val_rows   = [r for r in rows if r['phase'] == 'val']
test_rows  = [r for r in rows if r['phase'] == 'test']

# Current config's train metrics (average across apps for this config_idx)
current = [r for r in train_rows if r['config_idx'] == config_idx]
cur_r, cur_acc, cur_pl, cur_pa, cur_rk = phase_summary(current)

# Running average across all train configs so far
run_r, run_acc, run_pl, run_pa, run_rk = phase_summary(train_rows)

if requested_phase == "train" and cur_r is not None:
    line = f"  ┌─ [TRAIN {config_idx:>3}/{total_configs}]"
    if cur_pl is not None:
        line += f"  pred_loss={cur_pl:.4f}  pred_acc={cur_pa:.1f}%  avg_rank={cur_rk:.1f}"
    else:
        line += f"  loss(r)={cur_r:.4f}  acc={cur_acc:.1f}%"
    line += f"  │  running avg:"
    if run_pl is not None:
        line += f" pred_loss={run_pl:.4f} pred_acc={run_pa:.1f}% avg_rank={run_rk:.1f}"
    else:
        line += f" loss={run_r:.4f} acc={run_acc:.1f}%"
    print(line)

elif requested_phase == "checkpoint":
    # Latest val metrics (all val rows with config_idx == this checkpoint's idx)
    latest_val = [r for r in val_rows if r['config_idx'] == config_idx]
    val_r, val_acc, val_pl, val_pa, val_rk = phase_summary(latest_val)

    print(f"  ╔══════════════════════════════════════════════════════════════╗")
    print(f"  ║  CHECKPOINT (after {config_idx} train configs)                      ")
    if run_pl is not None:
        print(f"  ║  TRAIN  pred_loss={run_pl:.4f}  pred_acc={run_pa:.1f}%  avg_rank={run_rk:.1f}  ({len(train_rows)} samples)")
    elif run_r is not None:
        print(f"  ║  TRAIN  loss(r)={run_r:.4f}   acc={run_acc:.1f}%  ({len(train_rows)} samples)")
    if val_pl is not None:
        print(f"  ║  VAL    pred_loss={val_pl:.4f}  pred_acc={val_pa:.1f}%  avg_rank={val_rk:.1f}  ({len(latest_val)} samples)")
    elif val_r is not None:
        print(f"  ║  VAL    loss(r)={val_r:.4f}   acc={val_acc:.1f}%  ({len(latest_val)} samples)")
    else:
        print(f"  ║  VAL    (no data)")
    cmp_train = run_pl if run_pl is not None else run_r
    cmp_val = val_pl if val_pl is not None else val_r
    if cmp_train and cmp_val:
        gap = cmp_val - cmp_train
        sign = "+" if gap >= 0 else ""
        print(f"  ║  GAP    {sign}{gap:.4f}  {'(overfit)' if gap > 0.05 else '(ok)'}")
    print(f"  ╚══════════════════════════════════════════════════════════════╝")

elif requested_phase == "test":
    test_r, test_acc = phase_summary(test_rows)
    print(f"  ╔══════════════════════════════════════════════════════════════╗")
    print(f"  ║  FINAL TEST RESULTS                                         ")
    if run_r is not None:
        print(f"  ║  TRAIN  loss(r)={run_r:.4f}   acc={run_acc:.1f}%")
    if test_r is not None:
        print(f"  ║  TEST   loss(r)={test_r:.4f}   acc={test_acc:.1f}%  ({len(test_rows)} samples)")
    print(f"  ╚══════════════════════════════════════════════════════════════╝")
PYEOF
}

# ============================================================================
# Helper: generate train/val loss and accuracy curves
# ============================================================================
generate_online_curves() {
  local metrics_csv="$1" output_dir="$2"

  python3 - "${metrics_csv}" "${output_dir}" << 'PYEOF'
import sys, csv, os
from collections import defaultdict
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

metrics_csv, output_dir = sys.argv[1], sys.argv[2]

rows = []
with open(metrics_csv) as f:
    reader = csv.DictReader(f)
    for row in reader:
        rows.append(row)

if not rows:
    print("No metrics data, skipping curve generation")
    sys.exit(0)

# Group by (phase, config_idx) and average across apps
def group_by_idx(data):
    groups = defaultdict(lambda: {'r': [], 'pct': []})
    for r in data:
        idx = int(r['config_idx'])
        groups[idx]['r'].append(float(r['avg_r']))
        groups[idx]['pct'].append(float(r['pct_faster']))
    result = []
    for idx in sorted(groups):
        result.append((idx, np.mean(groups[idx]['r']), np.mean(groups[idx]['pct'])))
    return result

train_rows = [r for r in rows if r['phase'] == 'train']
val_rows   = [r for r in rows if r['phase'] == 'val']
test_rows  = [r for r in rows if r['phase'] == 'test']

train_avg = group_by_idx(train_rows)
val_avg   = group_by_idx(val_rows)

# ── PLOT 1: Loss curve (avg_r = t_pred / t_default) ──
fig, ax = plt.subplots(figsize=(14, 6))
if train_avg:
    ax.plot([x[0] for x in train_avg], [x[1] for x in train_avg],
            'b.-', alpha=0.6, markersize=4, label='Train')
if val_avg:
    ax.plot([x[0] for x in val_avg], [x[1] for x in val_avg],
            'rs-', markersize=8, label='Val')
ax.axhline(y=1.0, color='gray', linestyle='--', alpha=0.5, label='Parity (r=1)')
ax.set_xlabel('Train config index')
ax.set_ylabel('avg r = t_pred / t_default  (lower is better)')
ax.set_title('Online Learning: Loss Curve')
ax.legend()
ax.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig(f"{output_dir}/loss_curve.png", dpi=150)
plt.close()

# ── PLOT 2: Accuracy curve (% kernels faster) ──
fig, ax = plt.subplots(figsize=(14, 6))
if train_avg:
    ax.plot([x[0] for x in train_avg], [x[2] for x in train_avg],
            'b.-', alpha=0.6, markersize=4, label='Train')
if val_avg:
    ax.plot([x[0] for x in val_avg], [x[2] for x in val_avg],
            'rs-', markersize=8, label='Val')
ax.set_xlabel('Train config index')
ax.set_ylabel('% kernels faster than default')
ax.set_title('Online Learning: Accuracy Curve')
ax.legend()
ax.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig(f"{output_dir}/accuracy_curve.png", dpi=150)
plt.close()

# ── PLOT 3: Final summary table ──
if test_rows:
    test_avg = group_by_idx(test_rows)
    print(f"\n  TEST results: avg_r={np.mean([x[1] for x in test_avg]):.4f}, "
          f"pct_faster={np.mean([x[2] for x in test_avg]):.1f}%")

print(f"\n  Curves saved to {output_dir}/loss_curve.png, accuracy_curve.png")
PYEOF
}


# ============================================================================
# EXECUTION: ONLINE LEARNING (Mode 5) vs STANDARD GRID STUDY
# ============================================================================

if [[ ",${RUN_MODES}," == *",5,"* ]]; then

# ============================================================================
# MODE 5: ML-GUIDED EXPLORATION + ONLINE TRAINING PIPELINE
# ============================================================================
# Mode 5 explores blocks per kernel (~20-30 candidates), uses the best found
# block as correct label to train XGBoost online. The model improves over
# configs because labels come from real measurements, not arbitrary heuristics.
#
# Pipeline: TRAIN configs -> model updates -> VAL checkpoints -> TEST evaluation
# ============================================================================

echo
echo "========================================================================"
echo "  ML-GUIDED EXPLORATION + ONLINE TRAINING PIPELINE (Mode 5)"
echo "  Explore blocks -> train XGBoost with time-based loss"
echo "========================================================================"

# Build train / val / test splits — stratified by grid size (3 val per grid)
N_VAL_PER_GRID=8

TRAIN_CONFIGS=()
VAL_CONFIGS=()
TEST_CONFIGS=()

for GRID_ARR_NAME in GRIDS_100 GRIDS_200 GRIDS_300 GRIDS_400 GRIDS_420 GRIDS_450 GRIDS_2D_100 GRIDS_2D_200 GRIDS_2D_300 GRIDS_2D_400; do
  eval "GRID_ARR=(\"\${${GRID_ARR_NAME}[@]}\")"
  N_GRID=${#GRID_ARR[@]}

  # Shuffle this grid size deterministically
  mapfile -t GRID_SHUFFLED < <(printf '%s\n' "${GRID_ARR[@]}" | shuf --random-source=<(yes ${N_GRID} | head -10000))

  # First N_VAL_PER_GRID go to val, next N_TEST_PER_GRID to test, rest to train
  N_TEST_PER_GRID=4
  for ((i=0; i<N_GRID; i++)); do
    if (( i < N_VAL_PER_GRID )); then
      VAL_CONFIGS+=("${GRID_SHUFFLED[$i]}")
    elif (( i < N_VAL_PER_GRID + N_TEST_PER_GRID )); then
      TEST_CONFIGS+=("${GRID_SHUFFLED[$i]}")
    else
      TRAIN_CONFIGS+=("${GRID_SHUFFLED[$i]}")
    fi
  done
done

# Shuffle train configs so grid sizes are interleaved
TOTAL_TRAIN=${#TRAIN_CONFIGS[@]}
mapfile -t TRAIN_CONFIGS < <(printf '%s\n' "${TRAIN_CONFIGS[@]}" | shuf --random-source=<(yes ${TOTAL_TRAIN} | head -10000))

TOTAL_CONFIGS=$(( ${#TRAIN_CONFIGS[@]} + ${#VAL_CONFIGS[@]} + ${#TEST_CONFIGS[@]} ))

echo "  Total configs: ${TOTAL_CONFIGS}"
echo "  Train: ${#TRAIN_CONFIGS[@]}  Val: ${#VAL_CONFIGS[@]}  Test: ${#TEST_CONFIGS[@]} (saved for later)"
echo "  Update interval: ${ONLINE_UPDATE_INTERVAL}"

if [[ ${RESUME_FROM} -gt 0 && -n "${RESUME_DIR}" && -d "${RESUME_DIR}" ]]; then
  # ---- RESUME MODE ----
  EXPLORE_RESULTS_DIR="${RESUME_DIR}/explore_results_${DATE_STAMP}"

  if [[ ! -d "${EXPLORE_RESULTS_DIR}" ]]; then
    echo "  ERROR: explore_results not found: ${EXPLORE_RESULTS_DIR}"
    exit 1
  fi

  # Reload splits from previous run; if missing, save the ones we just generated
  if [[ -f "${EXPLORE_RESULTS_DIR}/train_configs.txt" ]]; then
    mapfile -t TRAIN_CONFIGS < "${EXPLORE_RESULTS_DIR}/train_configs.txt"
    mapfile -t VAL_CONFIGS   < "${EXPLORE_RESULTS_DIR}/val_configs.txt"
    mapfile -t TEST_CONFIGS  < "${EXPLORE_RESULTS_DIR}/test_configs.txt"
    echo "  Splits reloaded from: ${EXPLORE_RESULTS_DIR}"
  else
    # Previous run didn't save splits — save the deterministic ones now
    printf '%s\n' "${TRAIN_CONFIGS[@]}" > "${EXPLORE_RESULTS_DIR}/train_configs.txt"
    printf '%s\n' "${VAL_CONFIGS[@]}"   > "${EXPLORE_RESULTS_DIR}/val_configs.txt"
    printf '%s\n' "${TEST_CONFIGS[@]}"  > "${EXPLORE_RESULTS_DIR}/test_configs.txt"
    echo "  Splits generated and saved to: ${EXPLORE_RESULTS_DIR}"
  fi

  METRICS_CSV="${EXPLORE_RESULTS_DIR}/online_metrics.csv"

  CHECKPOINT_DIR="${EXPLORE_RESULTS_DIR}/checkpoints"
  WORK_BX="${CHECKPOINT_DIR}/xgboost_multi_bx_work.xgb"
  WORK_BY="${CHECKPOINT_DIR}/xgboost_multi_by_work.xgb"
  WORK_BZ="${CHECKPOINT_DIR}/xgboost_multi_bz_work.xgb"

  # Validate checkpoint models exist
  for f in "${WORK_BX}" "${WORK_BY}" "${WORK_BZ}"; do
    if [[ ! -f "$f" ]]; then
      echo "  ERROR: checkpoint model not found: $f"
      exit 1
    fi
  done

  # Use checkpoint work copies as starting models
  XGBOOST_BX_PATH="${WORK_BX}"
  XGBOOST_BY_PATH="${WORK_BY}"
  XGBOOST_BZ_PATH="${WORK_BZ}"

  echo "  RESUMING from config ${RESUME_FROM}/${#TRAIN_CONFIGS[@]}"
  echo "  Train: ${#TRAIN_CONFIGS[@]}  Val: ${#VAL_CONFIGS[@]}  Test: ${#TEST_CONFIGS[@]}"
  echo "  Models: ${CHECKPOINT_DIR}"
  echo "  Metrics: ${METRICS_CSV}"
else
  # ---- FRESH START ----
  RESUME_FROM=0
  EXPLORE_RESULTS_DIR="${HOME}/OPS_LOGS/explore_results_${DATE_STAMP}"
  mkdir -p "${EXPLORE_RESULTS_DIR}"

  METRICS_CSV="${EXPLORE_RESULTS_DIR}/online_metrics.csv"
  echo "config_idx,phase,label,app,avg_r,pct_faster,pred_loss,pred_acc,avg_rank" > "${METRICS_CSV}"

  # Save all splits to files (for resume support)
  printf '%s\n' "${TRAIN_CONFIGS[@]}" > "${EXPLORE_RESULTS_DIR}/train_configs.txt"
  printf '%s\n' "${VAL_CONFIGS[@]}"   > "${EXPLORE_RESULTS_DIR}/val_configs.txt"
  printf '%s\n' "${TEST_CONFIGS[@]}"  > "${EXPLORE_RESULTS_DIR}/test_configs.txt"
  echo "  Splits saved to: ${EXPLORE_RESULTS_DIR}/{train,val,test}_configs.txt"

  # Copy original models for checkpoint/restore
  CHECKPOINT_DIR="${EXPLORE_RESULTS_DIR}/checkpoints"
  mkdir -p "${CHECKPOINT_DIR}"
  cp "${XGBOOST_BX_PATH}" "${CHECKPOINT_DIR}/xgboost_multi_bx_initial.xgb"
  cp "${XGBOOST_BY_PATH}" "${CHECKPOINT_DIR}/xgboost_multi_by_initial.xgb"
  cp "${XGBOOST_BZ_PATH}" "${CHECKPOINT_DIR}/xgboost_multi_bz_initial.xgb"

  # Working copies that get updated during training
  WORK_BX="${CHECKPOINT_DIR}/xgboost_multi_bx_work.xgb"
  WORK_BY="${CHECKPOINT_DIR}/xgboost_multi_by_work.xgb"
  WORK_BZ="${CHECKPOINT_DIR}/xgboost_multi_bz_work.xgb"
  cp "${XGBOOST_BX_PATH}" "${WORK_BX}"
  cp "${XGBOOST_BY_PATH}" "${WORK_BY}"
  cp "${XGBOOST_BZ_PATH}" "${WORK_BZ}"
fi

ORIG_RUN_MODES="${RUN_MODES}"

# ---- RETROACTIVE FIX: generate missing best CSVs for existing val/test dirs ----
# This recovers val metrics from previous/current job runs without re-running.
echo "  Checking existing log dirs for missing best CSVs..."
retro_count=0
for app_name in ${RUN_APPS//,/ }; do
  for cfg in "${VAL_CONFIGS[@]}" "${TEST_CONFIGS[@]}"; do
    IFS=":" read -r _gx _gy _gz _label <<< "${cfg}"
    retro_dir="${HOME}/OPS_LOGS/${app_name}_cuda_${_label}_${DATE_STAMP}"
    if [[ -d "${retro_dir}/autotune_on" ]]; then
      if [[ ! -f "${retro_dir}/autotune_on/ops_blocksize_best_logmod.csv" ]] && \
         [[ -f "${retro_dir}/autotune_on/ops_blocksize_tuning_logmod.csv" ]]; then
        generate_best_csv_from_tuning "${retro_dir}"
        retro_count=$((retro_count + 1))
      fi
    fi
  done
done
if (( retro_count > 0 )); then
  echo "  >> Retroactively generated ${retro_count} best CSVs from existing tuning data"
else
  echo "  >> No missing best CSVs found (all up to date)"
fi

# Checkpoint interval: evaluate on val every N train configs
CHECKPOINT_EVERY=10

# ---- TRAINING PHASE ----
echo
echo "========================================================================"
echo "  TRAINING PHASE (${#TRAIN_CONFIGS[@]} configs)"
echo "========================================================================"

train_count=0
for grid in "${TRAIN_CONFIGS[@]}"; do
  IFS=":" read -r GX GY GZ LABEL <<< "${grid}"
  train_count=$((train_count + 1))

  # Skip configs already processed in previous run
  if (( train_count <= RESUME_FROM )); then
    continue
  fi

  echo
  echo "================================================================="
  echo "  TRAIN ${train_count}/${#TRAIN_CONFIGS[@]}: ${LABEL} (${GX}x${GY}x${GZ})"
  echo "================================================================="

  RUN_MODES="0,5"

  # Point Mode 5 at working model copies (so updates accumulate)
  XGBOOST_BX_PATH="${WORK_BX}"
  XGBOOST_BY_PATH="${WORK_BY}"
  XGBOOST_BZ_PATH="${WORK_BZ}"

  # Run appropriate apps based on config type (2D configs have _2d_ in label)
  for app_name in ${RUN_APPS//,/ }; do
    if [[ "${LABEL}" == *"_2d_"* ]]; then
      # 2D config: only run 2D apps
      if ! is_2d_app "${app_name}"; then continue; fi
    else
      # 3D config: only run 3D apps
      if is_2d_app "${app_name}"; then continue; fi
    fi
    local_app_dir=$(get_app_dir "${app_name}")
    run_grid_config "${app_name}" "${local_app_dir}" "${GX}" "${GY}" "${GZ}" "${LABEL}"

    # Compute per-config metrics
    LOG_DIR_THIS="${HOME}/OPS_LOGS/${app_name}_cuda_${LABEL}_${DATE_STAMP}"
    compute_online_metrics "${LOG_DIR_THIS}" "train" "${train_count}" "${LABEL}" "${app_name}" "${METRICS_CSV}"
  done

  # Print running train summary
  print_online_summary "${METRICS_CSV}" "${train_count}" "${#TRAIN_CONFIGS[@]}" "train"

  # Checkpoint: save model + evaluate on val set
  if (( train_count % CHECKPOINT_EVERY == 0 )) || (( train_count == ${#TRAIN_CONFIGS[@]} )); then
    echo
    echo "  ---- CHECKPOINT after ${train_count} train configs ----"

    # Save checkpoint
    cp "${WORK_BX}" "${CHECKPOINT_DIR}/xgboost_multi_bx_ckpt${train_count}.xgb"
    cp "${WORK_BY}" "${CHECKPOINT_DIR}/xgboost_multi_by_ckpt${train_count}.xgb"
    cp "${WORK_BZ}" "${CHECKPOINT_DIR}/xgboost_multi_bz_ckpt${train_count}.xgb"

    # Evaluate on VAL set (model is frozen during val — Mode 4 for inference only)
    for val_grid in "${VAL_CONFIGS[@]}"; do
      IFS=":" read -r VGX VGY VGZ VLABEL <<< "${val_grid}"

      # Use Mode 0 + Mode 5 but the model won't update much on val (few samples)
      # Actually use Mode 4 (frozen prediction) for val to measure pure prediction quality
      RUN_MODES="0,4"
      XGBOOST_BX_PATH="${WORK_BX}"
      XGBOOST_BY_PATH="${WORK_BY}"
      XGBOOST_BZ_PATH="${WORK_BZ}"

      # Run appropriate apps based on config type (2D configs have _2d_ in label)
      for app_name in ${RUN_APPS//,/ }; do
        if [[ "${VLABEL}" == *"_2d_"* ]]; then
          if ! is_2d_app "${app_name}"; then continue; fi
        else
          if is_2d_app "${app_name}"; then continue; fi
        fi
        local_app_dir=$(get_app_dir "${app_name}")
        run_grid_config "${app_name}" "${local_app_dir}" "${VGX}" "${VGY}" "${VGZ}" "${VLABEL}"

        LOG_DIR_VAL="${HOME}/OPS_LOGS/${app_name}_cuda_${VLABEL}_${DATE_STAMP}"
        generate_best_csv_from_tuning "${LOG_DIR_VAL}"
        compute_online_metrics "${LOG_DIR_VAL}" "val" "${train_count}" "${VLABEL}" "${app_name}" "${METRICS_CSV}"
      done
    done

    # Print checkpoint summary (train + val)
    print_online_summary "${METRICS_CSV}" "${train_count}" "${#TRAIN_CONFIGS[@]}" "checkpoint"
  fi
done

# ---- TEST PHASE ----
echo
echo "========================================================================"
echo "  TEST PHASE (${#TEST_CONFIGS[@]} configs, model frozen)"
echo "========================================================================"

# Restore working model path for Mode 4 (frozen) test
XGBOOST_BX_PATH="${WORK_BX}"
XGBOOST_BY_PATH="${WORK_BY}"
XGBOOST_BZ_PATH="${WORK_BZ}"

test_count=0
for grid in "${TEST_CONFIGS[@]}"; do
  IFS=":" read -r GX GY GZ LABEL <<< "${grid}"
  test_count=$((test_count + 1))

  echo
  echo "================================================================="
  echo "  TEST ${test_count}/${#TEST_CONFIGS[@]}: ${LABEL} (${GX}x${GY}x${GZ})"
  echo "================================================================="

  RUN_MODES="0,4"

  # Run appropriate apps based on config type (2D configs have _2d_ in label)
  for app_name in ${RUN_APPS//,/ }; do
    if [[ "${LABEL}" == *"_2d_"* ]]; then
      if ! is_2d_app "${app_name}"; then continue; fi
    else
      if is_2d_app "${app_name}"; then continue; fi
    fi
    local_app_dir=$(get_app_dir "${app_name}")
    run_grid_config "${app_name}" "${local_app_dir}" "${GX}" "${GY}" "${GZ}" "${LABEL}"

    LOG_DIR_TEST="${HOME}/OPS_LOGS/${app_name}_cuda_${LABEL}_${DATE_STAMP}"
    generate_best_csv_from_tuning "${LOG_DIR_TEST}"
    compute_online_metrics "${LOG_DIR_TEST}" "test" "${test_count}" "${LABEL}" "${app_name}" "${METRICS_CSV}"
  done
done

# Print final test summary
print_online_summary "${METRICS_CSV}" "${test_count}" "${#TEST_CONFIGS[@]}" "test"

# Generate loss/accuracy curves
echo
echo "  Generating training curves..."
generate_online_curves "${METRICS_CSV}" "${EXPLORE_RESULTS_DIR}"

# Restore original paths and modes
XGBOOST_BX_PATH="${ML_MODEL_DIR}/xgboost_bx_20260307_153956.json"
XGBOOST_BY_PATH="${ML_MODEL_DIR}/xgboost_by_20260307_153956.json"
XGBOOST_BZ_PATH="${ML_MODEL_DIR}/xgboost_bz_20260307_153956.json"
RUN_MODES="${ORIG_RUN_MODES}"

echo
echo "========================================================================"
echo "  ML-GUIDED EXPLORATION + TRAINING COMPLETE"
echo "========================================================================"
echo "  Train: ${#TRAIN_CONFIGS[@]} configs  Val: ${#VAL_CONFIGS[@]} configs  Test: ${#TEST_CONFIGS[@]} configs"
echo "  Metrics: ${METRICS_CSV}"
echo "  Checkpoints: ${CHECKPOINT_DIR}/"
echo "  Curves: ${EXPLORE_RESULTS_DIR}/loss_curve.png, accuracy_curve.png"
echo "========================================================================"

else

# ============================================================================
# STANDARD GRID STUDY (Modes 0-4, no Mode 5 exploration)
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
echo "All logs saved to: ${HOME}/OPS_LOGS/*_${DATE_STAMP}/"

fi
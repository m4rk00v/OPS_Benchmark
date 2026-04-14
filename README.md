# Description

## Directory Structure
### OPS_AUTO
#### auto_grid.sh
Master orchestration script that automates the execution of CUDA block-size autotuning experiments over applications built with the OPS framework (Oxford Parallel library for Structured mesh solvers). It runs as a SLURM job on a node with an exclusive GPU.

It measures the performance of different CUDA block selection strategies `(bx, by, bz)` across multiple applications and mesh sizes, comparing:

| Mode | Strategy | Description |
|------|----------|-------------|
| 0 | Default | OPS default blocks (baseline) |
| 1 | Dynamic autotuning | Tries all candidates at runtime, picks the best |
| 2 | Precomputed | Reads optimal blocks from a previous CSV (from Mode 1) |
| 4 | XGBoost multi-output | ML model predicts bx, by, bz separately |
| 5 | Online learning | Explores candidates + trains XGBoost incrementally |
| 6 | XGBoost single-output | ML model predicts one of 231 combined (bx,by,bz) classes |

**Flow:**
1. Configure `GPU_TYPE`, `RUN_APPS`, `RUN_MODES` and the grid arrays (`GRIDS_420`, `GRIDS_450`, etc.)
2. Auto-submits to SLURM if not already inside a job
3. Compiles the OPS core library and the selected apps
4. Branches based on mode:
   - **Mode 5 active**: runs the online learning pipeline (train/val/test split, checkpoints, curves)
   - **Any other mode**: runs the standard grid study — iterates each grid config sequentially
5. For each grid config, generates a temporary script (`run_modes.sh`) that executes all selected modes in sequence on the same GPU, captures wall times and computes speedups

**Output structure:**
```
$HOME/OPS_LOGS/
  {app}_cuda_{label}_{date}/
    config.txt              <- wall times, speedups, array stats
    autotune_on/
      ops_blocksize_tuning_logmod.csv   <- all measurements (kernel, bx,by,bz, time)
      ops_blocksize_best_logmod.csv     <- best block per kernel
    autotune_off/
      ops_blocksize_best_logmod.csv     <- times with default blocks
```

**Usage:**
```bash
# 1. Edit configuration in the script:
#    GPU_TYPE="a100"
#    RUN_APPS="cloverleaf"
#    RUN_MODES="0,2"

# 2. Launch (auto-submits to SLURM):
bash $HOME/OPS_AUTO/auto_grid.sh

# 3. Monitor:
tail -f $HOME/OPS_AUTO/auto_grid_history.log
```

**Relationship with ops_util.cpp:** auto_grid.sh sets environment variables (`OPS_AUTOTUNE_MODE`, `OPS_XGBOOST_SINGLE`, `OPS_BLOCKSIZE_CSV`, etc.) that ops_util.cpp reads at runtime to decide which block selection strategy to use inside the CUDA kernel.

##### Running: RUN_APPS, RUN_MODES

`RUN_APPS` selects which applications to build and run. Any combination of:

| App name | Type | Description |
|----------|------|-------------|
| `cloverleaf` | 3D | CloverLeaf 3D hydrodynamics |
| `cloverleaf2d` | 2D | CloverLeaf 2D hydrodynamics |
| `tti` | 3D | TTI seismic wave propagation |
| `maxwell` | 3D | Maxwell FDTD electromagnetics |
| `lattboltz2d` | 2D | Lattice Boltzmann fluid sim |
| `laplace2d` | 2D | Laplace 2D solver |
| `opensbli` | 3D | OpenSBLI TGsym_DP |
| `tgvstorenone` | 3D | TGV StoreNone |
| `tgvstoreall` | 3D | TGV StoreAll |

`RUN_MODES` selects which block selection strategies to compare in a single run. The two most important modes are:

- **Mode 0 (Default):** Runs the application with OPS default block sizes (typically `128x1x1` or `32x4x1`). This is the baseline for speedup calculations. No CSV is written in `autotune_on/`.
- **Mode 1 (Dynamic autotuning):** Exhaustively tries all valid `(bx, by, bz)` candidates for each kernel at runtime. The best block per kernel is selected based on measured execution time. Writes both `ops_blocksize_tuning_logmod.csv` (all measurements) and `ops_blocksize_best_logmod.csv` (best per kernel). This is the primary data collection mode.

Example: `RUN_MODES="0,1"` runs baseline first, then autotuning, and computes the speedup ratio.

### OPS_LOGS

All CSV files are generated at runtime by `ops_util.cpp` inside the CUDA application. When auto_grid.sh runs an app, it sets the environment variable `OPS_LOGS_DIR` to the target directory, and the C++ logging code writes the files there.

#### Dataset

##### Tuning CSV (`ops_blocksize_tuning_logmod.csv`)

One row per (kernel, block config) measurement. Columns extracted from the OPS runtime in `ops_util.cpp`:

| Column | Description |
|--------|-------------|
| `kernel_id` | Unique kernel identifier |
| `bx`, `by`, `bz` | Block dimensions tested |
| `nstencil_args` | Number of stencil arguments |
| `total_bytes` | Total bytes accessed by the kernel |
| `dim` | Dimensionality (1, 2, or 3) |
| `elem_size` | Element size in bytes |
| `size_x`, `size_y`, `size_z` | Array sizes per dimension |
| `d_m_x..z`, `d_p_x..z` | Halo depths (minus/plus) |
| `num_read`, `num_write`, `num_rw` | Argument access counts |
| `grid_x`, `grid_y`, `grid_z` | Grid extent per dimension |
| `max_threads` | Max threads per block for this GPU |
| `n_args_x_offset`, `n_args_y_offset`, `n_args_z_offset` | Argument offset counts |
| `n_args_face`, `n_args_stride`, `n_args_none` | Argument access pattern counts |
| `max_radius_x`, `max_radius_y`, `max_radius_z` | Stencil radii |
| `total_offset_points`, `total_points` | Stencil point counts |
| `ratio_xy`, `ratio_xz` | Grid aspect ratios |
| `bytes_per_point` | Memory per stencil point |
| `is_2d`, `dominant_stencil_axis` | Dimensionality flags |
| `collapse_x`, `collapse_y`, `collapse_z` | Collapsed dimension flags |
| `is_face_access`, `is_high_complexity` | Stencil complexity flags |
| `face_low_args`, `face_high_args` | Face argument counts |
| `stencil_sig` | Stencil signature string |
| `execution_time` | Measured wall time for this block config |
| `default_time` | Wall time with default blocks |
| `best_time` | Best time found so far |
| `label` | Grid configuration label |
| `pred_time`, `pred_rank` | ML prediction time and rank (Mode 5 only) |

##### Best CSV (`ops_blocksize_best_logmod.csv`)

One row per kernel with the best block found. Written by Mode 1 and Mode 5.

| Column | Description |
|--------|-------------|
| `kernel_id` | Unique kernel identifier |
| `bx`, `by`, `bz` | Best block dimensions |
| `best_time` | Fastest execution time |
| `default_time` | Default block time |
| `points` | Total grid points |
| `gpoints_per_s` | Throughput (Gpoints/s) |
| `nargs`, `nstencil_args` | Argument counts |
| `widest_radius` | Max stencil radius |
| `widest_radius_x`, `widest_radius_y`, `widest_radius_z` | Per-axis radii |
| `stencil_sig` | Stencil signature |
| `max_threads_per_block` | GPU thread limit |

##### Autotuning
Data collected with `OPS_AUTOTUNE_MODE=1`. The app explores all valid block candidates per kernel and logs every measurement. This produces the full tuning CSV.

##### Pre-computed
Data used with `OPS_AUTOTUNE_MODE=2`. The app reads the best block per kernel from a previously generated `ops_blocksize_best_logmod.csv` (or `ops_blocksize_tuning_logmod.csv`) and applies those blocks without exploration. The path is set via `OPS_BLOCKSIZE_BASE` in auto_grid.sh.

### ops_util.cpp

Central autotuning logic file in the OPS framework (`$HOME/OPS/ops/c/src/externlib/ops_util.cpp`). Contains block candidate generation, ML inference, CSV logging, and mode dispatching.

#### build_explore_candidates Method

Generates the list of valid CUDA block sizes `(bx, by, bz)` for a given kernel. The algorithm:

```
For a 3D kernel:
  max_x = min(x_extent, 1024)
  max_y = min(y_extent, 1024)
  max_z = min(z_extent, 64)        <- hardware cap: bz <= 64

  For bz = 1, 2, 4, ..., max_z:    <- powers of 2
    For by = 1, 2, 4, ..., max_y:
      For bx = 1, 2, 4, ..., max_x:
        if 32 <= bx*by*bz <= 1024:  <- valid thread count
          add (bx, by, bz) as candidate
```

#### Block Size Classes: 231 Theoretical Maximum

The theoretical maximum of unique `(bx, by, bz)` combinations is **231**, computed from all power-of-2 triples where:
- `bx` in {1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024}
- `by` in {1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024}
- `bz` in {1, 2, 4, 8, 16, 32, 64}
- 32 <= `bx * by * bz` <= 1024

However, reaching all 231 classes depends on the **grid geometry** because the code restricts block dimensions to the kernel's extent sizes (`max_x = min(x_extent, 1024)`, etc.). This means:

```
To reach all 231 classes, a kernel must have:
  x_extent >= 1024   AND
  y_extent >= 1024   AND
  z_extent >= 64

For a single-rank 3D problem of size N^3:
  GX * GY * GZ = N^3    (exact factorization)
  GX >= 1024, GY >= 1024, GZ >= 64

  => N^3 >= 1024 * 1024 * 64 = 67,108,864
  => N >= 407 (minimum)
```

**Geometry limitation examples:**

| Problem size | Total cells | Max Z (with X,Y >= 1024) | Classes | Reaches 231? |
|-------------|-------------|--------------------------|---------|--------------|
| 300^3 | 27,000,000 | 25 (bz max = 16) | ~196 | No |
| 400^3 | 64,000,000 | 61 (< 64) | ~226 | No |
| 420^3 | 74,088,000 | 64 (exact) | 231 | Yes |
| 450^3 | 91,125,000 | 72+ | 231 | Yes |

**GPU limitation:** This constraint is independent of GPU model (V100 vs A100). Both have `max_threads_per_block = 1024`. The limitation comes purely from the problem geometry and MPI decomposition, not from GPU hardware. However, larger problems (420^3+) require more GPU memory, which may only be feasible on A100 (40/80 GB) rather than V100 (16/32 GB).



## Building

auto_grid.sh handles compilation automatically. When launched, it:

1. Compiles the OPS core library:
```bash
cd $HOME/OPS/ops/c && make clean && make -j NV_ARCH={Ampere|Volta}
```

2. Compiles each app listed in `RUN_APPS`:
```bash
cd $HOME/OPS/apps/c/{app_dir} && make clean && make {app}_cuda NV_ARCH={Ampere|Volta}
```

`NV_ARCH` is derived from `GPU_TYPE` in the script (`a100` -> `Ampere`, `v100` -> `Volta`).

Prerequisites: CUDA toolkit, C++ compiler, and OPS dependencies (see https://github.com/OP-DSL/OPS).



## Setting Up Instructions

It is recommended to clone the OPS framework directly from https://github.com/OP-DSL/OPS and follow its build instructions for the applications.

The expected directory structure for `auto_grid.sh` to work:

```
$HOME/
├── OPS/                                    # OPS framework (clone from OP-DSL/OPS)
│   ├── ops/
│   │   └── c/                              # OPS core C library (compiled first)
│   └── apps/
│       └── c/
│           ├── CloverLeaf_3D/              # 3D apps
│           ├── CloverLeaf/                 # 2D app
│           ├── tti/
│           ├── maxwell_fdtd/
│           ├── ops-lbm/step5/             # Lattice Boltzmann 2D
│           ├── laplace2d_tutorial/step7/   # Laplace 2D
│           ├── TGsym_DP/                  # OpenSBLI
│           ├── TGV_StoreNone/
│           └── TGV_StoreAll/
│
├── OPS_AUTO/                               # Orchestration scripts
│   └── auto_grid.sh                        # Main benchmark script
│
├── OPS_LOGS/                               # Output (created at runtime)
│   └── {app}_cuda_{label}_{date}/
│       ├── config.txt
│       ├── autotune_on/
│       │   ├── ops_blocksize_tuning_logmod.csv
│       │   └── ops_blocksize_best_logmod.csv
│       └── autotune_off/
│           └── ops_blocksize_best_logmod.csv
│
└── OPS_DEEP-LEARNING/                      # ML models (only for modes 4, 5, 6)
    └── notes/
        └── models/
            ├── xgboost_bx_*.json           # Mode 4/5: multi-output models
            ├── xgboost_by_*.json
            ├── xgboost_bz_*.json
            └── model_*.json                # Mode 6: single-output model
```

### Step-by-Step Execution Guide

#### Step 1: Select GPU type

Edit two places in `auto_grid.sh`:

```bash
# Line 4 — SLURM resource request (must match GPU_TYPE):
#SBATCH --gres=gpu:a100:1        # or gpu:v100:1

# Line 16 — Script variable:
GPU_TYPE="a100"                   # or "v100"
```

This controls `NV_ARCH` used during compilation (`a100` -> `Ampere`, `v100` -> `Volta`).

#### Step 2: Select applications

Set `RUN_APPS` with a comma-separated list of apps to run:

```bash
# Single app:
RUN_APPS="cloverleaf"

# Multiple apps:
RUN_APPS="cloverleaf,tti,maxwell"

# All apps:
RUN_APPS="cloverleaf,cloverleaf2d,tti,maxwell,lattboltz2d,laplace2d,tgvstorenone,tgvstoreall"
```

**Important:** More apps means longer execution time. Each app runs all selected modes for each grid config.

#### Step 3: Select run modes

Set `RUN_MODES` with the modes to compare:

```bash
# Data collection (baseline + autotuning):
RUN_MODES="0,1"

# Evaluate precomputed blocks against baseline:
RUN_MODES="0,2"

# Compare all strategies:
RUN_MODES="0,1,2,4,6"
```

**Note:** Mode 1 (dynamic autotuning) is the slowest mode because it tests every block candidate per kernel. Mode 0 and Mode 2 are fast.

#### Step 4: Select grid configurations

Uncomment the grid arrays you want to evaluate and comment out the rest. Each array is set to `=()` (empty) when disabled:

```bash
# To DISABLE a grid size — set empty array:
GRIDS_300=()

# To ENABLE a grid size — uncomment the array:
GRIDS_420=(
  "1029:1125:64:420^3_cfg1"
  "1125:1029:64:420^3_cfg2"
)
```

**Consider the following when choosing grids:**

| Factor | Guidance |
|--------|----------|
| 231 classes | Only grids >= 420^3 with X>=1024, Y>=1024, Z>=64 guarantee all 231 block classes |
| SLURM time limit | The job has a maximum of **12 hours** (`#SBATCH --time=12:00:00`). Mode 1 with large grids (420^3+) and multiple apps can easily exceed this |
| Estimation | For CloverLeaf 3D with Mode 0+1 on A100: ~30 min per grid config at 420^3. Plan accordingly |
| 2D grids | 2D grid arrays (`GRIDS_2D_*`) only apply to 2D apps (`cloverleaf2d`, `lattboltz2d`, `laplace2d`). They are ignored if `RUN_APPS` only contains 3D apps |

#### Step 5: Ensure OPS_LOGS is empty

Before each new run, make sure the output directory is empty to avoid mixing data from different experiments:

```bash
# Back up previous results if needed:
mv $HOME/OPS_LOGS $HOME/OPS_LOGS_backup_$(date +%Y%m%d)

# Create a fresh directory:
mkdir -p $HOME/OPS_LOGS
```

If you want to **append** to an existing run instead, set `DATE_STAMP` to the same value as the previous run. By default, the script uses a fixed stamp:

```bash
DATE_STAMP="20260218_141451"  # Fixed: resumes/appends to existing folders
# DATE_STAMP=$(date +%Y%m%d_%H%M%S)  # Uncomment for a fresh timestamp each run
```

#### Step 6: Configure application parameters

Each application has parameters defined in `auto_grid.sh` that control the simulation length. Shorter simulations run faster but may produce less stable timing measurements:

```bash
# CloverLeaf 3D — number of time steps
CLOVER_END_STEP=220

# CloverLeaf 2D — number of time steps
CLOVER2D_END_STEP=300

# Maxwell FDTD — number of timesteps (passed as CLI arg)
MAXWELL_TIMESTEPS=4000

# Lattice Boltzmann 2D — iterations
LBM_ITERATIONS=400

# Laplace2D — iterations
LAPLACE2D_ITERATIONS=400
```

**CloverLeaf-specific:** auto_grid.sh automatically generates the `clover.in` input file for each grid config with the correct `x_cells`, `y_cells`, `z_cells` and `end_step`. No manual file editing is needed for CloverLeaf.

**Other apps (TTI, Maxwell, LBM, Laplace2D, TGV):** Grid dimensions are passed as command-line arguments. No input file generation is needed — auto_grid.sh handles this internally.

**Adding a new app:** If you add a new OPS application, you need to:
1. Add its directory variable (e.g., `NEWAPP_DIR="${OPS_ROOT}/apps/c/newapp"`)
2. Add a build block (`make clean && make newapp_cuda`)
3. Add it to `get_app_dir()` and `is_2d_app()` (if 2D)
4. Add its CLI arguments in the `run_grid_config()` function
5. Add iteration/step variables if applicable

#### Step 7: Launch

```bash
# Simply run the script — it auto-submits to SLURM:
bash $HOME/OPS_AUTO/auto_grid.sh

# Monitor progress:
tail -f $HOME/OPS_AUTO/auto_grid_history.log

# Check SLURM job status:
squeue -u $USER
```

## Limitations

- Reaching all 231 block classes requires problem sizes >= 420^3 (~74M cells), which demands significant GPU memory (A100 40GB+ recommended).
- V100 GPUs (16-32 GB) may not have enough memory for 420^3+ problems, limiting the achievable number of classes.
- The number of classes per kernel varies depending on each kernel's extent dimensions, not just the global grid size.
- Mode 5 (online learning) has a known bug in the test summary output (`print_online_summary` unpacks 2 values from a 5-value return).

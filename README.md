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
### OPS_LOGS
#### Dataset
##### Autotuning
##### Pre-computed
#### Configurations
### OPS
#### Setting OPS
#### apps/c
#### Makefiles

## Autotuning Logic
### ops_util.cpp
### build_explore_candidates Method

## Building


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

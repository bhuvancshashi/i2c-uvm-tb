# I2C Slave – AXI4-Stream UVM Verification Environment

A UVM-based verification environment for an I2C slave controller with
AXI4-Stream data interfaces. The environment drives I2C master traffic onto
the bus, monitors both the I2C and AXI4-Stream sides, and checks data
integrity end-to-end through a scoreboard, with functional coverage
collection for both protocols.

## Architecture

```
                ┌───────────────────────────────────────────┐
                │                  env                       │
                │                                             │
   i2c_agent ──►│  i2c_driver (master BFM) ── i2c_monitor ──►│── i2c_cov_collector
   (active)     │                                             │
                │                                             │
 s_axis_agent──►│  axi_driver ── axi_monitor ────────────────►│── axi_cov_collector
   (active)     │                                             │
                │                                             │
 m_axis_agent──►│  axi_monitor (passive) ────────────────────►│── axi_cov_collector
   (passive)    │                                             │
                │                                             │
                │              i2c_scoreboard                │
                │   (compares I2C transactions vs AXI bytes) │
                └───────────────────────────────────────────┘
                              │
                              ▼
                  ┌─────────────────────────┐
                  │   i2c_slave DUT (RTL)    │
                  │  (AXI4-Stream <-> I2C)   │
                  └─────────────────────────┘
```

**Key components**
- `i2c_driver` — bit-accurate I2C master BFM (START/STOP, clock stretching, repeated start, ACK/NACK handling)
- `axi_driver` / `axi_monitor` — AXI4-Stream source/sink with configurable `tready` backpressure
- `i2c_monitor` — passively reconstructs I2C transactions (address, R/W, data, STOP/repeated-START)
- `i2c_scoreboard` — correlates I2C-side transactions with AXI-side byte streams and checks data integrity
- `i2c_cov_collector` / `axi_cov_collector` — functional coverage (R/W direction, address match/mismatch, burst sizes, backpressure, repeated-start)
- SVA assertions embedded in `i2c_if` and `axi_stream_if` for protocol-level checks (X/Z detection, SDA stability, AXI handshake stability)

## Test Suite

| Test | Description |
|---|---|
| `write_test` | Basic single-byte I2C write |
| `read_test` | Basic I2C read with AXI-side data push |
| `tc06_addr_miss_test` | Address mismatch — DUT must not respond |
| `tc07_addr_mask_test` | Address mask matching |
| `tc08_write_stretch_test` | Clock stretching during write (AXI backpressure) |
| `tc09_read_stretch_test` | Clock stretching during read (AXI data not ready) |
| `tc10_axi_backpressure_test` | Randomized AXI `tready` toggling during write |
| `tc11_repeated_start_test` | Repeated START write-then-read |
| `tc12_rand_burst_write_test` | Randomized burst write lengths |
| `tc13_rand_zero_byte_test` | Zero-byte transaction handling |
| `tc14_rand_early_nack_test` | Early NACK during read |
| `tc15_rand_axi_starvation_test` | AXI source starvation during read |
| `tc16_rand_back_to_back_test` | Back-to-back write/read/write |
| `tc17_rand_sr_stress_test` | Repeated-start stress (randomized sizes) |
| `tc18_rand_max_stress_test` | Max burst writes with randomized backpressure |
| `tc20_nack_stop_test` | NACK recovery and bus re-use |
| `tc21_data_integrity_test` | Walking-ones data pattern integrity check |
| `tc22_continuous_stream_test` | Back-to-back continuous write stream |
| `tc23_extreme_backpressure_test` | Extended AXI backpressure during write |
| `tc25_stop_mid_transfer_test` | Early STOP mid-transfer, recovery check |
| `tc26_missing_stop_recovery_test` | Missing STOP, recovery via next transaction |

## Repository Structure

```
i2c-uvm-tb/
├── rtl/
│   └── i2c_slave.v          # DUT (see Acknowledgements)
├── tb/
│   ├── tb_top.sv             # Top-level testbench module
│   ├── include/
│   │   └── tb_pkg.sv          # UVM package, includes all TB source
│   └── src/
│       ├── interfaces.sv      # i2c_if, axi_stream_if (+ SVA)
│       ├── transactions.sv    # i2c_seq_item, axi_stream_seq_item
│       ├── sequences.sv       # All sequence classes
│       ├── drivers_monitors.sv# i2c_driver/monitor, axi_driver/monitor
│       ├── agents_env_sb.sv   # Sequencers, agents, scoreboard, env
│       ├── coverage.sv        # Functional coverage collectors
│       └── tests.sv           # base_test + all tc*/write/read tests
├── sim/
│   └── Makefile               # VCS / Questa / Xcelium run targets
└── .gitignore
```

## Running Simulations

From the `sim/` directory:

```bash
# VCS (default)
make vcs TEST=write_test

# Questa/ModelSim
make questa TEST=tc21_data_integrity_test

# Xcelium
make xrun TEST=tc11_repeated_start_test

# specify a seed
make vcs TEST=tc12_rand_burst_write_test SEED=42
```

Waveforms are dumped to `dump.vcd` via `$dumpfile`/`$dumpvars` in `tb_top.sv`.

## Acknowledgements

The DUT (`rtl/i2c_slave.v`) is sourced from
[alexforencich/verilog-i2c](https://github.com/alexforencich/verilog-i2c),
licensed under the MIT License. All UVM verification IP in this repository
(testbench, interfaces, sequences, drivers, monitors, scoreboard, coverage
models, and tests) is original work.

Note: the upstream repository is deprecated; ongoing development continues at
[fpganinja/taxi](https://github.com/fpganinja/taxi).

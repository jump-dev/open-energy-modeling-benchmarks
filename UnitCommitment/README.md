# UnitCommitment.jl

UnitCommitment.jl (UC.jl) is an optimization package for the
Security-Constrained Unit Commitment Problem (SCUC), a fundamental optimization
problem in power systems used, for example, to clear the day-ahead electricity
markets. The package provides benchmark instances for the problem and Julia/JuMP
implementations of state-of-the-art mixed-integer programming formulations.

More details are available at [https://github.com/ANL-CEEESA/UnitCommitment.jl](https://github.com/ANL-CEEESA/UnitCommitment.jl)

Documentation is available at: [https://anl-ceeesa.github.io/UnitCommitment.jl/](https://anl-ceeesa.github.io/UnitCommitment.jl/)

The GitHub repository is [https://github.com/ANL-CEEESA/UnitCommitment.jl](https://github.com/ANL-CEEESA/UnitCommitment.jl)

## License

UnitCommitment license can be found at [https://github.com/ANL-CEEESA/UnitCommitment.jl/blob/dev/LICENSE.md](https://github.com/ANL-CEEESA/UnitCommitment.jl/blob/dev/LICENSE.md).

## Structure

The script in `main.jl` was inspired in code extracted from the documentation.

## Notes

This package add network constraints (including contigencies) iteratively.
Hence, the JuMP model built with `UnitCommitment.build_model` contains no
network constraints and, consequently, solving this model with
`JuMP.optimize!` tipically solves a simpler problem. On the other hand,
instances generated after the first round of adding network constraints
tend to have the same difficulty level. This requires
`UnitCommitment.optimize!`. However, there is no control to stop right after
the first iteration, so we attempt to emulate such procedure by setting a time
limit of 600s for both the algorithm and the HiGHS solver and a tight gap.
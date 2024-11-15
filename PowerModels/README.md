# PowerModels

PowerModels.jl is a Julia/JuMP package for Steady-State Power Network
Optimization. It is designed to enable computational evaluation of emerging
power network formulations and algorithms in a common platform. The code is
engineered to decouple problem specifications (e.g. Power Flow, Optimal Power
Flow, ...) from the power network formulations (e.g. AC, DC-approximation,
SOC-relaxation, ...). This enables the definition of a wide variety of power
network formulations and their comparison on common problem specifications.

More details are available at [https://github.com/lanl-ansi/PowerModels.jl](https://github.com/lanl-ansi/PowerModels.jl)

Documentation is available at: [https://lanl-ansi.github.io/PowerModels.jl/stable/](https://lanl-ansi.github.io/PowerModels.jl/stable/)

The GitHub repository is [https://github.com/lanl-ansi/PowerModels.jl](https://github.com/lanl-ansi/PowerModels.jl)

## License

PowerModels license can be found at [https://github.com/lanl-ansi/PowerModels.jl/blob/master/LICENSE.md](https://github.com/lanl-ansi/PowerModels.jl/blob/master/LICENSE.md).

## Structure

As the focus of Open Energy Modeling Benchmarks is MIPs, the current code for
PowerModels only considers the Optimal Transmission Switching (OTS) problems.
Another class of MIPs in PowerModels is Transmission Network Expansion Planning
(TNEP), but there are no available instances.

All instances were obtanied from [Power Grid Lib - Optimal Power Flow](https://github.com/power-grid-lib/pglib-opf)
benchmark library.

# TulipaEnergyModel

TulipaEnergyModel is an optimization model for the electricity market and its
coupling with other energy sectors (e.g., hydrogen, heat, natural gas, etc.).
The main objective is to determine the optimal investment and operation
decisions for different types of assets (e.g., producers, consumers,
conversions, storages, and transports).

More details are available at [https://github.com/TulipaEnergy/TulipaEnergyModel.jl](https://github.com/TulipaEnergy/TulipaEnergyModel.jl)

Documentation is available at: [https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable)

The GitHub organization is [https://github.com/TulipaEnergy](https://github.com/TulipaEnergy)

## License

TulipaEnergyModel is licensed under the [Apache License 2.0](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/blob/main/LICENSE).

## Structure

The example cases in this directory are taken from [https://github.com/TulipaEnergy/TulipaEnergyModel.jl/tree/main/benchmark/EU](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/tree/main/benchmark/EU) 

The EU case is a stylized European-level investment and operation modified to consider integer investments and unit commitment variables. In addition, the code at `main.jl` modifies the timesteps to consider different problem sizes ranging from a day to a year.

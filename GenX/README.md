# GenX

GenX is a configurable power system capacity expansion model.

More details are available at [https://genx.mit.edu](https://genx.mit.edu)

Documentation is available at [genxproject.github.io/GenX.jl/](genxproject.github.io/GenX.jl/)

The GitHub repository is [GenXProject/GenX.jl](https://github.com/GenXProject/GenX.jl)

## License

GenX is licensed under the [GPL v2 license](https://github.com/GenXProject/GenX.jl/blob/v0.4.1/LICENSE).

## Structure

The example cases in this directory are taken from
[https://github.com/GenXProject/GenX.jl/tree/v0.4.1/example_systems](https://github.com/GenXProject/GenX.jl/tree/v0.4.1/example_systems).

Cases were modified. Main change is setting `UCommit: 1` to consider unit commitment of operation
variables, which is the source of integrality in GenX. Other modifications include changes in
HiGHS parameters to generate the mps files quicker and disabling extra solves for writing prices.

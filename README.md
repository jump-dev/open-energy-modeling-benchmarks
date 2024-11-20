# open-energy-modeling-benchmarks

The purpose of this repository is to collate a collection of benchmarks related
to open energy modeling in JuMP. These benchmarks will be used to improve JuMP
and HiGHS.

This repository is part of our [Open-Energy-Modeling](https://jump.dev/announcements/open-energy-modeling/2024/09/16/oem/)
project.

For suggestions and feedback, please open a GitHub issue.

## License

This repository is licensed under the [MIT license](https://github.com/jump-dev/open-energy-modeling-benchmarks/blob/main/LICENSE.md).

## Structure

This repository is organized as follows:

 * `/benchmark`: scripts to run any required benchmarking experiments
 * `/instances`: a collection of MPS for benchmarking. Files in this directory
   are gzipped with the default `gzip <file.mps>`. Filenames are composed by
   two pieces `[PREFIX]-[SHA256]` where `[SHA256]` is the SHA256 of
   the uncompressed MPS file (to mitigate against potential differences in
   `gzip` settings), and `[PREFIX]` is a name that can be used to
   trace the origin of that particular model. If no prefix was defined it
   falls back to `UNNAMED`. By default, models in this
   directory are not included by git. Add them with `git add -f instances/*`.
 * `/GenX`: case studies and scripts to run models built with GenX.
 * `/PowerModels`: case studies and scripts to run models built with
 PowerModels.
 * `/Sienna`: case studies and scripts to run models built with Sienna.
 * `/TulipaEnergyModel`: case studies and scripts to run models built with
 TulipaEnergyModel.
 * `Makefile`: a top-level makefile to automate rebuilding the instances, and
   any other tasks that we end up needed to repeat regularly.

## Usage instructions

Rebuild all instances with:

```
make all
```

### GenX

For now, we can rebuild all of the GenX examples with (from the root of this
directory):

```
make genx
```

To run a particular case, do:

```
julia --project=GenX GenX/main.jl --case=1_three_zones --run [--write]
```

See the `GenX/main.jl` driver script for more details.

### PowerModels

For now, we can rebuild all of the PowerModels examples with (from the root of
this directory):

```
make powermodels
```

To run a particular case, do:

```
julia --project=PowerModels PowerModels/main.jl --case=pglib_opf_case1951_rte.m --run [--write]
```

See the `PowerModels/main.jl` driver script for more details.

### Sienna

For now, we can rebuild all of the Sienna examples with (from the root of this
directory):

```
make sienna
```

To run a particular case, do:

```
julia --project=Sienna Sienna/tutorial_1.jl --case=PTDF-12 --run [--write]
```

See the `Sienna/tutorial_1.jl` driver script for more details.

### SpineOpt

For now, we can rebuild all of the SpineOpt examples with (from the
root of this directory):

```
make spineopt
```

To run a particular case, do:

```
julia --project=SpineOpt SpineOpt/main.jl --case=1_electrolyzer_with_rolling_horizon.json --run [--write]
```

See the `SpineOpt/main.jl` driver script for more details.

* SpineOpt requires a python installation and additional install steps.
See the [SpineOpt/README](https://github.com/jump-dev/open-energy-modeling-benchmarks/blob/main/SpineOpt/README.md).


### TulipaEnergyModel

For now, we can rebuild all of the TulipaEnergyModel examples with (from the
root of this directory):

```
make tulipaenergymodel
```

To run a particular case, do:

```
julia --project=TulipaEnergyModel TulipaEnergyModel/main.jl --case=1_EU_investment_simple --run [--write]
```

See the `TulipaEnergyModel/main.jl` driver script for more details.
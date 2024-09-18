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
   are gzipped with the default `gzip <file.mps>`. Filenames are the SHA256 of
   the uncompressed MPS file (to mitigate against potential differences in
   `gzip` settings), followed by `-`, followed by a suffix that can be used to
   trace the origin of that particular model. By default, models in this
   directory are not included by git. Add them with `git add -f instances/*`.
 * `/GenX`: case studies and scripts to run models built with GenX.
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

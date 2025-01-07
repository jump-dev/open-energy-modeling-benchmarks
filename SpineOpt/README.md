# SpineOpt

SpineOpt.jl is an integrated energy systems optimization model part of the Spine Tools organization, striving towards adaptability for a multitude of modelling purposes.
The data-driven model structure allows for highly customizable energy system descriptions, as well as flexible temporal and stochastic structures, without the need to alter the model source code directly. The methodology is based on mixed-integer linear programming (MILP).

More details are available at [https://github.com/spine-tools](https://github.com/spine-tools)

Documentation is available at: [https://spine-tools.github.io/SpineOpt.jl/stable/](https://spine-tools.github.io/SpineOpt.jl/stable/)

The GitHub repository is [https://github.com/spine-tools/SpineOpt.jl](https://github.com/spine-tools/SpineOpt.jl)

## License

SpineOpt license can be found at [https://github.com/spine-tools/SpineOpt.jl/blob/master/LICENSE](https://github.com/spine-tools/SpineOpt.jl/blob/master/LICENSE.md).

## Structure

* `install_spinedb_api.jl` is used to install python dependencies
* `main.jl` is responsible for running the cases from `cases` folder.
* Case studies were shared by SpineOpt users and represent different energy
model applications that can modeled as MIP problems.

## Installing

SpineOpt requires not only Julia but also Python. So make sure you have a
Python3 installation.

* start a Julia session
* run `install_spinedb_api.jl` to install the python dependencies
* finish the Julia session

Now you will be able to use `main.jl` in new Julia sessions.

### Notes

Python version used 3.12

You might also need a PostgresSQL install to use `pg_config`,
which is necessary to compile [`psycopg2`](https://www.psycopg.org/docs/install.html#prerequisites),
which is necessary to use [`spinedb_api`](https://pypi.org/project/spinedb-api/).
* Linux: `apt install libpq-dev`
* Mac: `brew install postgresql` or `sudo port install postgresql`
* Windows: use the installer https://www.postgresql.org/download/windows/

## Warning

SpineOpt instances are non-deterministic. Every different run of the `main.jl`
script leads to a new mps files. From a first pass on the files its seem that
the only change is the order of the constraints. However, this apparently simple
change can lead to different solve times and *very* different solutions.
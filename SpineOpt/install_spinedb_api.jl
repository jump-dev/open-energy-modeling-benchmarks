# Copyright (c) 2024: Oscar Dowson, Joaquim Garcia and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

# Based in: https://github.com/spine-tools/SpineOpt.jl/blob/739baf636a4b8127172df174aca73e24c895c0bf/.install_spinedb_api.jl

cd(@__DIR__)
using Pkg
Pkg.activate(".")
using PyCall
@show python = PyCall.pyprogramname
run(`$python -m pip install --user setuptools-scm`)
run(`$python -m pip install --user git+https://github.com/spine-tools/Spine-Database-API`)
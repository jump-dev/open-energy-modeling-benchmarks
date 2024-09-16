# Copyright (c) 2024: Oscar Dowson, Joaquim Garcia and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

default: help

help:
	@echo "The following make commands are available:"
	@echo "  genx   	write all GenX instances"
	@echo "  benchmark  run a new set of benchmarks"
	@echo "  analyze   	print analysis of output"
	@echo "  all    	re-run all commands"

genx:
	julia --project=GenX GenX/main.jl --all --run --write

benchmark:
	julia --project=benchmark benchmark/main.jl --all

analyze:
	julia --project=benchmark benchmark/main.jl --analyze

all: genx

.PHONY: default help genx benchmark analyze

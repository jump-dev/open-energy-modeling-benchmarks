# Copyright (c) 2024: Oscar Dowson, Joaquim Garcia and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

function _parse_args(args)
    ret = Dict{String,String}()
    for arg in args
        if (m = match(r"--([a-z]+)=(.+?)($|\s)", arg)) !== nothing
            ret[m[1]] = m[2]
        elseif (m = match(r"--([a-z]+?)($|\s)", arg)) !== nothing
            ret[m[1]] = "true"
        else
            error("unsupported argument $arg")
        end
    end
    return ret
end

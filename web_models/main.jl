# Copyright (c) 2024: Oscar Dowson, Joaquim Garcia and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

import Downloads
import HiGHS
import SHA

function url_to_instance(url; suffix)
    instances = joinpath(dirname(@__DIR__), "instances")
    tmp_filename = joinpath(instances, "tmp.mps")
    highs = HiGHS.Highs_create()
    Downloads.download(url, tmp_filename)
    HiGHS.Highs_readModel(highs, tmp_filename)
    HiGHS.Highs_writeModel(highs, tmp_filename)
    HiGHS.Highs_destroy(highs)
    # We SHA the raw file so that potential gzip differences across
    # platforms don't matter.
    hex = bytes2hex(open(SHA.sha256, tmp_filename))
    run(`gzip $tmp_filename`)
    mv(
        "$(tmp_filename).gz",
        joinpath(instances, "$hex-$suffix.mps.gz");
        force = true,
    )
    return
end

function rebuild_miplib2017()
    io = IOBuffer()
    Downloads.download("https://miplib.zib.de/downloads/benchmark-v2.test", io)
    seekstart(io)
    for model in readlines(io)
        url = "https://miplib.zib.de/WebData/instances/$model"
        suffix = replace("MIPLIB2017_$model", ".mps.gz" => "")
        url_to_instance(url; suffix)
    end
    return
end

# url_to_instance(
#     "https://gist.github.com/sstroemer/07406d9422993aab2ee4d2fbd3ee8a8c/raw/ed1abeb670bed3c487011f87171aa766d23571fc/mwe.mps";
#     suffix = "sstroemer",
# )

# rebuild_miplib2017()

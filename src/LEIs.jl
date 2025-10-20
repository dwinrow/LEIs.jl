module LEIs

using HTTP
using JSON3
using ProgressBars
using Scratch

export LEI, LEI_Info, category, subcategory, jurisdiction

const url_lei = "https://api.gleif.org/api/v1/lei-records/"

struct LEI
    lei::Symbol
end
LEI(x::AbstractString) = LEI(Symbol(x))

struct LEI_Info
    lei::AbstractDict
end
LEI_Info(x::Union{AbstractString,Symbol}) = LEI_Info(LEI(x))
LEI_Info(x::LEI) = LEI_Info(lei(x.lei))

function __init__()
    global leidict = Dict{LEI,LEI_Info}()
    loadcaches()
end

function savecache(d = leidict, p = "leis.json")
    cachepath = joinpath(@get_scratch!("caches"),p)
    JSON3.write(cachepath,[lei.lei => info.lei for (lei,info) in d])
end

function removecache(p = "leis2.json")
    cachepath = joinpath(@get_scratch!("caches"),p)
    isfile(cachepath) && rm(cachepath)
end

function loadcaches()
    cachepath = joinpath(@get_scratch!("caches"),"leis.json")
    if isfile(cachepath)
        j = JSON3.read(cachepath)
        global leidict = Dict(LEI(key) => LEI_Info(val) for (key,val) in j)
    else
        @warn "No cache on disk, try LEIs.savecaches()"
    end
end

lei(x::Union{AbstractString,Symbol,Missing}) = lei(LEI(x))
function lei(lei::LEI)
    ismissing(x) && return missing
    if haskey(leidict,lei.lei)
        leidict[lei.lei]
    else
        try
            leidict[lei.lei] = get(lei)
        catch
            missing
        end
    end
end

function get(lei::LEI)
    r = HTTP.get(url_lei*string(lei.lei))
    r.body |> String |> JSON3.read
end

bulkaddleis(leis::Vector{Union{AbstractString,Symbol}}) = bulkaddleis(LEI.(leis))
function bulkaddleis(leis::Vector{LEI})

    global leidict 
    
    # A second dictionary is needed because adding keys to a large dictionary is slow
    leidict2 = Dict()

    for (i,lei) in ProgressBar(enumerate(leis))
        if !haskey(leidict,lei) && !haskey(leidict2,lei)
            try
                leidict2[lei] = get(lei)
            catch
            end
        end
        if i % 25 == 0
            savecache(leidict2,"leis2.json")
        end
    end

    if !isempty(leidict2)
        leidict = merge(copy(leidict),leidict2)
        savecache()
        removecache("leis2.json")
    end

end

category(lei::LEI_Info) = lei.lei[:data][:attributes][:entity][:category]
category(lei::LEI) = category(LEI_Info(lei))
category(lei::Union{AbstractString,Symbol}) = category(LEI(lei))
category(lei::Missing) = missing

subcategory(lei::LEI_Info) = lei.lei[:data][:attributes][:entity][:subCategory]
subcategory(lei::LEI) = subcategory(LEI_Info(lei))
subcategory(lei::Union{AbstractString,Symbol}) = subcategory(LEI(lei))
subcategory(lei::Missing) = missing

jurisdiction(lei::LEI_Info) = lei.lei[:data][:attributes][:entity][:jurisdiction]
jurisdiction(lei::LEI) = jurisdiction(LEI_Info(lei))
jurisdiction(lei::Union{AbstractString,Symbol}) = jurisdiction(LEI(lei))
jurisdiction(lei::Missing) = missing

end # module LEIs
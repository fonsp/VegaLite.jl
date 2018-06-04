###############################################################################
#
#   Definition of VLSpec type and associated functions
#
###############################################################################

struct VLSpec{T}
    params::Union{Dict, Vector}
end
vltype(::VLSpec{T}) where T = T

function (p::VLSpec{:plot})(data)
    if data isa AbstractPath
        new_dict = copy(p.params)

        as_uri = string(URI(data))

        # TODO This is a hack that might only work on Windows
        # Vega seems to not understand properly formed file URIs
        new_dict["data"] = Dict{String,Any}("url" => is_windows() ? as_uri[1:5] * as_uri[7:end] : as_uri)

        return VLSpec{:plot}(new_dict)
    elseif TableTraits.isiterabletable(data)
        it = IteratorInterfaceExtensions.getiterator(data)

        col_names = TableTraits.column_names(it)
        col_types = TableTraits.column_types(it)
        col_type_mapping = Dict{Symbol,Type}(i[1]=>i[2] for i in zip(col_names,col_types))
        
        recs = [Dict(c[1]=>isa(c[2], DataValues.DataValue) ? (isnull(c[2]) ? nothing : get(c[2])) : c[2] for c in zip(keys(r), values(r))) for r in it]

        new_dict = copy(p.params)
        new_dict["data"] = Dict{String,Any}("values" => recs)

        if haskey(new_dict, "encoding")
            for (k,v) in new_dict["encoding"]
                if !haskey(v, "type")
                    if !haskey(v, "aggregate") && haskey(v, "field") && haskey(col_type_mapping,Symbol(v["field"]))
                        jl_type = col_type_mapping[Symbol(v["field"])]
                        if jl_type <: DataValues.DataValue
                            jl_type = eltype(jl_type)
                        end
                        if jl_type <: Number
                            v["type"] = "quantitative"
                        elseif jl_type <: AbstractString
                            v["type"] = "nominal"
                        elseif jl_type <: Base.Dates.AbstractTime
                            v["type"] = "temporal"
                        end
                    end
                end
            end
        end

        return VLSpec{:plot}(new_dict)
    else
        throw(ArgumentError("'data' is not a table."))
    end
end

function (p::VLSpec{:plot})(uri::URI)
    new_dict = copy(p.params)
    new_dict["data"] = Dict{String,Any}("url" => string(uri))

    return VLSpec{:plot}(new_dict)
end

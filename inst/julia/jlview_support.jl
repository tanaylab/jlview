# inst/julia/jlview_support.jl

module JlviewSupport

using SparseArrays

# ── Pin/Unpin infrastructure ──

const PINNED = Dict{UInt64, Any}()
const PINNED_BYTES = Dict{UInt64, Int}()
const PINNED_LOCK = ReentrantLock()
const _next_pin_id = Ref{UInt64}(0)

struct PinInfo
    id::UInt64
    ptr::Ptr{Cvoid}
    nbytes::Int
    eltype_code::Int     # 1=Float64, 2=Int32, 3=UInt8, ...
    ndims::Int
    dims::Vector{Int}
end

# Element type codes for C layer
const ELTYPE_FLOAT64 = 1
const ELTYPE_INT32   = 2
const ELTYPE_UINT8   = 3

function eltype_code(::Type{Float64}) ELTYPE_FLOAT64 end
function eltype_code(::Type{Int32})   ELTYPE_INT32 end
function eltype_code(::Type{UInt8})   ELTYPE_UINT8 end

"""
Pin an array in memory (prevent GC) and return metadata for ALTREP construction.
Thread-safe: all Dict operations protected by PINNED_LOCK.
"""
function pin(array::AbstractArray{T,N}) where {T,N}
    # Convert to contiguous Array if needed (e.g., views, reshaped arrays)
    if !isa(array, Array)
        array = collect(array)
    end

    ptr = Ptr{Cvoid}(pointer(array))  # safe: array is on the stack
    nb = sizeof(array)
    dims = collect(size(array))
    ec = eltype_code(T)

    id = lock(PINNED_LOCK) do
        id = (_next_pin_id[] += 1)
        PINNED[id] = array
        PINNED_BYTES[id] = nb
        id
    end

    return PinInfo(id, ptr, nb, ec, N, dims)
end

# Specializations for types that need conversion
function pin(array::Array{Float32,N}) where N
    converted = Array{Float64}(array)
    return pin(converted)
end

const INT64_SAFE_MAX = Int64(2)^53 - 1
const INT64_SAFE_MIN = -(Int64(2)^53 - 1)

function pin(array::Array{Int64,N}) where N
    # Warn if values exceed Float64's exact integer range
    if length(array) > 0
        lo, hi = extrema(array)
        if lo < INT64_SAFE_MIN || hi > INT64_SAFE_MAX
            @warn "jlview: Int64 array contains values outside Float64's exact " *
                  "integer range (|x| > 2^53-1). Precision loss will occur." *
                  " min=$lo max=$hi"
        end
    end
    converted = Array{Float64}(array)
    return pin(converted)
end

function pin(array::Array{Int16,N}) where N
    converted = Array{Int32}(array)
    return pin(converted)
end

function pin(array::Array{UInt8,N}) where N
    converted = Array{Int32}(array)
    return pin(converted)
end

# Bool is NOT handled by pin(). Bool arrays use the fallback path in R
# (julia_call("collect", ..., need_return = "R") → standard LGLSXP copy).
# See §6.4: layout is incompatible, copy is unavoidable, no ALTREP benefit.

"""
Unpin an array, allowing Julia GC to collect it.
Returns number of bytes freed. Thread-safe.
"""
function unpin(id::UInt64)::Int
    lock(PINNED_LOCK) do
        nb = get(PINNED_BYTES, id, 0)
        delete!(PINNED, id)
        delete!(PINNED_BYTES, id)
        nb
    end
end

"""
Strip wrappers (ReadOnly, Named, etc.) to get the underlying array.
Depth-limited to prevent infinite loops from circular wrapper chains.
"""
function unwrap(array::AbstractArray; max_depth::Int=16)
    for _ in 1:max_depth
        p = try parent(array) catch; break end
        p === array && break
        array = p
    end
    return array
end

"""
Check if a Julia object is a supported array type for zero-copy.
Returns: (supported::Bool, eltype_name::String, ndims::Int)
"""
function check_support(obj)
    arr = unwrap(obj)
    T = eltype(arr)
    N = ndims(arr)

    # Direct zero-copy types (UInt8/RAWSXP not yet implemented in C layer)
    if T in (Float64, Int32)
        return (true, string(T), N)
    end
    # Conversion types (one copy in Julia, then zero-copy to R)
    # Bool excluded: layout incompatible (1 byte vs 4 bytes), no ALTREP benefit.
    # Falls through to JuliaCall's collect path which produces LGLSXP.
    if T in (Float32, Int64, Int16, UInt8)
        return (true, string(T), N)
    end
    return (false, string(T), N)
end

"""
Report total bytes currently pinned. Thread-safe.
"""
function pinned_bytes()::Int
    lock(PINNED_LOCK) do
        sum(values(PINNED_BYTES); init=0)
    end
end

"""
Report number of currently pinned arrays. Thread-safe.
"""
function pinned_count()::Int
    lock(PINNED_LOCK) do
        length(PINNED)
    end
end

# ── Sparse matrix support ──

struct SparsePinInfo
    nzval_pin::PinInfo
    rowval_pin_id::UInt64
    rowval_ptr::Ptr{Cvoid}
    rowval_len::Int
    rowval_is_int64::Bool
    colptr_pin_id::UInt64
    colptr_ptr::Ptr{Cvoid}
    colptr_len::Int
    colptr_is_int64::Bool
    nrow::Int
    ncol::Int
end

"""
Pin a sparse index array (rowval or colptr) and return metadata for
C_jlview_create_index. Returns (pin_id, length, is_int64) as a tuple.
"""
function pin_index(arr::Vector{Ti}) where Ti <: Integer
    ptr = Ptr{Cvoid}(pointer(arr))
    nb = sizeof(arr)
    is_int64 = (Ti === Int64)

    id = lock(PINNED_LOCK) do
        id = (_next_pin_id[] += 1)
        PINNED[id] = arr
        PINNED_BYTES[id] = nb
        id
    end

    return (id, length(arr), is_int64)
end

"""
Extract the colptr field from a SparseMatrixCSC.
"""
_get_colptr(m::SparseMatrixCSC) = m.colptr

function pin_sparse(matrix::SparseMatrixCSC{Tv,Ti}) where {Tv,Ti}
    # Pin nzval using existing pin() (handles type conversion)
    nzval_info = pin(nonzeros(matrix))

    # Pin rowval (indices) - just hold reference, no conversion
    rowval = rowvals(matrix)
    rowval_ptr = Ptr{Cvoid}(pointer(rowval))
    rowval_nb = sizeof(rowval)
    rowval_is_int64 = (Ti === Int64)

    rowval_id = lock(PINNED_LOCK) do
        id = (_next_pin_id[] += 1)
        PINNED[id] = rowval
        PINNED_BYTES[id] = rowval_nb
        id
    end

    # Pin colptr
    colptr = matrix.colptr
    colptr_ptr = Ptr{Cvoid}(pointer(colptr))
    colptr_nb = sizeof(colptr)
    colptr_is_int64 = (Ti === Int64)

    colptr_id = lock(PINNED_LOCK) do
        id = (_next_pin_id[] += 1)
        PINNED[id] = colptr
        PINNED_BYTES[id] = colptr_nb
        id
    end

    return SparsePinInfo(
        nzval_info,
        rowval_id, rowval_ptr, length(rowval), rowval_is_int64,
        colptr_id, colptr_ptr, length(colptr), colptr_is_int64,
        size(matrix, 1), size(matrix, 2)
    )
end

function check_support(obj::SparseMatrixCSC)
    T = eltype(obj)
    if T in (Float64, Int32, Float32, Int64, Int16, UInt8)
        return (true, string(T), 2)
    end
    return (false, string(T), 2)
end

# ── Summary statistics (called from C ALTREP Sum/Min/Max methods) ──

function pinned_sum(id::UInt64)::Float64
    arr = lock(PINNED_LOCK) do; get(PINNED, id, nothing); end
    arr === nothing && error("array not pinned")
    return sum(Float64, arr)
end

function pinned_minimum(id::UInt64)::Float64
    arr = lock(PINNED_LOCK) do; get(PINNED, id, nothing); end
    arr === nothing && error("array not pinned")
    return Float64(minimum(arr))
end

function pinned_maximum(id::UInt64)::Float64
    arr = lock(PINNED_LOCK) do; get(PINNED, id, nothing); end
    arr === nothing && error("array not pinned")
    return Float64(maximum(arr))
end

end # module JlviewSupport

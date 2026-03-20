# inst/julia/jlview_support.jl

module JlviewSupport

using SparseArrays
using Statistics

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

function eltype_code(::Type{Float64}) ELTYPE_FLOAT64 end
function eltype_code(::Type{Int32})   ELTYPE_INT32 end

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

function pin(array::Array{UInt16,N}) where N
    converted = Array{Int32}(array)
    return pin(converted)
end

function pin(array::Array{UInt64,N}) where N
    # Warn if values exceed Float64's exact integer range
    if length(array) > 0
        hi = maximum(array)
        if hi > UInt64(2)^53 - 1
            @warn "jlview: UInt64 array contains values outside Float64's exact " *
                  "integer range (> 2^53-1). Precision loss will occur." *
                  " max=$hi"
        end
    end
    converted = Array{Float64}(array)
    return pin(converted)
end

function pin(array::Array{UInt32,N}) where N
    # UInt32 and Int32 have identical 4-byte memory layout.
    # For UMI counts (always ≤ 2^31-1), the bit pattern is the same.
    # Warn if any value exceeds typemax(Int32) — these will wrap to negative in R.
    if length(array) > 0
        hi = maximum(array)
        if hi > typemax(Int32)
            @warn "jlview: UInt32 array contains values > typemax(Int32) ($(Int64(hi))). " *
                  "These will appear as negative integers in R."
        end
    end
    # True zero-copy: pin the original UInt32 array but report as Int32.
    # UInt32 and Int32 share the same 4-byte layout, so the C ALTREP layer
    # reads the bytes correctly as INTSXP elements.
    ptr = Ptr{Cvoid}(pointer(array))
    nb = sizeof(array)
    dims = collect(size(array))

    id = lock(PINNED_LOCK) do
        id = (_next_pin_id[] += 1)
        PINNED[id] = array          # prevent GC of the original UInt32 array
        PINNED_BYTES[id] = nb
        id
    end

    return PinInfo(id, ptr, nb, ELTYPE_INT32, N, dims)
end

# Bool is NOT handled by pin(). Bool arrays use the fallback path in R
# (julia_call("collect", ..., need_return = "R") → standard LGLSXP copy).
# Layout is incompatible (1 byte vs 4 bytes), copy is unavoidable, no ALTREP benefit.

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
    if T in (Float32, Int64, Int16, UInt8, UInt16, UInt32, UInt64)
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

"""
Copy a Julia index array to a new Int32 array shifted by -1 (Julia 1-based to R 0-based).
Used for sparse matrix rowval and colptr.
"""
function copy_shift_index(arr::Vector{Ti}) where Ti <: Integer
    result = Vector{Int32}(undef, length(arr))
    @inbounds for i in eachindex(arr)
        result[i] = Int32(arr[i] - 1)
    end
    return result
end

"""
Extract the colptr field from a SparseMatrixCSC.
"""
_get_colptr(m::SparseMatrixCSC) = m.colptr

"""
Get nzval as Float64 array. If already Float64, returns the same array.
Otherwise converts to Float64 (one copy in Julia, then zero-copy to R).
"""
function sparse_nzval_as_float64(m::SparseMatrixCSC{Tv,Ti}) where {Tv,Ti}
    nzv = nonzeros(m)
    if Tv === Float64
        return nzv
    else
        return Vector{Float64}(nzv)
    end
end

function check_support(obj::SparseMatrixCSC)
    T = eltype(obj)
    if T in (Float64, Int32, Float32, Int64, Int16, UInt8, UInt16, UInt32, UInt64)
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

# ── Transform operations (compute on pinned arrays, return new Julia array) ──

"""
Compute log2(x .+ scalar) on a pinned array and return the result array.
The input array is looked up by pin_id from the PINNED dict.
The caller is responsible for pinning the result (e.g., via jlview()).
"""
function transform_log2p(id, scalar::Real)
    uid = UInt64(id)
    arr = lock(PINNED_LOCK) do
        get(PINNED, uid, nothing)
    end
    arr === nothing && error("array not pinned (id=$uid)")
    return log2.(Float64.(arr) .+ Float64(scalar))
end

"""
Sweep a summary statistic from a pinned matrix via broadcast operations.
Margin 1 = rows, margin 2 = columns. Op is one of "/", "*", "-", "+".
The input array is looked up by pin_id from the PINNED dict.
The caller is responsible for pinning the result (e.g., via jlview()).
"""
function transform_sweep(id, stats::Vector{Float64}, margin::Int, op::String)
    uid = UInt64(id)
    arr = lock(PINNED_LOCK) do
        get(PINNED, uid, nothing)
    end
    arr === nothing && error("array not pinned (id=$uid)")
    mat = Float64.(arr)
    if margin == 2  # columns: stats has length ncols
        s = reshape(stats, 1, :)
        if op == "/"
            return mat ./ s
        elseif op == "*"
            return mat .* s
        elseif op == "-"
            return mat .- s
        elseif op == "+"
            return mat .+ s
        end
    elseif margin == 1  # rows: stats has length nrows
        if op == "/"
            return mat ./ stats
        elseif op == "*"
            return mat .* stats
        elseif op == "-"
            return mat .- stats
        elseif op == "+"
            return mat .+ stats
        end
    end
    error("invalid margin=$margin or op=$op")
end

"""
Transpose a pinned 2D matrix and return the result as a new contiguous array.
The input array is looked up by pin_id from the PINNED dict.
The caller is responsible for pinning the result (e.g., via jlview()).
"""
function transform_transpose(id)
    uid = UInt64(id)
    arr = lock(PINNED_LOCK) do
        get(PINNED, uid, nothing)
    end
    arr === nothing && error("array not pinned (id=$uid)")
    return collect(permutedims(Float64.(arr)))
end

"""
Compute column-wise maximums of a pinned 2D matrix.
Returns a 1D vector of length ncols.
"""
function transform_colMaxs(id)
    uid = UInt64(id)
    arr = lock(PINNED_LOCK) do
        get(PINNED, uid, nothing)
    end
    arr === nothing && error("array not pinned (id=$uid)")
    mat = Float64.(arr)
    return vec(maximum(mat, dims=1))
end

"""
Compute row-wise medians of a pinned 2D matrix.
Returns a 1D vector of length nrows.
"""
function transform_rowMedians(id)
    uid = UInt64(id)
    arr = lock(PINNED_LOCK) do
        get(PINNED, uid, nothing)
    end
    arr === nothing && error("array not pinned (id=$uid)")
    mat = Float64.(arr)
    n = size(mat, 2)
    result = Vector{Float64}(undef, size(mat, 1))
    for i in 1:size(mat, 1)
        row = sort(mat[i, :])
        result[i] = isodd(n) ? row[div(n+1,2)] : (row[div(n,2)] + row[div(n,2)+1]) / 2
    end
    return result
end

"""
Compute column-wise means of a pinned 2D matrix.
Returns a 1D vector of length ncols.
"""
function transform_colMeans(id)
    uid = UInt64(id)
    arr = lock(PINNED_LOCK) do
        get(PINNED, uid, nothing)
    end
    arr === nothing && error("array not pinned (id=$uid)")
    mat = Float64.(arr)
    return vec(mean(mat, dims=1))
end

"""
Compute row-wise means of a pinned 2D matrix.
Returns a 1D vector of length nrows.
"""
function transform_rowMeans(id)
    uid = UInt64(id)
    arr = lock(PINNED_LOCK) do
        get(PINNED, uid, nothing)
    end
    arr === nothing && error("array not pinned (id=$uid)")
    mat = Float64.(arr)
    return vec(mean(mat, dims=2))
end

"""
Compute fold-change: divide each row of a pinned 2D matrix by its row median.
Returns a new matrix of the same size.
The input array is looked up by pin_id from the PINNED dict.
Transposes to column-major-friendly layout for row-wise median computation.

If `epsilon > 0`, adds epsilon to each element before computing medians and dividing.
This fuses the `x + epsilon` and `x / rowMedians(x)` steps into a single pass,
avoiding an intermediate allocation.
"""
function transform_fp(id, epsilon::Real=0.0)
    uid = UInt64(id)
    arr = lock(PINNED_LOCK) do
        get(PINNED, uid, nothing)
    end
    arr === nothing && error("array not pinned (id=$uid)")
    mat = Float64.(arr)
    eps = Float64(epsilon)
    if eps != 0.0
        mat = mat .+ eps
    end
    nrows, ncols = size(mat)

    # Transpose to make "rows" into contiguous columns for cache-friendly access
    matt = permutedims(mat)  # ncols x nrows, column j = original row j
    medians = Vector{Float64}(undef, nrows)
    for j in 1:nrows
        col = matt[:, j]  # contiguous copy of original row j
        medians[j] = median!(col)  # in-place median (partialsort)
    end
    return mat ./ medians
end

"""
Find top-2 row indices and values per column of a pinned 2D matrix.
For a gene x metacell matrix, this returns the top-2 genes per metacell.
Returns: (top1_idx, top2_idx, top1_val, top2_val) as 1-indexed Int32/Float64 vectors.
"""
function transform_top2_per_col(id)
    uid = UInt64(id)
    arr = lock(PINNED_LOCK) do
        get(PINNED, uid, nothing)
    end
    arr === nothing && error("array not pinned (id=$uid)")
    mat = Float64.(arr)
    nrows, ncols = size(mat)
    top1_idx = Vector{Int32}(undef, ncols)
    top2_idx = Vector{Int32}(undef, ncols)
    top1_val = Vector{Float64}(undef, ncols)
    top2_val = Vector{Float64}(undef, ncols)
    for j in 1:ncols
        best1_i = 1; best1_v = mat[1, j]
        best2_i = 1; best2_v = -Inf
        for i in 2:nrows
            v = mat[i, j]
            if v > best1_v
                best2_i = best1_i; best2_v = best1_v
                best1_i = i; best1_v = v
            elseif v > best2_v
                best2_i = i; best2_v = v
            end
        end
        top1_idx[j] = best1_i
        top2_idx[j] = best2_i
        top1_val[j] = best1_v
        top2_val[j] = best2_v
    end
    return (top1_idx, top2_idx, top1_val, top2_val)
end

"""
Find top-2 column indices and values per row of a pinned 2D matrix.
For a metacell x gene matrix, this returns the top-2 genes per metacell.
Returns: (top1_idx, top2_idx, top1_val, top2_val) as 1-indexed Int32/Float64 vectors.
"""
function transform_top2_per_row(id)
    uid = UInt64(id)
    arr = lock(PINNED_LOCK) do
        get(PINNED, uid, nothing)
    end
    arr === nothing && error("array not pinned (id=$uid)")
    mat = Float64.(arr)
    nrows, ncols = size(mat)
    top1_idx = Vector{Int32}(undef, nrows)
    top2_idx = Vector{Int32}(undef, nrows)
    top1_val = Vector{Float64}(undef, nrows)
    top2_val = Vector{Float64}(undef, nrows)
    for i in 1:nrows
        best1_j = 1; best1_v = mat[i, 1]
        best2_j = 1; best2_v = -Inf
        for j in 2:ncols
            v = mat[i, j]
            if v > best1_v
                best2_j = best1_j; best2_v = best1_v
                best1_j = j; best1_v = v
            elseif v > best2_v
                best2_j = j; best2_v = v
            end
        end
        top1_idx[i] = best1_j
        top2_idx[i] = best2_j
        top1_val[i] = best1_v
        top2_val[i] = best2_v
    end
    return (top1_idx, top2_idx, top1_val, top2_val)
end

end # module JlviewSupport

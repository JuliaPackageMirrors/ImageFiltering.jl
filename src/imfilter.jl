# see below for imfilter docstring

# Step 1: if necessary, determine the output's element type
@inline function imfilter(img::AbstractArray, kernel, args...)
    imfilter(filter_type(img, kernel), img, kernel, args...)
end

# Step 2: if necessary, put the kernel into cannonical (factored) form
@inline function imfilter{T}(::Type{T}, img::AbstractArray, kernel::Union{ArrayLike,Laplacian}, args...)
    imfilter(T, img, factorkernel(kernel), args...)
end

# Step 3: if necessary, fill in the default border
function imfilter{T}(::Type{T}, img::AbstractArray, kernel::ProcessedKernel, args...)
    imfilter(T, img, kernel, "replicate", args...)
end

function imfilter{T}(::Type{T}, img::AbstractArray, kernel::ProcessedKernel, border::AbstractString, args...)
    if border ∈ valid_borders
        return imfilter(T, img, kernel, Pad(Symbol(border)), args...)
    elseif border == "inner"
        error("specifying Inner as a string is deprecated, use `imfilter(img, kern, Inner())` instead")
    else
        throw(ArgumentError("$border not a recognized border"))
    end
end

# Step 4: if necessary, allocate the ouput
@inline function imfilter{T}(::Type{T}, img::AbstractArray, kernel::ProcessedKernel, border::BorderSpecAny, args...)
    imfilter!(allocate_output(T, img, kernel, border), img, kernel, border, args...)
end

# Now do the same steps for the case where the user supplies a Resource
@inline function imfilter(r::AbstractResource, img::AbstractArray, kernel, args...)
    imfilter(r, filter_type(img, kernel), img, kernel, args...)
end

@inline function imfilter{T}(r::AbstractResource, ::Type{T}, img::AbstractArray, kernel::ArrayLike, args...)
    imfilter(r, T, img, factorkernel(kernel), args...)
end

# For steps 3 & 4, we make args... explicit as a means to prevent
# specifying both r and an algorithm
function imfilter{T}(r::AbstractResource, ::Type{T}, img::AbstractArray, kernel::ProcessedKernel)
    imfilter(r, T, img, kernel, Pad(:replicate))  # supply the default border
end

function imfilter{T}(r::AbstractResource, ::Type{T}, img::AbstractArray, kernel::ProcessedKernel, border::BorderSpecAny)
    imfilter!(r, allocate_output(T, img, kernel, border), img, kernel, border)
end

"""
    imfilter([T], img, kernel, [border="replicate"], [alg]) --> imgfilt
    imfilter([r], img, kernel, [border="replicate"], [alg]) --> imgfilt
    imfilter(r, T, img, kernel, [border="replicate"], [alg]) --> imgfilt

Filter an array `img` with kernel `kernel` by computing their
correlation.

`kernel[0,0,..]` corresponds to the origin (zero displacement) of the
kernel; you can use `centered` to place the origin at the array
center, or use the OffsetArrays package to set `kernel`'s indices
manually. For example, to filter with a random *centered* 3x3 kernel,
you could use either of the following:

    kernel = centered(rand(3,3))
    kernel = OffsetArray(rand(3,3), -1:1, -1:1)

`kernel` can be specified as an array or as a "factored kernel," a
tuple `(filt1, filt2, ...)` of filters to apply along each axis of the
image. In cases where you know your kernel is separable, this format
can speed processing.  Each of these should have the same
dimensionality as the image itself, and be shaped in a manner that
indicates the filtering axis, e.g., a 3x1 filter for filtering the
first dimension and a 1x3 filter for filtering the second
dimension. In two dimensions, any kernel passed as a single matrix is
checked for separability; if you want to eliminate that check, pass
the kernel as a single-element tuple, `(kernel,)`.

Optionally specify the `border`, as one of `Fill(value)`,
`"replicate"`, `"circular"`, `"symmetric"`, `"reflect"`, `NA()`, or
`Inner()`. The default is `"replicate"`. These choices specify the
boundary conditions, and therefore affect the result at the edges of
the image. See `padarray` for more information.

`alg` allows you to choose the particular algorithm: `FIR()` (finite
impulse response, aka traditional digital filtering) or `FFT()`
(Fourier-based filtering). If no choice is specified, one will be
chosen based on the size of the image and kernel in a way that strives
to deliver good performance. Alternatively you can use a custom filter
type, like `IIRGaussian`.

Optionally, you can control the element type of the output image by
passing in a type `T` as the first argument.

You can also dispatch to different implementations by passing in a
resource `r` as defined by the ComputationalResources package.  For
example,

    imfilter(ArrayFire(), img, kernel)

would request that the computation be performed on the GPU using the
ArrayFire libraries.

See also: imfilter!, centered, padarray, Pad, Fill, Inner, IIRGaussian.
"""
imfilter

# see below for imfilter! docstring

# imfilter! can be called directly, so we take steps 2&3 here too. We
# have to be a little more cautious to make sure that later methods
# don't inadvertently call back to these: in methods that take an
# AbstractResource argument, exclude `NoPad()` as a border option.
function imfilter!(out::AbstractArray, img::AbstractArray, kernel::Union{ArrayLike,Laplacian}, args...)
    imfilter!(out, img, factorkernel(kernel), args...)
end

function imfilter!(r::AbstractResource, out::AbstractArray, img::AbstractArray, kernel::Union{ArrayLike,Laplacian})
    imfilter!(r, out, img, factorkernel(kernel))
end

function imfilter!(r::AbstractResource, out::AbstractArray, img::AbstractArray, kernel::Union{ArrayLike,Laplacian}, border::AbstractString)
    imfilter!(r, out, img, kernel, Pad(Symbol(border)))
end

function imfilter!(r::AbstractResource, out::AbstractArray, img::AbstractArray, kernel::Union{ArrayLike,Laplacian}, border::BorderSpec)
    imfilter!(r, out, img, factorkernel(kernel), border)
end

function imfilter!(out::AbstractArray, img::AbstractArray, kernel::ProcessedKernel)
    imfilter!(out, img, kernel, Pad(:replicate))
end

function imfilter!(r::AbstractResource, out::AbstractArray, img::AbstractArray, kernel::ProcessedKernel)
    imfilter!(r, out, img, kernel, Pad(:replicate))
end

function imfilter!(r::AbstractResource, out::AbstractArray, img::AbstractArray, kernel::ProcessedKernel, border::AbstractString)
    imfilter!(r, out, img, kernel, Pad(Symbol(border)))
end

# Step 5: if necessary, pick an algorithm
function imfilter!(out::AbstractArray, img::AbstractArray, kernel::ProcessedKernel, border::AbstractString)
    imfilter!(out, img, kernel, Pad(Symbol(border)))
end

function imfilter!(out::AbstractArray, img::AbstractArray, kernel::ProcessedKernel, border::BorderSpecAny)
    imfilter!(out, img, kernel, border, filter_algorithm(out, img, kernel))
end

function imfilter!(out::AbstractArray, img::AbstractArray, kernel::ProcessedKernel, border::BorderSpecAny, alg::Alg)
    imfilter!(default_resource(alg), out, img, kernel, border)
end

"""
    imfilter!(imgfilt, img, kernel, [border="replicate"], [alg])
    imfilter!(r, imgfilt, img, kernel, border, [inds])
    imfilter!(r, imgfilt, img, kernel, border::NoPad, [inds=indices(imgfilt)])

Filter an array `img` with kernel `kernel` by computing their
correlation, storing the result in `imgfilt`.

The indices of `imgfilt` determine the region over which the filtered
image is computed---you can use this fact to select just a specific
region of interest, although be aware that the input `img` might still
get padded.  Alteratively, explicitly provide the indices `inds` of
`imgfilt` that you want to calculate, and use `NoPad` boundary
conditions. In such cases, you are responsible for supplying
appropriate padding: `img` must be indexable for all of the locations
needed for calculating the output. This syntax is best-supported for
FIR filtering; in particular, that that IIR filtering can lead to
results that are inconsistent with respect to filtering the entire
array.

See also: imfilter.
"""
imfilter!

# Step 6: pad the input
# NA "padding": normalizing by the number of available values (similar to nanmean)
function imfilter!{T,S,N}(r::AbstractResource,
                          out::AbstractArray{S,N},
                          img::AbstractArray{T,N},
                          kernel::ProcessedKernel,
                          border::NA{0})
    _imfilter_na!(r, out, img, kernel, border)
end

function _imfilter_na!{T,S,N}(r::AbstractResource,
                              out::AbstractArray{S,N},
                              img::AbstractArray{T,N},
                              kernel::ProcessedKernel,
                              border::NA{0})
    nanflag = isnan.(img)
    hasnans = any(nanflag)
    if hasnans || !isseparable(kernel)
        imfilter_na_inseparable!(r, out, img, nanflag, kernel)
    else
        imfilter_na_separable!(r, out, img, kernel)
    end
    out
end

# for types that can't have NaNs, we can skip the isnan check
function _imfilter_na!{S,T<:Union{Integer,FixedColorant},N}(r::AbstractResource,
                                                            out::AbstractArray{S,N},
                                                            img::AbstractArray{T,N},
                                                            kernel::ProcessedKernel,
                                                            border::NA{0})
    if isseparable(kernel)
        imfilter_na_separable!(r, out, img, kernel)
    else
        nanflag = similar(dims->falses(dims), indices(img))
        imfilter_na_inseparable!(r, out, img, nanflag, kernel)
    end
end

# Any other kind of padding
function imfilter!{S,T,N}(r::AbstractResource,
                          out::AbstractArray{S,N},
                          img::AbstractArray{T,N},
                          kernel::ProcessedKernel,
                          border::BorderSpec)
    bord = border(kernel, img, Alg(r))  # if it's FFT, the size of img is also relevant
    A = padarray(S, img, bord)
    # By specifying NoPad(), we ensure that dispatch will never
    # accidentally "go back" to an earlier routine and apply more
    # padding
    imfilter!(r, out, A, kernel, NoPad(border))
end

# An optimized case that performs only "virtual padding"
function imfilter!{S,T,N}(r::AbstractCPU{FIR},
                          out::AbstractArray{S,N},
                          img::AbstractArray{T,N},
                          kernel::ProcessedKernel,
                          border::Pad{0})
    # The fast path: handle the points that don't need padding
    iinds = map(intersect, interior(img, kernel), indices(out))
    imfilter!(r, out, img, kernel, NoPad(border), iinds)
    # The not-so-fast path: handle the edges
    padded = view(img, padindices(img, border(kernel))...)
    pkernel = kernelconv(kernel...)
    _imfilter_iter!(r, out, padded, pkernel, EdgeIterator(indices(out), iinds))
end

### "Scheduler" methods (all with NoPad)

# These methods handle much of what Halide calls "the schedule."
# Together they handle the order-of-operations for separable and/or
# cascaded kernels, and even implement multithreadable tiling for FIR
# filtering.

# Trivial kernel (a copy operation)
function imfilter!(r::AbstractResource, out::AbstractArray, A::AbstractArray, kernel::Tuple{}, ::NoPad, inds::Indices=indices(out))
    R = CartesianRange(inds)
    copy!(out, R, A, R)
end

# A single kernel
function imfilter!(r::AbstractResource, out::AbstractArray, A::AbstractArray, kernel::Tuple{Any}, border::NoPad, inds::Indices=indices(out))
    kern = kernel[1]
    iscopy(kern) && return imfilter!(r, out, A, (), border, inds)
    imfilter!(r, out, A, samedims(out, kern), border, inds)
end

const fillbuf_nan = Ref(false)  # used only for testing purposes

# A filter cascade (2 or more filters)
function imfilter!(r::AbstractResource, out::AbstractArray, A::AbstractArray, kernel::Tuple{Any,Any,Vararg{Any}}, border::NoPad, inds=indices(out))
    kern = kernel[1]
    iscopy(kern) && return imfilter!(r, out, A, tail(kernel), border, inds)
    # For multiple stages of filtering, we introduce a second buffer
    # and swap them at each stage. The first of the two is the one
    # that holds the most recent result.
    A2 = similar(A)  # for type-stability, let's hope it's really the *same* type...
    if fillbuf_nan[]
        fill!(A2, NaN)  # for testing purposes
    end
    indsstep = shrink(expand(inds, calculate_padding(kernel)), kern)
    _imfilter!(r, out, A, A2, kernel, border, indsstep)
    return out
end

### When everything is FIR, we can instead use a tiled algorithm for the cascaded case
function imfilter!{S,T,N}(r::AbstractCPU{FIR}, out::AbstractArray{S,N}, A::AbstractArray{T,N}, kernel::Tuple{Any,Any,Vararg{Any}}, border::NoPad, inds=indices(out))
    kern = kernel[1]
    iscopy(kern) && return imfilter!(r, out, A, tail(kernel), border, inds)
    tmp = tile_allocate(filter_type(A, kernel), kernel)
    _imfilter_tiled!(r, out, A, kernel, border, tmp, inds)
    out
end

### Scheduler support methods

## No tiling, filter cascade

# For these (internal) methods, `indsstep` refers to `inds` for this
# step of filtering, not the indices of `out` that we want to finally
# target.

# When `kernel` is (originally) a tuple that has both TriggsSdika and
# FIR filters, the overall padding gets doubled, yet we only trim off
# the minimum at each stage. Consequently, `indsstep` might be
# optimistic about the range available in `out`; therefore we use
# `intersect`.
function _imfilter!(r, out::AbstractArray, A1, A2, kernel::Tuple{}, border::NoPad, indsstep::Indices)
    imfilter!(r, out, A1, kernel, border, map(intersect, indsstep, indices(out)))
end

function _imfilter!(r, out::AbstractArray, A1, A2, kernel::Tuple{Any}, border::NoPad, indsstep::Indices)
    imfilter!(r, out, A1, kernel[1], border, map(intersect, indsstep, indices(out)))
end

# For IIR, it's important to filter over the whole passed-in range,
# and then copy! to out
function _imfilter!(r, out::AbstractArray, A1, A2, kernel::Tuple{AnyIIR}, border::NoPad, indsstep::Indices)
    if indsstep != indices(out)
        imfilter!(r, A2, A1, kernel[1], border, indsstep)
        R = CartesianRange(map(intersect, indsstep, indices(out)))
        return copy!(out, R, A2, R)
    end
    imfilter!(r, out, A1, kernel[1], border, indsstep)
end

function _imfilter!(r, out::AbstractArray, A1, A2, kernel::Tuple{Any,Any,Vararg{Any}}, border::NoPad, indsstep::Indices)
    kern = kernel[1]
    iscopy(kern) && return _imfilter!(r, out, A1, A2, tail(kernel), border, indsstep)
    kernN = samedims(A2, kern)
    imfilter!(r, A2, A1, kernN, border, indsstep)  # store result in A2
    kernelt = tail(kernel)
    newinds = next_shrink(indsstep, kernelt)
    _imfilter!(r, out, A2, A1, tail(kernel), border, newinds)          # swap the buffers
end

# Single-threaded, pair of kernels (with only one temporary buffer required)
function _imfilter_tiled!{AA<:AbstractArray}(r::CPU1, out, A, kernel::Tuple{Any,Any}, border::NoPad, tiles::Vector{AA}, indsout)
    k1, k2 = kernel
    tile = tiles[1]
    indsk1, indstile = indices(k1), indices(tile)
    sz = map(length, indstile)
    chunksz = map(length, shrink(indstile, indsk1))
    inds = expand(indsout, k2)
    for tileinds in TileIterator(inds, chunksz)
        tileb = TileBuffer(tile, tileinds)
        imfilter!(r, tileb, A, samedims(tileb, k1), border, tileinds)
        imfilter!(r, out, tileb, samedims(out, k2), border, shrink(tileinds, k2))
    end
    out
end

# Multithreaded, pair of kernels
function _imfilter_tiled!{AA<:AbstractArray}(r::CPUThreads, out, A, kernel::Tuple{Any,Any}, border::NoPad, tiles::Vector{AA}, indsout)
    k1, k2 = kernel
    tile = tiles[1]
    indsk1, indstile = indices(k1), indices(tile)
    sz = map(length, indstile)
    chunksz = map(length, shrink(indstile, indsk1))
    tileinds_all = collect(TileIterator(expand(indsout, k2), chunksz))
    _imfilter_tiled_threads!(CPU1(r), out, A, samedims(out, k1), samedims(out, k2), border, tileinds_all, tiles)
end
# This must be in a separate function due to #15276
@noinline function _imfilter_tiled_threads!{AA<:AbstractArray}(r1, out, A, k1, k2, border, tileinds_all, tile::Vector{AA})
    Threads.@threads for i = 1:length(tileinds_all)
        id = Threads.threadid()
        tileinds = tileinds_all[i]
        tileb = TileBuffer(tile[id], tileinds)
        imfilter!(r1, tileb, A, k1, border, tileinds)
        imfilter!(r1, out, tileb, k2, border, shrink(tileinds, k2))
    end
    out
end

# Single-threaded, multiple kernels (requires two tile buffers, swapping on each iteration)
function _imfilter_tiled!{AA<:AbstractArray}(r::CPU1, out, A, kernel::Tuple{Any,Any,Vararg{Any}}, border::NoPad, tiles::Vector{Tuple{AA,AA}}, indsout)
    k1, kt = kernel[1], tail(kernel)
    tilepair = tiles[1]
    indsk1, indstile = indices(k1), indices(tilepair[1])
    sz = map(length, indstile)
    chunksz = map(length, shrink(indstile, indsk1))
    inds = expand(indsout, kt)
    for tileinds in TileIterator(inds, chunksz)
        tileb1 = TileBuffer(tilepair[1], tileinds)
        imfilter!(r, tileb1, A, samedims(tileb1, k1), border, tileinds)
        _imfilter_tiled_swap!(r, out, kt, border, (tileb1, tilepair[2]))
    end
end

# Multithreaded, multiple kernels
function _imfilter_tiled!{AA<:AbstractArray}(r::CPUThreads, out, A, kernel::Tuple{Any,Any,Vararg{Any}}, border::NoPad, tiles::Vector{Tuple{AA,AA}}, indsout)
    k1, kt = kernel[1], tail(kernel)
    tilepair = tiles[1]
    indsk1, indstile = indices(k1), indices(tilepair[1])
    sz = map(length, indstile)
    chunksz = map(length, shrink(indstile, indsk1))
    tileinds_all = collect(TileIterator(expand(indsout, kt), chunksz))
    _imfilter_tiled_threads!(CPU1(r), out, A, samedims(out, k1), kt, border, tileinds_all, tiles)
end
# This must be in a separate function due to #15276
@noinline function _imfilter_tiled_threads!{AA<:AbstractArray}(r1, out, A, k1, kt, border, tileinds_all, tiles::Vector{Tuple{AA,AA}})
    Threads.@threads for i = 1:length(tileinds_all)
        tileinds = tileinds_all[i]
        id = Threads.threadid()
        tile1, tile2 = tiles[id]
        tileb1 = TileBuffer(tile1, tileinds)
        imfilter!(r1, tileb1, A, k1, border, tileinds)
        _imfilter_tiled_swap!(r1, out, kt, border, (tileb1, tile2))
    end
    out
end

# The first of the pair in `tmp` has the current data. We also make
# the second a plain array so there's no doubt about who's holding the
# proper indices.
function _imfilter_tiled_swap!(r, out, kernel::Tuple{Any,Any,Vararg{Any}}, border, tmp::Tuple{TileBuffer,Array})
    tileb1, tile2 = tmp
    k1, kt = kernel[1], tail(kernel)
    parentinds = indices(tileb1)
    tileinds = shrink(parentinds, k1)
    tileb2 = TileBuffer(tile2, tileinds)
    imfilter!(r, tileb2, tileb1, samedims(tileb2, k1), border, tileinds)
    _imfilter_tiled_swap!(r, out, kt, border, (tileb2, parent(tileb1)))
end

# on the last call we write to `out` instead of one of the buffers
function _imfilter_tiled_swap!(r, out, kernel::Tuple{Any}, border, tmp::Tuple{TileBuffer,Array})
    tileb1 = tmp[1]
    k1 = kernel[1]
    parentinds = indices(tileb1)
    tileinds = shrink(parentinds, k1)
    imfilter!(r, out, tileb1, samedims(out, k1), border, tileinds)
end

### FIR filtering

"""
    imfilter!(::AbstractResource, imgfilt, img, kernel, NoPad(), [inds=indices(imgfilt)])

Filter an array `img` with kernel `kernel` by computing their
correlation, storing the result in `imgfilt`, defaulting to a finite-impulse
response (FIR) algorithm. Any necessary padding must have already been
supplied to `img`. If you want padding applied, instead call

    imfilter!([r::AbstractResource,] imgfilt, img, kernel, border)

with a specific `border`, or use

    imfilter!(imgfilt, img, kernel, [Algorithm.FIR()])

for default padding.

If `inds` is supplied, only the elements of `imgfilt` with indices in
the domain of `inds` will be calculated. This can be particularly
useful for "cascaded FIR filters" where you pad over a larger area and
then calculate the result over just the necessary/well-defined region
at each successive stage.

See also: imfilter.
"""
function imfilter!{S,T,N}(r::AbstractResource,
                          out::AbstractArray{S,N},
                          A::AbstractArray{T,N},
                          kern::NDimKernel{N},
                          border::NoPad,
                          inds::Indices{N}=indices(out))
    (isempty(A) || isempty(kern)) && return out
    indso, indsA, indsk = indices(out), indices(A), indices(kern)
    if iscopy(kern)
        R = CartesianRange(inds)
        return copy!(out, R, A, R)
    end
    for i = 1:N
        # Check that inds is inbounds for out
        indsi, indsoi, indsAi, indski = inds[i], indso[i], indsA[i], indsk[i]
        if first(indsi) < first(indsoi) || last(indsi) > last(indsoi)
            throw(DimensionMismatch("output indices $indso disagrees with requested indices $inds"))
        end
        # Check that input A is big enough not to throw a BoundsError
        if      first(indsAi) > first(indsi) + first(indski) ||
                last(indsA[i])  < last(indsi)  + last(indski)
            throw(DimensionMismatch("requested indices $inds and kernel indices $indsk do not agree with indices of padded input, $indsA"))
        end
    end
    _imfilter_inbounds!(r, out, A, kern, border, inds)
end

function _imfilter_inbounds!(r::AbstractResource, out, A::AbstractArray, kern::ReshapedIIR, border::NoPad, inds)
    indspre, ind, indspost = iterdims(inds, kern)
    _imfilter_dim!(r, out, A, kern.data, CartesianRange(indspre), ind, CartesianRange(indspost), border[])
end

function _imfilter_inbounds!(r::AbstractResource, out, A::AbstractArray, kern, border::NoPad, inds)
    indsk = indices(kern)
    R, Rk = CartesianRange(inds), CartesianRange(indsk)
    p = A[first(R)+first(Rk)] * first(kern)
    TT = typeof(p+p)
    for I in R
        tmp = zero(TT)
        @unsafe for J in Rk
            tmp += A[I+J]*kern[J]
        end
        @unsafe out[I] = tmp
    end
    out
end

function _imfilter_inbounds!(r::AbstractResource, out, A::AbstractArray, kern::ReshapedOneD, border::NoPad, inds)
    Rpre, ind, Rpost = iterdims(inds, kern)
    k = kern.data
    R, Rk = CartesianRange(inds), CartesianRange(indices(kern))
    p = A[first(R)+first(Rk)] * first(k)
    TT = typeof(p+p)
    _imfilter_inbounds(r, TT, out, A, k, Rpre, ind, Rpost)
end

function _imfilter_inbounds{TT}(r::AbstractResource, ::Type{TT}, out, A::AbstractArray, k::AbstractVector, Rpre::CartesianRange, ind, Rpost::CartesianRange)
    indsk = indices(k, 1)
    for Ipost in Rpost
        for Ipre in Rpre
            for i in ind
                tmp = zero(TT)
                @unsafe for j in indsk
                    tmp += A[Ipre,i+j,Ipost]*k[j]
                end
                @unsafe out[Ipre,i,Ipost] = tmp
            end
        end
    end
    out
end

function _imfilter_iter!(r::AbstractResource, out, padded, kernel::AbstractArray, iter)
    p = first(padded) * first(kernel)
    TT = typeof(p+p)
    Rk = CartesianRange(indices(kernel))
    for I in iter
        tmp = zero(TT)
        for J in Rk
            tmp += padded[I+J]*kernel[J]
        end
        out[I] = tmp
    end
    out
end

### FFT filtering

"""
    imfilter!(::AbstractResource{FFT}, imgfilt, img, kernel, NoPad())

Filter an array `img` with kernel `kernel` by computing their
correlation, storing the result in `imgfilt`, using a fast Fourier
transform (FFT) algorithm. Any necessary padding must have already
been applied to `img`. If you want padding applied, instead call

    imfilter!(::AbstractResource{FFT}, imgfilt, img, kernel, border)

with a specific `border`, or use

    imfilter!(imgfilt, img, kernel, Algorithm.FFT())

for default padding.

See also: imfilter.
"""
function imfilter!{S,T,K,N}(r::AbstractCPU{FFT},
                            out::AbstractArray{S,N},
                            img::AbstractArray{T,N},
                            kernel::AbstractArray{K,N},
                            border::NoPad)
    imfilter!(r, out, img, (kernel,), border)
end

function imfilter!{S,T,N}(r::AbstractCPU{FFT},
                          out::AbstractArray{S,N},
                          A::AbstractArray{T,N},
                          kernel::Tuple{AbstractArray},
                          border::NoPad)
    _imfilter_fft!(r, out, A, kernel, border)  # ambiguity resolution
end
function imfilter!{S,T,N}(r::AbstractCPU{FFT},
                          out::AbstractArray{S,N},
                          A::AbstractArray{T,N},
                          kernel::Tuple{AbstractArray,Vararg{AbstractArray}},
                          border::NoPad)
    _imfilter_fft!(r, out, A, kernel, border)
end

function _imfilter_fft!{S,T,N}(r::AbstractCPU{FFT},
                          out::AbstractArray{S,N},
                          A::AbstractArray{T,N},
                          kernel::Tuple{AbstractArray,Vararg{AbstractArray}},
                          border::NoPad)
    kern = samedims(A, kernelconv(kernel...))
    krn = FFTView(zeros(eltype(kern), map(length, indices(A))))
    for I in CartesianRange(indices(kern))
        krn[I] = kern[I]
    end
    Af = filtfft(A, krn)
    if map(first, indices(out)) == map(first, indices(Af))
        R = CartesianRange(indices(out))
        copy!(out, R, Af, R)
    else
        # Exploit the periodic boundary conditions of FFTView
        dest = FFTView(out)
        src = OffsetArray(view(FFTView(Af), indices(dest)...), indices(dest))
        copy!(dest, src)
    end
    out
end

filtfft(A, krn) = irfft(rfft(A).*conj(rfft(krn)), length(indices(A,1)))
function filtfft{C<:Colorant}(A::AbstractArray{C}, krn)
    Av, dims = channelview_dims(A)
    kernrs = kreshape(C, krn)
    Avf = irfft(rfft(Av, dims).*conj(rfft(kernrs, dims)), length(indices(Av, dims[1])), dims)
    colorview(base_colorant_type(C){eltype(Avf)}, Avf)
end
channelview_dims{C<:Colorant,N}(A::AbstractArray{C,N}) = channelview(A), ntuple(d->d+1, Val{N})
if ImageCore.squeeze1
    channelview_dims{C<:ImageCore.Color1,N}(A::AbstractArray{C,N}) = channelview(A), ntuple(identity, Val{N})
end

function kreshape{C<:Colorant}(::Type{C}, krn::FFTView)
    kern = parent(krn)
    kernrs = FFTView(reshape(kern, 1, size(kern)...))
end
if ImageCore.squeeze1
    kreshape{C<:ImageCore.Color1}(::Type{C}, krn::FFTView) = krn
end

### Triggs-Sdika (modified Young-van Vliet) recursive filtering
# B. Triggs and M. Sdika, "Boundary conditions for Young-van Vliet
# recursive filtering". IEEE Trans. on Sig. Proc. 54: 2365-2367
# (2006).

# Note this is safe for inplace use, i.e., out === img

function imfilter!{S,T,N}(r::AbstractResource{IIR},
                          out::AbstractArray{S,N},
                          img::AbstractArray{T,N},
                          kernel::Tuple{TriggsSdika, Vararg{TriggsSdika}},
                          border::BorderSpec)
    isa(border, Pad) && border.symbol != :replicate && throw(ArgumentError("only \"replicate\" is supported"))
    length(kernel) <= N || throw(DimensionMismatch("cannot have more kernels than dimensions"))
    inds = indices(img)
    _imfilter_inplace_tuple!(r, out, img, kernel, CartesianRange(()), inds, CartesianRange(tail(inds)), border)
end

"""
    imfilter!(r::AbstractResource, imgfilt, img, kernel::Tuple{TriggsSdika...}, border)
    imfilter!(r::AbstractResource, imgfilt, img, kernel::TriggsSdika, dim::Integer, border)

Filter an array `img` with a Triggs-Sdika infinite impulse response
(IIR) `kernel`, storing the result in `imgfilt`. Unlike the `FIR` and
`FFT` algorithms, this version is safe for inplace operations, i.e.,
`imgfilt` can be the same array as `img`.

Either specify one kernel per dimension (as a tuple), or a particular
dimension `dim` along which to filter. If you exhaust `kernel`s before
you run out of array dimensions, the remaining dimension(s) will not
be filtered.

With Triggs-Sdika filtering, the only border options are `NA()`,
`"replicate"`, or `Fill(value)`.

See also: imfilter, TriggsSdika, IIRGaussian.
"""
function imfilter!(r::AbstractResource, out, img, kernel::TriggsSdika, dim::Integer, border::BorderSpec)
    inds = indices(img)
    k, l = length(kernel.a), length(kernel.b)
    # This next part is not type-stable, which is why _imfilter_dim! has a @noinline
    Rbegin = CartesianRange(inds[1:dim-1])
    Rend   = CartesianRange(inds[dim+1:end])
    _imfilter_dim!(r, out, img, kernel, Rbegin, inds[dim], Rend, border)
end
function imfilter!(r::AbstractResource, out, img, kernel::TriggsSdika, dim::Integer, border::AbstractString)
    imfilter!(r, out, img, kernel, dim, Pad(Symbol(border)))
end


function imfilter!(r::AbstractResource, out, A::AbstractVector, kern::TriggsSdika, border::NoPad, inds::Indices=indices(out))
    indspre, ind, indspost = iterdims(inds, kern)
    _imfilter_dim!(r, out, A, kern, CartesianRange(indspre), ind, CartesianRange(indspost), border[])
end

# Lispy and type-stable inplace (currently just Triggs-Sdika) filtering over each dimension
function _imfilter_inplace_tuple!(r, out, img, kernel, Rbegin, inds, Rend, border)
    ind = first(inds)
    _imfilter_dim!(r, out, img, first(kernel), Rbegin, ind, Rend, border)
    _imfilter_inplace_tuple!(r,
                             out,
                             out,
                             tail(kernel),
                             CartesianRange(CartesianIndex((Rbegin.start.I..., first(ind))),
                                            CartesianIndex((Rbegin.stop.I...,  last(ind)))),
                             tail(inds),
                             _tail(Rend),
                             border)
end
# When the final kernel has been used, return the output
_imfilter_inplace_tuple!(r, out, img, ::Tuple{}, Rbegin, inds, Rend, border) = out

# This is the "workhorse" function that performs Triggs-Sdika IIR
# filtering along a particular dimension. The "pre" dimensions are
# encoded in Rbegin, the "post" dimensions in Rend, and the dimension
# we're filtering is sandwiched between these. This design is
# type-stable and cache-friendly for any dimension---we update values
# in memory-order rather than along the chosen dimension. Nor does it
# require that the arrays have efficient linear indexing. For more
# information, see http://julialang.org/blog/2016/02/iteration.
@noinline function _imfilter_dim!{T,k,l}(r::AbstractResource,
                                         out, img, kernel::TriggsSdika{T,k,l},
                                         Rbegin::CartesianRange, ind::AbstractUnitRange,
                                         Rend::CartesianRange, border::BorderSpec)
    if iscopy(kernel)
        if !(out === img)
            copy!(out, img)
        end
        return out
    end
    if length(ind) <= max(k, l)
        throw(DimensionMismatch("size of img along dimension $dim $(length(inds[dim])) is too small for filtering with IIR kernel of length $(max(k,l))"))
    end
    for Iend in Rend
        # Initialize the left border
        indleft = ind[1:k]
        for Ibegin in Rbegin
            leftborder!(out, img, kernel, Ibegin, indleft, Iend, border)
        end
        # Propagate forwards. We omit the final point in case border
        # is "replicate", so that the original value is still
        # available. rightborder! will handle that point.
        for i = ind[k]+1:ind[end-1]
            @unsafe for Ibegin in Rbegin
                tmp = one(T)*img[Ibegin, i, Iend]
                for j = 1:k
                    tmp += kernel.a[j]*out[Ibegin, i-j, Iend]
                end
                out[Ibegin, i, Iend] = tmp
            end
        end
        # Initialize the right border
        indright = ind[end-l+1:end]
        for Ibegin in Rbegin
            rightborder!(out, img, kernel, Ibegin, indright, Iend, border)
        end
        # Propagate backwards
        for i = ind[end-l]:-1:ind[1]
            @unsafe for Ibegin in Rbegin
                tmp = one(T)*out[Ibegin, i, Iend]
                for j = 1:l
                    tmp += kernel.b[j]*out[Ibegin, i+j, Iend]
                end
                out[Ibegin, i, Iend] = tmp
            end
        end
        # Final scaling
        for i in ind
            @unsafe for Ibegin in Rbegin
                out[Ibegin, i, Iend] *= kernel.scale
            end
        end
    end
    out
end

# Implements the initialization in the first paragraph of Triggs & Sdika, section II
function leftborder!(out, img, kernel, Ibegin, indleft, Iend, border::Fill)
    _leftborder!(out, img, kernel, Ibegin, indleft, Iend, convert(eltype(img), border.value))
end
function leftborder!(out, img, kernel, Ibegin, indleft, Iend, border::Pad)
    _leftborder!(out, img, kernel, Ibegin, indleft, Iend, img[Ibegin, indleft[1], Iend])
end
function _leftborder!{T,k,l}(out, img, kernel::TriggsSdika{T,k,l}, Ibegin, indleft, Iend, iminus)
    uminus = iminus/(1-kernel.asum)
    n = 0
    for i in indleft
        n += 1
        tmp = one(T)*img[Ibegin, i, Iend]
        for j = 1:n-1
            tmp += kernel.a[j]*out[Ibegin, i-j, Iend]
        end
        for j = n:k
            tmp += kernel.a[j]*uminus
        end
        out[Ibegin, i, Iend] = tmp
    end
    out
end

# Implements Triggs & Sdika, Eqs 14-15
function rightborder!(out, img, kernel, Ibegin, indright, Iend, border::Fill)
    _rightborder!(out, img, kernel, Ibegin, indright, Iend, convert(eltype(img), border.value))
end
function rightborder!(out, img, kernel, Ibegin, indright, Iend, border::Pad)
    _rightborder!(out, img, kernel, Ibegin, indright, Iend, img[Ibegin, indright[end], Iend])
end
function _rightborder!{T,k,l}(out, img, kernel::TriggsSdika{T,k,l}, Ibegin, indright, Iend, iplus)
    # The final value from forward-filtering was not calculated, so do that here
    i = last(indright)
    tmp = one(T)*img[Ibegin, i, Iend]
    for j = 1:k
        tmp += kernel.a[j]*out[Ibegin, i-j, Iend]
    end
    out[Ibegin, i, Iend] = tmp
    # Initialize the v values at and beyond the right edge
    uplus = iplus/(1-kernel.asum)
    vplus = uplus/(1-kernel.bsum)
    vright = kernel.M * rightΔu(out, uplus, Ibegin, last(indright), Iend, kernel) + vplus
    out[Ibegin, last(indright), Iend] = vright[1]
    # Propagate inward
    n = 1
    for i in last(indright)-1:-1:first(indright)
        n += 1
        tmp = one(T)*out[Ibegin, i, Iend]
        for j = 1:n-1
            tmp += kernel.b[j]*out[Ibegin, i+j, Iend]
        end
        for j = n:l
            tmp += kernel.b[j]*vright[j-n+2]
        end
        out[Ibegin, i, Iend] = tmp
    end
    out
end

# Part of Triggs & Sdika, Eq. 14
function rightΔu{T,l}(img, uplus, Ibegin, i, Iend, kernel::TriggsSdika{T,3,l})
    @inbounds ret = SVector(img[Ibegin, i,   Iend]-uplus,
                            img[Ibegin, i-1, Iend]-uplus,
                            img[Ibegin, i-2, Iend]-uplus)
    ret
end

### NA boundary conditions

function imfilter_na_inseparable!{T}(r, out::AbstractArray{T}, img, nanflag, kernel::Tuple{Vararg{TriggsSdika}})
    fc, fn = Fill(zero(T)), Fill(zero(eltype(T)))  # color, numeric
    copy!(out, img)
    out[nanflag] = zero(T)
    validpixels = copy!(similar(Array{eltype(T)}, indices(img)), mappedarray(x->!x, nanflag))
    # TriggsSdika is safe for inplace operations
    imfilter!(r, out, out, kernel, fc)
    imfilter!(r, validpixels, validpixels, kernel, fn)
    for I in eachindex(out)
        out[I] /= validpixels[I]
    end
    out[nanflag] = nan(T)
    out
end

function imfilter_na_inseparable!{T}(r, out::AbstractArray{T}, img, nanflag, kernel::Tuple)
    fc, fn = Fill(zero(T)), Fill(zero(eltype(T)))  # color, numeric
    imgtmp = copy!(similar(out, indices(img)), img)
    imgtmp[nanflag] = zero(T)
    validpixels = copy!(similar(Array{eltype(T)}, indices(img)), mappedarray(x->!x, nanflag))
    imfilter!(r, out, imgtmp, kernel, fc)
    vp = imfilter(r, validpixels, kernel, fn)
    for I in eachindex(out)
        out[I] /= vp[I]
    end
    out[nanflag] = nan(T)
    out
end

function imfilter_na_separable!{T}(r, out::AbstractArray{T}, img, kernel::Tuple)
    fc, fn = Fill(zero(T)), Fill(zero(eltype(T)))  # color, numeric
    imfilter!(r, out, img, kernel, fc)
    normalize_separable!(r, out, kernel, fn)
end

### Utilities

filter_type{S}(img::AbstractArray{S}, kernel) = filter_type(S, kernel)

filter_type{S,T}(::Type{S}, kernel::ArrayLike{T}) = typeof(zero(S)*zero(T) + zero(S)*zero(T))
filter_type{S<:Union{UFixed,FixedColorant}}(::Type{S}, ::Laplacian) = float32(S)
filter_type{S<:Colorant}(::Type{S}, kernel::Laplacian) = S
filter_type{S<:AbstractFloat}(::Type{S}, ::Laplacian) = S
filter_type{S<:Signed}(::Type{S}, ::Laplacian) = S
filter_type{S<:Unsigned}(::Type{S}, ::Laplacian) = signed_type(S)
filter_type(::Type{Bool}, ::Laplacian) = Int8

signed_type(::Type{UInt8})  = Int16
signed_type(::Type{UInt16}) = Int32
signed_type(::Type{UInt32}) = Int64

@inline function filter_type{S}(::Type{S}, kernel::Tuple{Any,Vararg{Any}})
    T = filter_type(S, kernel[1])
    filter_type(T, S, tail(kernel))
end
@inline function filter_type{T,S}(::Type{T}, ::Type{S}, kernel::Tuple{Any,Vararg{Any}})
    Tnew = promote_type(T, filter_type(S, kernel[1]))
    filter_type(Tnew, S, tail(kernel))
end
filter_type{T,S}(::Type{T}, ::Type{S}, kernel::Tuple{}) = T

factorkernel(kernel::AbstractArray) = (kernelshift(indices(kernel), kernel),)
factorkernel(L::Laplacian) = (L,)

function factorkernel{T}(kernel::AbstractMatrix{T})
    inds = indices(kernel)
    m, n = map(length, inds)
    kern = Array{T}(m, n)
    copy!(kern, 1:m, 1:n, kernel, inds[1], inds[2])
    factorstridedkernel(inds, kern)
end

function factorstridedkernel(inds, kernel::StridedMatrix)
    SVD = svdfact(kernel)
    U, S, Vt = SVD[:U], SVD[:S], SVD[:Vt]
    separable = true
    EPS = sqrt(eps(eltype(S)))
    for i = 2:length(S)
        separable &= (abs(S[i]) < EPS)
    end
    if !separable
        ks = kernelshift(inds, kernel)
        return (dummykernel(indices(ks)), ks)
    end
    s = S[1]
    u, v = U[:,1:1], Vt[1:1,:]
    ss = sqrt(s)
    (kernelshift((inds[1], dummyind(inds[1])), ss*u),
     kernelshift((dummyind(inds[2]), inds[2]), ss*v))
end

prod_kernel(kern::AbstractArray) = kern
prod_kernel(kern::AbstractArray, kern1, kerns...) = broadcast(*, kern, kern1, kerns...) #prod_kernel(kern.*kern1, kerns...)
prod_kernel{N}(::Type{Val{N}}, args...) = prod_kernel(Val{N}, prod_kernel(args...))
prod_kernel{_,N}(::Type{Val{N}}, kernel::AbstractArray{_,N}) = kernel
function prod_kernel{N}(::Type{Val{N}}, kernel::AbstractArray)
    inds = indices(kernel)
    newinds = fill_to_length(inds, oftype(inds[1], 0:0), Val{N})
    reshape(kernel, newinds)
end

kernelshift(::Tuple{}, A::StridedArray) = A
kernelshift(::Tuple{}, A) = A
kernelshift{N}(inds::NTuple{N,Base.OneTo}, A::StridedArray) = _kernelshift(inds, A)
kernelshift{N}(inds::NTuple{N,Base.OneTo}, A) = _kernelshift(inds, A)
function _kernelshift(inds, A)
    Base.depwarn("assuming that the origin is at the center of the kernel; to avoid this warning, call `centered(kernel)` or use an OffsetArray", :_kernelshift)  # this may be necessary long-term?
    centered(A)
end
kernelshift(inds::Indices, A::StridedArray) = OffsetArray(A, inds...)
function kernelshift(inds::Indices, A)
    @assert indices(A) == inds
    A
end

# Note this is not type-stable. Fortunately, all the outputs are
# allocated by the time this gets called.
function filter_algorithm(out, img, kernel::Union{ArrayType,Tuple{Vararg{ArrayType}}})
    L = maxlen(kernel)
    if L > 30
        return FFT()
    end
    FIR()
end
filter_algorithm(out, img, kernel::Tuple{AnyIIR,Vararg{AnyIIR}}) = IIR()
filter_algorithm(out, img, kernel) = Mixed()

maxlen(A::AbstractArray) = _length(A)
@inline maxlen(kernel::Tuple) = _maxlen(0, kernel...)
_maxlen(len, kernel1, kernel...) = _maxlen(max(len, _length(kernel1)), kernel...)
_maxlen(len) = len

_length(A::AbstractArray) = length(linearindices(A))
_length(A::ReshapedVector) = _length(A.data)

isseparable(kernels::Tuple{Vararg{AnyIIR}}) = true
isseparable(kernels::Tuple) = all(x->nextendeddims(x)==1, kernels)

normalize_separable!(r::AbstractResource, A, ::Tuple{}, border) = error("this shouldn't happen")
function normalize_separable!{N}(r::AbstractResource, A, kernels::NTuple{N,TriggsSdika}, border)
    inds = indices(A)
    function imfilter_inplace!(r, a, kern, border)
        imfilter!(r, a, a, (kern,), border)
    end
    filtdims = ntuple(d->imfilter_inplace!(r, similar(dims->ones(dims), inds[d]), kernels[d], border), Val{N})
    normalize_dims!(A, filtdims)
end
function normalize_separable!{N}(r::AbstractResource, A, kernels::NTuple{N,ReshapedIIR}, border)
    normalize_separable!(r, A, map(_vec, kernels), border)
end

function normalize_separable!{N}(r::AbstractResource, A, kernels::NTuple{N}, border)
    inds = indices(A)
    filtdims = ntuple(d->imfilter(r, similar(dims->ones(dims), inds[d]), _vec(kernels[d]), border), Val{N})
    normalize_dims!(A, filtdims)
end

function normalize_dims!{T,N}(A::AbstractArray{T,N}, factors::NTuple{N})
    for I in CartesianRange(indices(A))
        tmp = A[I]/factors[1][I[1]]
        for d = 2:N
            tmp /= factors[d][I[d]]
        end
        A[I] = tmp
    end
    A
end

iscopy(kernel::AbstractArray) = all(x->x==0:0, indices(kernel)) && first(kernel) == 1
iscopy(kernel::Laplacian) = false
iscopy(kernel::TriggsSdika) = all(x->x==0, kernel.a) && all(x->x==0, kernel.b) && kernel.scale == 1
iscopy(kernel::ReshapedOneD) = iscopy(kernel.data)

kernelconv(kernel) = kernel
function kernelconv(k1, k2, kernels...)
    out = similar(Array{filter_type(eltype(k1), k2)}, calculate_padding((k1, k2)))
    fill!(out, zero(eltype(out)))
    k1N, k2N = samedims(out, k1), samedims(out, k2)
    R1, R2 = CartesianRange(indices(k1N)), CartesianRange(indices(k2N))
    for I1 in R1
        for I2 in R2
            out[I1+I2] += k1N[I1]*k2N[I2]
        end
    end
    kernelconv(out, kernels...)
end

default_resource(alg::FIR) = Threads.nthreads() > 1 ? CPUThreads(alg) : CPU1(alg)
default_resource(alg) = CPU1(alg)

## Tiling utilities

function tile_allocate{T}(::Type{T}, kernel::Tuple{Any,Any})
    sz = map(length, calculate_padding(kernel))
    tsz = padded_tilesize(T, sz)
    [Array{T}(tsz) for i = 1:Threads.nthreads()]
end

function tile_allocate{T}(::Type{T}, kernel::Tuple{Any,Any,Vararg{Any}})
    # Allocate a pair of tiles and swap buffers at each stage
    sz = map(length, calculate_padding(kernel))
    tsz = padded_tilesize(T, sz)
    [(Array{T}(tsz), Array{T}(tsz)) for i = 1:Threads.nthreads()]
end

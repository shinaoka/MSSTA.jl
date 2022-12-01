function _single_tensor_flip()
    cval = [-1, 0]
    # (cin, cout, s', s)
    single_tensor = zeros(Float64, 2, 2, 2, 2)
    for icin in 1:2
        for a in 1:2
            out = -(a - 1) + cval[icin]
            icout = out < 0 ? 1 : 2
            b = mod(out, 2) + 1
            single_tensor[icin, icout, a, b] = 1
        end
    end
    return single_tensor
end

"""
f(x) = g(1 - x) = M * g(x)
"""
function flipop(sites::Vector{Index{T}}; rev_carrydirec=false, bc::Int=1)::MPO where {T}
    N = length(sites)
    abs(bc) == 1 || error("bc must be either 1, -1")
    N > 1 || error("MPO with one tensor is not supported")

    t = _single_tensor_flip()
    M = MPO(N)
    links = [Index(2, "Link,l=$l") for l in 1:(N + 1)]
    for n in 1:N
        M[n] = ITensor(t, (links[n], links[n + 1], sites[n]', sites[n]))
    end

    M[1] *= onehot(links[1] => 2)

    bc_tensor = ITensor([1.0, bc], links[end])
    M[N] = M[N] * bc_tensor

    if rev_carrydirec
        M = _reverse(M)
    end

    cleanup_linkinds!(M)

    return M
end

function reverseaxis(M::MPS; tag="", bc::Int=1, kwargs...)
    sites = siteinds(M)
    targetsites = sites
    if tag != ""
        targetsites = findallsiteinds_by_tag(sites; tag=tag)
    end

    transformer = matchsiteinds(flipop(targetsites; rev_carrydirec=true, bc=bc), sites)

    return apply(transformer, M; kwargs...)
end


"""
Multiply by exp(i θ x), where x = (x_1, ..., x_R)_2.
"""
function phase_rotation(M::MPS, θ::Float64; targetsites=nothing, tag="")
    sitepos, target_sites = _find_target_sites(M; sitessrc=targetsites, tag=tag)
    res = copy(M)

    nqbit = length(sitepos)
    for n in 1:nqbit
        p = sitepos[n]
        res[p] *= op("Phase", siteind(res, p); ϕ=θ * 2^(nqbit - n))
    end

    return noprime(res)
end
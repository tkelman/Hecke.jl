################################################################################
#
#          NfOrdClsUnits.jl : Units in generic number field orders 
#
# This file is part of hecke.
#
# Copyright (c) 2015: Claus Fieker, Tommy Hofmann
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#
#  Copyright (C) 2015, 2016 Tommy Hofmann
#
################################################################################

export is_unit, is_torsion_unit, is_independent, unit_group

add_verbose_scope(:UnitGrp)

################################################################################
#
#  Initialization 
#
################################################################################

function _unit_group_init(O::NfMaxOrd)
  u = UnitGrpCtx{FacElem{nf_elem}}(O)
  return u
end

################################################################################
#
#  Field access
#
################################################################################

order(u::UnitGrpCtx) = u.order

################################################################################
#
#  String I/O
#
################################################################################

function show(io::IO, U::UnitGrpCtx)
  print(io, "Unit group context of\n$(order(U))\n")
end

################################################################################
#
#  Unit rank
#
################################################################################

doc"""
***
    unit_rank(O::NfOrdCls) -> Int

> Returns the unit rank of $\mathcal O$, that is, the rank of the unit group
> $\mathcal O^\times$.
"""
function unit_rank(O::NfOrdCls)
  r1, r2 = signature(nf(O))
  return r1 + r2 - 1
end

################################################################################
#
#  Testing for invertibility
#
################################################################################

doc"""
***
    is_unit(x::NfOrdElem) -> Bool

> Returns whether $x$ is invertible or not.
"""
function is_unit(x::NfOrdElem)
  return abs(norm(x)) == 1 
end

_is_unit(x::NfOrdElem) = is_unit(x)

function _is_unit{T <: Union{nf_elem, FacElem{nf_elem}}}(x::T)
  return abs(norm(x)) == 1
end

################################################################################
#
#  Torsion unit test
#
################################################################################

doc"""
***
    is_torsion_unit(x::NfOrdElem, checkisunit::Bool = false) -> Bool

> Returns whether $x$ is a torsion unit, that is, whether there exists $n$ such
> that $x^n = 1$.
> 
> If `checkisunit` is `true`, it is first checked whether $x$ is a unit of the
> maximal order of the number field $x$ is lying in.
"""
function is_torsion_unit(x::NfOrdElem, checkisunit::Bool = false)
  return is_torsion_unit(x.elem_in_nf, checkisunit)
end

################################################################################
#
#  Order of a single torsion unit
#
################################################################################

doc"""
***
    torsion_unit_order(x::NfOrdElem, n::Int)

> Given a torsion unit $x$ together with a multiple $n$ of its order, compute
> the order of $x$, that is, the smallest $k \in \mathbb Z_{\geq 1}$ such
> that $x^k = 1$.
>
> It is not checked whether $x$ is a torsion unit.
"""
function torsion_unit_order(x::NfOrdElem, n::Int)
  return torsion_unit_order(x.elem_in_nf, n)
end

################################################################################
#
#  Torsion unit group
#
################################################################################

doc"""
***
    torsion_units(O::NfOrdCls) -> Array{NfOrdElem, 1}

> Given an order $O$, compute the torsion units of $O$.
"""
function torsion_units(O::NfOrdCls)
  ar, g = _torsion_units(O)
  return ar
end

doc"""
***
    torsion_units(O::NfOrdCls) -> NfOrdElem

> Given an order $O$, compute a generator of the torsion units of $O$.
"""
function torsion_units_gen(O::NfOrdCls)
  ar, g = _torsion_units(O)
  return g
end

function _torsion_units(O::NfOrdCls)
  if isdefined(O, :torsion_units)
    return O.torsion_units
  end

  n = degree(O)
  K = nf(O)
  rts = conjugate_data_arb(K)
  A = ArbField(rts.prec)
  M = ArbMatSpace(A, n, n)()
  r1, r2 = signature(K)
  B = basis(O)

  if r1 > 0
    return [ O(1), -O(1) ], -O(1)
  end

  function _t2_pairing(x, y, p)
    local i
    v = minkowski_map(x, p)
    w = minkowski_map(y, p)
 
    t = zero(parent(v[1]))
 
    for i in 1:r1
      t = t + v[i]*w[i]
    end
 
    for i in (r1 + 1):(r1 + 2*r2)
      t = t + v[i]*w[i]
    end
 
    return t
  end

  p = 64

  gram_found = false

  while !gram_found
    for i in 1:n, j in 1:n
      M[i,j] = _t2_pairing(B[i], B[j], p)
      if !isfinite(M[i, j])
        p = 2*p
        break
      end
    end
    gram_found = true
  end

  l = enumerate_using_gram(M, A(n))

  R = Array{NfOrdElem, 1}()

  for i in l
    if O(i) == zero(O)
      continue
    end
    if is_torsion_unit(O(i))
      push!(R, O(i))
    end
  end

  i = 0

  for i in 1:length(R)
    if torsion_unit_order(R[i], length(R)) == length(R)
      break
    end
  end

  O.torsion_units = R, deepcopy(R[i])

  return O.torsion_units
end

################################################################################
#
#  Test if units are independent
#
################################################################################

doc"""
***
    is_independent{T}(x::Array{T, 1})

> Given an array of non-zero elements in a number field, returns whether they
> are multiplicatively independent.
"""
function is_independent{T}(x::Array{T, 1})
  K = _base_ring(x[1])

  deg = degree(K)
  r1, r2 = signature(K)
  rr = r1 + r2
  r = rr - 1 # unit rank

  p = 32

  # This can be made more memory friendly
  while true
    @assert p != 0

    conlog = conjugates_arb_log(x[1], -p)

    A = MatrixSpace(parent(conlog[1]), length(x), rr)()

    for i in 1:rr
      A[1, i] = conlog[i]
    end

    Ar = base_ring(A)

    for k in 2:length(x)
      conlog = conjugates_arb_log(x[k], -p)
      for i in 1:rr
        A[k, i] = conlog[i]
      end
    end

    B = A*transpose(A)
    @vprint :UnitGrp 2 "Computing det of $(rows(B))x$(cols(B)) matrix with precision $(p) ... \n"
    d = det(B)

    y = (Ar(1)//Ar(r))^r * (Ar(21)//Ar(128) * log(Ar(deg))//(Ar(deg)^2))^(2*r)
    if isfinite(d) && ispositive(y - d)
      return false
    elseif isfinite(d) && ispositive(d)
      return true
    end
    p = 2*p
  end
end

# Checks whether x[1]^z[1] * ... x[n]^z[n]*y^[n+1] is a torsion unit
# This can be improved
function _check_relation_mod_torsion{T}(x::Array{T, 1}, y::T, z::Array{fmpz, 1})
  (length(x) + 1 != length(z)) && error("Lengths of arrays does not fit")
  r = x[1]^z[1]

  for i in 2:length(x)
    r = r*x[i]^z[i]
  end 

  w = r*y^z[length(z)]

  return is_torsion_unit(w)
end

function _find_rational_relation!(rel::Array{fmpz, 1}, v::arb_mat, bound::fmpz)
  @vprint :UnitGrp 2 "Finding rational approximation in $v\n"
  r = length(rel) - 1

  z = Array(fmpq, r)
  
  # Compute an upper bound in the denominator of an entry in the relation
  # using Cramer's rule and lower regulator bounds

  # No comes the rational approximation phase

  # First a trivial check:
  # If the relation contains only integers, it does not yield any information

  i = 0

  is_integer = true

  while is_integer && i < r
    i = i + 1
    b, o = unique_integer(v[1, i])
    if b
      rel[i] = o
    end
    is_integer = is_integer && b
  end

  if is_integer
    rel[r + 1] = -1
    @vprint :UnitGrp 2 "Found rational relation.\n"
    return true
  end

  for i in 1:r
    if radius(v[1, i]) > 1
      # This is a strange case I cannot handle at the moment
      return false
      #no_change_matrix = MatrixSpace(ZZ, r, r)(1)
      #no_change_matrix = vcat(no_change_matrix, MatrixSpace(ZZ, 1, r)(0))
      #return x, no_change_matrix
    end

    app =  _frac_bounded_2(v[1, i], bound)
    if app[1]
      z[i] = app[2]
    else
      @vprint :UnitGrp 2 "Something went wrong with the approximation.\n"
      return false
    end
  end

  dlcm = den(z[1])

  for i in 2:length(z)
    dlcm = lcm(dlcm, den(z[i]))
  end

  for i in 1:r
    rel[i] = num(z[i]*dlcm)
  end 

  rel[r + 1] = -dlcm

  # Check that relation is primitive
  g = rel[1]

  for i in 1:length(rel)
    g = gcd(g, rel[i])
    if g == 1
      break
    end
  end

  @assert g == 1

  @vprint :UnitGrp 2 "Found rational relation.\n"
  return true
end

# Given r elements x_1,...,x_r, where r is the unit rank, and y an additional unit,
# compute a basis z_1,...z_r such that <x_1,...x_r,y,T> = <z_1,...,z_r,T>,
# where T are the torsion units
function _find_relation{S, T}(x::Array{S, 1}, y::T, p::Int = 64)
  
  K = _base_ring(x[1])

  deg = degree(K)
  r1, r2 = signature(K)
  rr = r1 + r2
  r = rr - 1 # unit rank

  R = ArbField(p)
  #println("precision is $(c.prec)");

  zz = Array(fmpz, r + 1)

  @vprint :UnitGrp 1 "Computing conjugates log matrix ... \n"
  A = _conj_log_mat_cutoff(x, p)

  Ar = base_ring(A)

  b = ArbMatSpace(Ar, 1, r)()

  conlog = conjugates_arb_log(y, -p)

  for i in 1:r
    b[1, i] = conlog[i]
  end

  B = parent(A)()


  # I should do this using lu decomposition and caching
  # The inversion could go wrong,
  # Then we again have to increase the precision

  inv_succesful = false

  try
    @vprint :UnitGrp 1 "Inverting matrix ... \n"
    B = inv(A)
    inv_succesful = true
  catch
    @vprint :UnitGrp 1 "Cannot invert matrix ... \n"
  end
      
  v = b*B

  z = Array(fmpq, r)
  
  rreg = det(A)

  bound = _denominator_bound_in_relation(rreg, K)

  # Compute an upper bound in the denominator of an entry in the relation
  # using Cramer's rule and lower regulator bounds


  rel = Array(fmpz, r + 1)
  for i in 1:r+1
    rel[i] = zero(FlintZZ)
  end

  while !inv_succesful || !_find_rational_relation!(rel, v, bound)
    p =  2*p

    inv_succesful = false

    A = _conj_log_mat_cutoff(x, p)

    Ar = base_ring(A)

    b = ArbMatSpace(Ar, 1, r)()

    conlog = conjugates_arb_log(y, -p)

    for i in 1:r
      b[1, i] = conlog[i]
    end

    if !inv_succesful
      try
        @vprint :UnitGrp 1 "Inverting matrix ... \n"
        B = inv(A)
        inv_succesful = true
      catch
        @vprint :UnitGrp 1 "Cannot invert matrix. Increasing precision to $(2*p)\n"
      end
    end
        
    v = b*B
  end

  # Check if it is a relation modulo torsion units!
  @vprint :UnitGrp 1 "Checking relation $rel \n"

  if !_check_relation_mod_torsion(x, y, rel)
    #error("Dirty approximation did not work")
    return _find_relation(x, y, 2*p)
    #rel[r + 1 ] = 0
    #return rel
  end

  @vprint :UnitGrp 1 "Found a valid relation!\n"
  return rel
end

function _denominator_bound_in_relation(rreg::arb, K::AnticNumberField)
  # Compute an upper bound in the denominator of an entry in the relation
  # using Cramer's rule and lower regulator bounds

  arb_bound = rreg * inv(lower_regulator_bound(K))

  # I want to get an upper bound as an fmpz
  tm = arf_struct(0, 0, 0, 0)
  ccall((:arf_init, :libarb), Void, (Ptr{arf_struct}, ), &tm)

  ccall((:arb_get_abs_ubound_arf, :libarb), Void, (Ptr{arf_struct}, Ptr{arb}, Int), &tm, &arb_bound, 64)

  bound = fmpz()

  # round towards +oo
  ccall((:arf_get_fmpz, :libarb), Void, (Ptr{fmpz}, Ptr{arf_struct}, Cint), &bound, &tm, 3)

  ccall((:arf_clear, :libarb), Void, (Ptr{arf_struct}, ), &tm)

  return bound
end

function _transform(x::Array{nf_elem}, y::fmpz_mat)
  n = length(x)
  @assert n == rows(y)
  m = cols(y)
  z = Array(nf_elem, m)
  for i in 1:m
    z[i] = x[1]^y[1, i]
    for j in 2:n
      z[i] = z[i]*x[j]^y[j, i]
    end
  end
  return z
end

function _frac_bounded_2(y::arb, bound::fmpz)
  p = prec(parent(y))
  x = _arb_get_fmpq(y)
  n = 1
  c = cfrac(x, n)[1]
  q = fmpq(c)

  new_q = q

  while nbits(num(new_q)) < div(p, 2) && nbits(den(new_q)) < div(p, 2) && den(new_q) < bound

    if contains(y, new_q)
      return true, new_q
    end
   
    n = n + 1
    c = cfrac(x, n)[1]
    new_q = fmpq(c)

  end
  return false, zero(FlintQQ)
end

function _max_frac_bounded(x::fmpq, b::fmpz)
  n = 2
  c = cfrac(x, n)[1]
  q = fmpq(c)

  while abs(den(q)) < b && q != x
    n = 2*n
    c = cfrac(x, n)[1]
    q = fmpq(c)
  end

  while abs(den(q)) > b
    n = n - 1
    c = cfrac(x, n)[1]
    q = fmpq(c)
  end

  return n
end

function _rel_add_prec(U)
  return U.rel_add_prec
end

function _add_dependent_unit{S, T}(U::UnitGrpCtx{S}, y::T)
  K = nf(order(U))
  deg = degree(K)
  r1, r2 = signature(K)
  rr = r1 + r2
  r = rr - 1 # unit rank

  #println("precision is $(c.prec)");

  p = _rel_add_prec(U)
  
  #p = 64

  zz = Array(fmpz, r + 1)

  @v_do :UnitGrp 1 pushindent()
  p, B = _conj_log_mat_cutoff_inv(U, p)
  @v_do :UnitGrp 1 popindent()
  @vprint :UnitGrp 2 "Precision is now $p\n"

  Ar = base_ring(B)

  b = ArbMatSpace(Ar, 1, r)()

  conlog = conjugates_arb_log(y, -p)

  for i in 1:r
    b[1, i] = conlog[i]
  end

  # I should do this using lu decomposition and caching
  # The inversion could go wrong,
  # Then we again have to increase the precision

  inv_succesful = true

  @vprint :UnitGrp 3 "For $p element b: $b\n"
  v = b*B
  @vprint :UnitGrp 3 "For $p the vector v: $v\n"

  z = Array(fmpq, r)

  rreg = arb()

  if isdefined(U, :tentative_regulator)
    rreg = U.tentative_regulator
  else
    rreg = regulator(U.units, 64)
  end

  bound = _denominator_bound_in_relation(rreg, K)

    rel = Array(fmpz, r + 1)
  for i in 1:r+1
    rel[i] = zero(FlintZZ)
  end
  
  @vprint :UnitGrp 2 "First iteration to find a rational relation ... \n"
  while !_find_rational_relation!(rel, v, bound)
    @vprint :UnitGrp 2 "Precision not high enough, increasing from $p to $(2*p)\n"
    p =  2*p

    p, B = _conj_log_mat_cutoff_inv(U, p)

    conlog = conjugates_arb_log(y, -p)

    b = ArbMatSpace(parent(conlog[1]), 1, r)()

    for i in 1:r
      b[1, i] = conlog[i]
    end

    @vprint :UnitGrp 3 "For $p element b: $b\n"

    v = b*B
    @vprint :UnitGrp 3 "For $p the vector v: $v\n"
  end

  @vprint :UnitGrp 3 "For $p rel: $rel\n"

  @vprint :UnitGrp 2 "Second iteration to check relation ... \n"
  while !_check_relation_mod_torsion(U.units, y, rel)
    @vprint :UnitGrp 2 "Precision not high enough, increasing from $p to $(2*p)\n"
    p = 2*p
    p, B = _conj_log_mat_cutoff_inv(U, p)

    conlog = conjugates_arb_log(y, -p)

    b = ArbMatSpace(parent(conlog[1]), 1, r)()

    for i in 1:r
      b[1, i] = conlog[i]
    end

    @vprint :UnitGrp 3 "For $p element b: $b\n"
    v = b*B
    @vprint :UnitGrp 3 "For $p the vector v: $v\n"
    _find_rational_relation!(rel, v, bound)
    @vprint :UnitGrp 3 "For $p rel: $rel\n"
  end

  if abs(rel[r + 1]) == 1 || rel[r + 1] == 0
    U.rel_add_prec = p
    return false
  end
  
  m = MatrixSpace(FlintZZ, r + 1, 1)(reshape(rel, r + 1, 1))

  h, u = hnf_with_transform(m)

  @assert h[1,1] == 1

  u = inv(u)

  m = submat(u, 1:r+1, 2:r+1)

  U.units =  _transform(vcat(U.units, y), m)

  U.conj_log_mat_cutoff = Dict{Int, arb_mat}()
  U.conj_log_mat_cutoff_inv = Dict{Int, arb_mat}()
  U.tentative_regulator = regulator(U.units, 64)
  U.rel_add_prec = p
  return true
end

function _conj_log_mat_cutoff{T}(x::Array{T, 1}, p::Int)
  r = length(x)
  conlog = conjugates_arb_log(x[1], -p)
  A = ArbMatSpace(parent(conlog[1]), r, r)()

  for i in 1:r
    A[1, i] = conlog[i]
  end

  for k in 2:r
    conlog = conjugates_arb_log(x[k], -p)
    for i in 1:r
      A[k, i] = conlog[i]
    end
  end
  return A
end

function _conj_log_mat_cutoff(x::UnitGrpCtx, p::Int)
  if haskey(x.conj_log_mat_cutoff,  p)
    @vprint :UnitGrp 2 "Conj matrix for $p cached\n"
    return x.conj_log_mat_cutoff[p]
  else
    @vprint :UnitGrp 2 "Conj matrix for $p not cached\n"
    x.conj_log_mat_cutoff[p] = _conj_log_mat_cutoff(x.units, p)
    return x.conj_log_mat_cutoff[p]
  end
end

function _conj_log_mat_cutoff_inv(x::UnitGrpCtx, p::Int)
  @vprint :UnitGrp 2 "Computing inverse of conjugates log matrix (starting with prec $p) ... \n"
  if haskey(x.conj_log_mat_cutoff_inv,  p)
    @vprint :UnitGrp 2 "Inverse matrix cached for $p\n"
    return p, x.conj_log_mat_cutoff_inv[p]
  else
    @vprint :UnitGrp 2 "Inverse matrix not cached for $p\n"
    try
      @vprint :UnitGrp 2 "Trying to invert conj matrix with prec $p \n"
      @vprint :UnitGrp 3 "Matrix to invert is $(_conj_log_mat_cutoff(x, p))"
      x.conj_log_mat_cutoff_inv[p] = inv(_conj_log_mat_cutoff(x, p))
      @vprint :UnitGrp 2 "Successful. Returning with prec $p \n"
      @vprint :UnitGrp 3 "$(x.conj_log_mat_cutoff_inv[p])\n"
      return p, x.conj_log_mat_cutoff_inv[p]
    catch e
      println(e)
      @vprint :UnitGrp 2 "Increasing precision .."
      @v_do :UnitGrp 2 pushindent()
      r = _conj_log_mat_cutoff_inv(x, 2*p)
      @v_do :UnitGrp 2 popindent()
      return r
    end
  end
end

# Powering function for fmpz exponents
function _pow{T}(x::Array{T, 1}, y::Array{fmpz, 1})
  K = _base_ring(x[1])

  zz = deepcopy(y)

  z = Array(fmpz, length(x))

  for i in 1:length(x)
    z[i] = mod(zz[i], 2)
    zz[i] = zz[i] - z[i]
  end

  r = K(1)

  return zz
end

################################################################################
#
#  Free part of the unit group
#
################################################################################

doc"""
***
    regulator(x::Array{T, 1}, abs_tol::Int) -> arb

> Compute the regulator $r$ of the elements in $x$, such that the radius of $r$
> is less then `2^abs_tol`.
"""
function regulator{T}(x::Array{T, 1}, abs_tol::Int)
  K = _base_ring(x[1])
  deg = degree(K)
  r1, r2 = signature(K)
  rr = r1 + r2
  r = rr - 1 # unit rank

  p = 32

  while true
    conlog = conjugates_arb_log(x[1], -p)

    A = ArbMatSpace(parent(conlog[1]), r, r)()

    for j in 1:r
      A[1, j] = conlog[j]
    end

    for i in 2:r
      conlog = conjugates_arb_log(x[i], -p)
      for j in 1:r
        A[i, j] = conlog[j]
      end
    end

    z = abs(det(A))

    if isfinite(z) && radiuslttwopower(z, abs_tol)
      return z
    end
    
    p = 2*p
  end
end

function _make_row_primitive(x::fmpz_mat, j::Int)
  y = x[j, 1]
  for i in 1:cols(x)
    y = gcd(y, x[j, i])
  end
  if y > 1
    for i in 1:cols(x)
      x[j, i] = div(x[j, i], y)
    end
  end
end

################################################################################
#
#  Compute unit group from class group context
#
################################################################################

function _unit_group(O::NfMaxOrd, c::ClassGrpCtx)
  u = UnitGrpCtx{FacElem{nf_elem}}(O)
  _unit_group_find_units(u, c)
  return u
end

# TH:
# Current strategy
# ================
# Compute a basis of the kernel of the relation matrix (as fmpz_mat).
# In the first round try to find r independent units, r is the unit rank.
# In the second round, try to enlarge the unit group.
function _unit_group_find_units(u::UnitGrpCtx, x::ClassGrpCtx)
  @vprint :UnitGrp 1 "Processing ClassGrpCtx to find units ... \n"

  O = order(u)

  @vprint :UnitGrp 1 "Computing the kernel of relation matrix ... \n"

  #ker, rnk = nullspace(transpose(fmpz_mat(x.M)))

  #println(ker)
  time_kernel = @elapsed ker =  _kernel(fmpz_mat(x.M))
  rnk = rows(ker)

  @vprint :UnitGrp 1 "Kernel has dimension $rnk\n"

  #ker = transpose(ker)

  K = nf(order(x.FB.ideals[1]))
  r = unit_rank(O)
  r1, r2 = signature(O)

  A = u.units

  j = 0

  used_elts = Dict{Int, Bool}()

  while(length(A) < r)
    @vprint :UnitGrp 1 "Found $(length(A)) independent units so far ($(r - length(A)) left to find)\n"
    j = j + 1

    if j > rows(ker)
      return length(A)
    end

    if is_zero_row(ker, j)
      continue
    end

    _make_row_primitive(ker, j)

    y = FacElem(x, ker, j)
    
    if is_torsion_unit(y)
      continue
    end
    _add_unit(u, y)
    used_elts[j] = true
  end
  @vprint :UnitGrp 1 "Found $r linear independent units \n"

  u.full_rank = true

  j = 0

  not_larger = 0

  time_add_dep_unit = 0.0

  @vprint :UnitGrp 1 "Enlarging unit group by adding remaining kernel basis elements ...\n"
  while(j < rows(ker)) && not_larger < 5 
    j = j + 1

    if haskey(used_elts, j)
      continue
    end

    if is_zero_row(ker, j)
      continue
    end

    y = FacElem(x, ker, j)
    
    @vprint :UnitGrp 2 "Test if kernel element yields torsion unit ... \n"
    @v_do :UnitGrp 2 pushindent()
    if is_torsion_unit(y)
      @v_do :UnitGrp 2 popindent()
      #println("torsion unit: $y")
      @vprint :UnitGrp 2 "Element is torsion unit\n"
      continue
    end
    @v_do :UnitGrp 2 popindent()

    @v_do :UnitGrp 2 pushindent()
    time_add_dep_unit += @elapsed m = _add_dependent_unit(u, y)
    @v_do :UnitGrp 2 popindent()

    if !m
      not_larger = not_larger + 1
    else
      not_larger = 0
    end

    #println(_reg(u.units))
  end

  u.tentative_regulator = regulator(u.units, -64)

  @vprint :UnitGrp 1 "Finished processing\n"
  @vprint :UnitGrp 1 "Regulator of current unit group is $(u.tentative_regulator)\n"
  @vprint :UnitGrp 1 "-"^80 * "\n"
  @vprint :UnitGrp 1 "Kernel time: $time_kernel\n"
  @vprint :UnitGrp 1 "Adding dependent unit time: $time_add_dep_unit\n"
end

function _add_unit(u::UnitGrpCtx, x::FacElem{nf_elem})
  if is_independent(vcat(u.units, [x]))
    push!(u.units, x)
  end
  nothing
end

################################################################################
#
#  Size reduction
#
################################################################################

function _reduce_size{T}(x::Array{T, 1}, prec::Int = 64)
  K = _base_ring(x[1])

  deg = degree(K)
  r1, r2 = signature(K)
  rr = r1 + r2
  r = rr - 1 # unit rank

  conlog = conjugates_arb_log(x[1], -prec)

  A = MatrixSpace(parent(conlog[1]), length(x), rr)()

  B = MatrixSpace(FlintZZ, rows(A), cols(A))()

  for i in 1:rr
    A[1, i] = conlog[i]
  end

  Ar = base_ring(A)

  for i in 1:rows(A)
    for j in 1:cols(A)
      b, y = unique_integer(ceil(ldexp(A[i, j], 64)))
      @assert b
      B[i, j] = y
    end
  end

  L, U = lll_with_transform(B)
end


################################################################################
#
#  Saturation
#
################################################################################

# TH:
# Let U = <u_1,...,u_n,z> with z a generator for Tor(U)
# For a prime p the group U/U^p is F_p-vector space of dimension
# rank(U) or rank(U) + 1 (depending on the order of z).
# if p divides N(P) - 1 = #F_P*, then F_P*/F_P*^p is a one-dimensional
# F_p-vector space. Thus the canonical map F_p-linear
#               U/U^p -> F_P*/F_P*^p
# can be described by a 1 x (rank(U)) or 1 x (rank(U) + 1) matrix over F_p,
# and can be computed by solving discrete logarithms in F_P
#
function _is_saturated(U::UnitGrpCtx, p::Int, B::Int = 2^30 - 1, proof::Bool = false)
  if proof
    error("Not yet implemented")
  end

  N = 3*unit_rank(order(U))

  @vprint :UnitGrp 1 "Computing $N prime ideals for saturation ...\n"

  primes =  _find_primes_for_saturation(order(U), p, N, B)
  
  m = _matrix_for_saturation(U, primes[1], p)

  for i in 2:N
    m = vcat(m, _matrix_for_saturation(U, primes[i], p))
  end

  @vprint :UnitGrp 1 "Computing kernel of p-th power map ...\n"
  (K, k) = _right_kernel(m)

  K = transpose(K)
  L = lift(K)
  T = typeof(L[1,1])

  nonzerorows = Array{Int, 1}()

  for j in 1:rows(L)
    if !is_zero_row(L, j)
      push!(nonzerorows, j)
    end
  end

  if k == 0 
    return (true, zero(nf(order(U))))
  elseif k == 1 && sum(T[ L[nonzerorows[1], i]::T for i in 1:cols(L)-1]) == 0
    # Only one root, which is torsion.
    # We assume that the torsion group is the full torsion group
    return (true, zero(nf(order(U))))
  else
    for j in nonzerorows

      
      a = U.units[1]^(L[j, 1])
      for i in 2:length(U.units)
        a = a*U.units[i]^L[j, i]
      end
      
      if gcd(p, U.torsion_units_order) != 1
        a = a*elem_in_nf(U.torsion_units_gen)^L[j, length(U.units) + 1]
      end

      b = evaluate(a)

      @vprint :UnitGrp 1 "Testing/computing root ... \n"

      has_root, roota = root(b, p)

      if !has_root
        continue
      end

      return (false, roota)
    end
  end

  # try some random linear combination of kernel vectors

  MAX = 10

  for i in 1:MAX

    ra = rand(0:p-1, rows(K))
    v = MatrixSpace(base_ring(K), 1, cols(K))(0)
    for j in 1:cols(K)
      for l in 1:rows(K)
        v[1, j] = v[1, j] + ra[l]*K[l,j]
      end
    end

    if v == parent(v)(0)# || sum([v[1, j] for j in 1:rows(K)-1]) == 0
      continue
    end
    
    v = lift(v)

    a = U.units[1]^(v[1, 1])
    for j in 2:length(U.units)
      a = a*U.units[j]^v[1, j]
    end

    if gcd(p, U.torsion_units_order) != 1
      a = a*elem_in_nf(U.torsion_units_gen)^v[1, length(U.units) + 1]
    end

    b = evaluate(a)

    has_root, roota = root(b, p)

    if has_root
      return (false, roota)
    end
  end

  return (true, zero(nf(order(U))))
end

# The output will be of type
# elem_type(MatrixSpace(ResidueRing(ZZ, p), 1, rank(U) ( + 1))), so
# nmod_mat or fmpz_mod_mat
# THIS FUNCTION IS NOT TYPE STABLE
function _matrix_for_saturation(U::UnitGrpCtx, P::NfMaxOrdIdl, p::Int)
  O = order(U)
  K = nf(O)
  F, mF = ResidueField(O, P)
  mK = extend(mF, K)
  g = _primitive_element(F)

  # We have to add the generator of the torsion group
  if gcd(p, U.torsion_units_order) != 1
    res = MatrixSpace(ResidueRing(FlintZZ, p), 1, unit_rank(O) + 1)()
  else
    res = MatrixSpace(ResidueRing(FlintZZ, p), 1, unit_rank(O))()
  end

  t = K()

  for i in 1:length(U.units)
    u = U.units[i]
    y = one(F)

    # P.gen_two should be P-unformizer
    #println("$(P.gen_one), $b, $(P.gen_two)")

    for b in base(u)
      t = b*K(P.gen_two)^(-valuation(b, P))

      if mod(den(t), minimum(P)) == 0
        l = valuation(den(t), P)
        y = y*(mK(t*elem_in_nf(P.anti_uniformizer)^l)*mF(P.anti_uniformizer)^(-l))^u.fac[b]
      else
        y = y*mK(t)^u.fac[b]
      end
    end

    res[1, i] = disc_log(y, g, p)
  end

  if gcd(p, U.torsion_units_order) != 1
    res[1, unit_rank(O) + 1] = disc_log(mF(U.torsion_units_gen), g, p)
  end

  return res
end

# TH:
# This function finds n prime ideals P of O such that p divides N(P) - 1
# Moreover the prime ideals are unramified and min(P) does not divide
# the index of O in the equation order.
#
# The function loops through all prime ideals ordered by the minimum,
# starting at next_prime(st)
function _find_primes_for_saturation(O::NfMaxOrd, p::Int, n::Int,
                                     st::Int = 0)
  res = Array(NfMaxOrdIdl, n)
  i = 0

  q = st
  while i < n
    q = next_prime(q)

    if mod(index(O), q) == 0 || isramified(O, q)
      continue
    end

    lp = prime_decomposition(O, q)

    j = 1

    while j <= length(lp) && i < n
      Q = lp[j]
      if mod(norm(Q[1]) - 1, p) == 0
        i = i + 1
        res[i] = Q[1]
      end
      j = j + 1
    end
  end

  return res
end
        
function _primitive_element(F::FqNmodFiniteField)
  #println("Computing primitive element of $F")
  #println("Have to factor $(order(F) - 1)")
  fac = factor(order(F) - 1)
  while true
    a = rand(F)
    if iszero(a)
      continue
    end
    is_primitive = true
    for l in keys(fac)
      if isone(a^(div(order(F) - 1, l)))
        is_primitive = false
        break
      end
    end
    if is_primitive
      return a
    end
  end
end

function _refine_with_saturation(c::ClassGrpCtx, u::UnitGrpCtx)
  @vprint :UnitGrp "Enlarging unit group using saturation ... \n"

  b = _validate_class_unit_group(c, u)

  p = 2

  while b > 1
    @vprint :UnitGrp 1 "Saturating at $p ... \n"

    @v_do :UnitGrp 1 pushindent()
    issat, new_unit = _is_saturated(u, p)
    @v_do :UnitGrp 1 popindent()

    while !issat
      #println("I have found a new unit: $new_unit")
      _add_dependent_unit(u, FacElem(new_unit))
      #println("$(u.tentative_regulator)")
      
      @v_do :UnitGrp 1 pushindent()
      b = _validate_class_unit_group(c, u)
      @v_do :UnitGrp 1 popindent()

      if b == 1
        break
      end

      @v_do :UnitGrp 1 pushindent()
      issat, new_unit = _is_saturated(u, p)
      @v_do :UnitGrp 1 popindent()
    end

    @v_do :UnitGrp 1 pushindent()
    b = _validate_class_unit_group(c, u)
    @v_do :UnitGrp 1 popindent()

    p = next_prime(p)
    if p > b
      break
    end
  end
  return b
end

################################################################################
#
#  High level interface
#
################################################################################

doc"""
***
    unit_group(O::NfMaxOrd) -> Map

> Returns an isomorphism map $f \colon A \to \mathcal O^\times$. Let
> `A = codomain(f)`. Then a set of fundamental units of $\mathcal O$ can be
> obtained via `[ f(A[i]) for i in 1:unit_rank(O) ]`.
"""
function unit_group(O::NfMaxOrd)
  if isdefined(O, :unit_group)
    return O.unit_group::AbToNfOrdUnitGrp{Nemo.nf_elem,NfOrdElem{NfMaxOrd}}
  else
    c, U, b = _class_unit_group(O)
    _refine_with_saturation(c, U)
    f = AbToNfOrdUnitGrp(O, U.units, U.torsion_units_gen, U.torsion_units_order)
    O.unit_group = f
    return f
  end
end

function lower_regulator_bound(K::AnticNumberField)
  return ArbField(64)("0.054")
end

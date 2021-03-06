################################################################################
#
#  NfOrdCls.jl : Generic orders in number fields and elements/ideals thereof
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
#  Copyright (C) 2015 Tommy Hofmann
#
################################################################################
#
#  TODO:
#   Fix hashing 
#
################################################################################

export elem_in_order, rand, rand!, istorsionunit, NfOrdElem,
       minkowski_mat, conjugates_log, conjugates_arb, intersect, lcm,
       idempotents

################################################################################
#
#  Signature
#
################################################################################

doc"""
***
    signature(O::NfOrdCls) -> Tuple{Int, Int}

> Returns the signature of the ambient number field of $\mathcal O$.
"""
function signature(x::NfOrdCls)
  if x.signature[1] != -1
    return x.signature
  else
    x.signature = signature(nf(x).pol)
    return x.signature
  end
end

################################################################################
#
#  Discriminant
#
################################################################################

doc"""
***
    discriminant(O::NfOrdCls) -> fmpz

> Returns the discriminant of $\mathcal O$.
"""
function discriminant(O::NfOrdCls)
  return _discriminant(O)
end

function _discriminant(O::NfOrdCls)
  if isdefined(O, :disc)
    return O.disc
  end

  A = MatrixSpace(FlintZZ, degree(O), degree(O))()
  B = basis_nf(O)
  for i in 1:degree(O)
    for j in 1:degree(O)
      A[i,j] = FlintZZ(trace(B[i]*B[j]))
    end
  end
  O.disc = det(A)
  return O.disc
end

################################################################################
#
#  Minkowski matrix
#
################################################################################

doc"""
***
    minkowski_mat(O::NfOrdCls, abs_tol::Int) -> arb_mat

> Returns the Minkowski matrix of $\mathcal O$.
> Thus if $\mathcal O$ has degree $d$, then the
> result is a matrix in $\operatorname{Mat}_{d\times d}(\mathbf R)$.
> The entries of the matrix are real balls of type `arb` with radius
> less then `2^abs_tol`. 
"""

function minkowski_mat(O::NfOrdCls, abs_tol::Int)
  if isdefined(O, :minkowski_mat) && O.minkowski_mat[2] < abs_tol
    A = deepcopy(O.minkowski_mat[1])
  else
    T = Array(Array{arb, 1}, degree(O))
    B = basis(O, nf(O))
    for i in 1:degree(O)
      T[i] = minkowski_map(B[i], abs_tol)
    end
    p = maximum([ prec(parent(T[i][j])) for i in 1:degree(O), j in 1:degree(O) ])
    M = ArbMatSpace(ArbField(p), degree(O), degree(O))()
    for i in 1:degree(O)
      for j in 1:degree(O)
        M[i, j] = T[i][j]
      end
    end
    O.minkowski_mat = (M, abs_tol)
    A = deepcopy(M)
  end
  return A
end

################################################################################
################################################################################
##
##  NfOrdElem
##
################################################################################
################################################################################


################################################################################
#
#  Parent object overloading
#
################################################################################

#doc"""
#***
#    call(O::NfOrdCls, a::nf_elem, check::Bool = true) -> NfOrdElem
#
#> Given an element $a$ of the ambient number field of $\mathcal O$, this
#> function coerces the element into $\mathcal O$. It will be checked that $a$
#> is contained in $\mathcal O$ if and only if `check` is `true`.
#"""
function Base.call(O::NfMaxOrd, a::nf_elem, check::Bool = true)
  if check
    (x,y) = _check_elem_in_order(a,O)
    !x && error("Number field element not in the order")
    return NfOrdElem{NfMaxOrd}(O, deepcopy(a), y)
  else
    return NfOrdElem{NfMaxOrd}(O, deepcopy(a))
  end
end

function Base.call(O::NfOrd, a::nf_elem, check::Bool = true)
  if check
    (x,y) = _check_elem_in_order(a,O)
    !x && error("Number field element not in the order")
    return NfOrdElem{NfOrd}(O, deepcopy(a), y)
  else
    return NfOrdElem{NfOrd}(O, deepcopy(a))
  end
end

#doc"""
#***
#    call(O::NfOrdCls, a::Union{fmpz, Integer}) -> NfOrdElem
#
#> Given an element $a$ of type `fmpz` or `Integer`, this
#> function coerces the element into $\mathcal O$. It will be checked that $a$
#> is contained in $\mathcal O$ if and only if `check` is `true`.
#"""
#for T in subtypes(NfOrdCls)
#  function Base.call(O::T, a::Union{fmpz, Integer})
#    return NfOrdElem{T}(O, nf(O)(a))
#  end
#end

function Base.call(O::NfMaxOrd, a::Union{fmpz, Integer})
  return NfOrdElem{NfMaxOrd}(O, nf(O)(a))
end

function Base.call(O::NfOrd, a::Union{fmpz, Integer})
  return NfOrdElem{NfOrd}(O, nf(O)(a))
end

#doc"""
#***
#    call(O::NfOrdCls, arr::Array{fmpz, 1})
#
#> Returns the element of $\mathcal O$ with coefficient vector `arr`.
#"""
function Base.call(O::NfMaxOrd, arr::Array{fmpz, 1})
  return NfOrdElem{NfMaxOrd}(O, deepcopy(arr))
end

function Base.call(O::NfOrd, arr::Array{fmpz, 1})
  return NfOrdElem{NfOrd}(O, deepcopy(arr))
end
#
#doc"""
#***
#    call{T <: Integer}(O::NfOrdCls, arr::Array{T, 1})
#
#> Returns the element of $\mathcal O$ with coefficient vector `arr`.
#"""
function Base.call{S <: Integer}(O::NfMaxOrd, arr::Array{S, 1})
  return NfOrdElem{NfMaxOrd}(O, deepcopy(arr))
end

function Base.call{S <: Integer}(O::NfOrd, arr::Array{S, 1})
  return NfOrdElem{NfOrd}(O, deepcopy(arr))
end
#doc"""
#***
#    call(O::NfOrdCls, a::nf_elem, arr::Array{fmpz, 1}) -> NfOrdElem
#
#> This function constructs the element of $\mathcal O$ with coefficient vector
#> `arr`. It is assumed that the corresponding element of the ambient number
#> field is $a$.
#"""
for T in subtypes(NfOrdCls)
  function Base.call(O::T, a::nf_elem, arr::Array{fmpz, 1})
    return NfOrdElem{T}(O, deepcopy(a), deepcopy(arr))
  end
end

#doc"""
#***
#    call(O::NfOrdCls) -> NfOrdElem
#
#> This function constructs a new element of $\mathcal O$ which is set to $0$.
#"""
#for T in subtypes(NfOrdCls)
#  Base.call(O::T) = NfOrdElem{T}(O)
#end

Base.call(O::NfMaxOrd) = NfOrdElem{NfMaxOrd}(O)

Base.call(O::NfOrd) = NfOrdElem{NfOrd}(O)

################################################################################
#
#  Field access
#
################################################################################

doc"""
***
    parent(a::NfOrdElem) -> NfOrdCls

> Returns the order of which $a$ is an element.
"""
parent(a::NfOrdElem) = a.parent

doc"""
***
    elem_in_nf(a::NfOrdElem) -> nf_elem

> Returns the element $a$ considered as an element of the ambient number field.
"""
function elem_in_nf(a::NfOrdElem)
  if isdefined(a, :elem_in_nf)
    return a.elem_in_nf
  end
  error("Not a valid order element")
end

doc"""
***
    elem_in_basis(a::NfOrdElem) -> Array{fmpz, 1}

> Returns the coefficient vector of $a$.
"""
function elem_in_basis(a::NfOrdElem)
  @vprint :NfOrd 2 "Computing the coordinates of $a\n"
  if a.has_coord
    return a.elem_in_basis
  else
    (x,y) = _check_elem_in_order(a.elem_in_nf,parent(a))
    !x && error("Number field element not in the order")
    a.elem_in_basis = y
    a.has_coord = true
    return a.elem_in_basis
  end
end

################################################################################
#
#  Hashing
#
################################################################################

# I don't think this is a good idea

hash(x::NfOrdElem) = hash(elem_in_nf(x))

################################################################################
#
#  Equality testing
#
################################################################################

doc"""
***
    ==(x::NfOrdElem, y::NfOrdElem) -> Bool

> Returns whether $x$ and $y$ are equal.
"""
 ==(x::NfOrdElem, y::NfOrdElem) = parent(x) == parent(y) &&
                                            x.elem_in_nf == y.elem_in_nf

################################################################################
#
#  Copy
#
################################################################################

doc"""
***
    deepcopy(x::NfOrdElem) -> NfOrdElem

> Returns a copy of $x$.
"""
function deepcopy(x::NfOrdElem)
  z = parent(x)()
  z.elem_in_nf = deepcopy(x.elem_in_nf)
  if x.has_coord
    z.has_coord = true
    z.elem_in_basis = deepcopy(x.elem_in_basis)
  end
  return z
end

################################################################################
#
#  Inclusion of number field elements
#
################################################################################

# Check if a number field element is contained in O
# In this case, the second return value is the coefficient vector with respect
# to the basis of O

function _check_elem_in_order(a::nf_elem, O::NfOrdCls)
  M = MatrixSpace(ZZ, 1, degree(O))()
  t = FakeFmpqMat(M)
  elem_to_mat_row!(t.num, 1, t.den, a)
  x = t*basis_mat_inv(O)
  v = Array(fmpz, degree(O))
  for i in 1:degree(O)
    v[i] = x.num[1,i]
  end
  return (x.den == 1, v) 
end  

doc"""
***
    in(a::nf_elem, O::NfOrdCls) -> Bool

> Checks wether $a$ lies in $\mathcal O$.
"""
function in(a::nf_elem, O::NfOrdCls)
  (x,y) = _check_elem_in_order(a,O)
  return x
end

################################################################################
#
#  Denominator in an order
#
################################################################################

doc"""
***
    den(a::nf_elem, O::NfOrdCls) -> fmpz

> Returns the smallest positive integer $k$ such that $k \cdot a$ lies in O.
"""
function den(a::nf_elem, O::NfOrdCls)
  d = den(a)
  b = d*a 
  M = MatrixSpace(ZZ, 1, degree(O))()
  elem_to_mat_row!(M, 1, fmpz(1), b)
  t = FakeFmpqMat(M, d)
  z = t*basis_mat_inv(O)
  return z.den
end

################################################################################
#
#  Special elements
#
################################################################################

doc"""
***
    zero(O::GenNford) -> NfOrdElem

> Returns an element of $\mathcal O$ which is set to zero.
"""
zero(O::NfOrdCls) = O(fmpz(0))

doc"""
***
    one(O::NfOrdCls) -> NfOrdElem

> Returns an element of $\mathcal O$ which is set to one.
"""
one(O::NfOrdCls) = O(fmpz(1))

doc"""
***
    zero(a::NfOrdElem) -> NfOrdElem

> Returns the zero in the same ring.
"""
zero(a::NfOrdElem) = parent(a)(0)

doc"""
***
    one(O::NfOrdCls) -> NfOrdElem

> Returns the one in the same ring.
"""
one(a::NfOrdElem) = parent(a)(1)


doc"""
***
    isone(a::NfOrdCls) -> Bool

> Tests if a is one.
"""
isone(a::NfOrdElem) = isone(a.elem_in_nf)

doc"""
***
    iszero(a::NfOrdCls) -> Bool

> Tests if a is one.
"""
iszero(a::NfOrdElem) = iszero(a.elem_in_nf)




################################################################################
#
#  String I/O
#
################################################################################

function show(io::IO, a::NfOrdElem)
  print(io, a.elem_in_nf)
end

################################################################################
#
#  Unary operations
#
################################################################################

doc"""
***
    -(x::NfOrdElem) -> NfOrdElem

> Returns the additive inverse of $x$.
"""
function -(x::NfOrdElem)
  z = parent(x)()
  z.elem_in_nf = - x.elem_in_nf
  return z
end

###############################################################################
#
#  Binary operations
#
###############################################################################

doc"""
***
    *(x::NfOrdElem, y::NfOrdElem) -> NfOrdElem

> Returns $x \cdot y$.
"""
function *(x::NfOrdElem, y::NfOrdElem)
  z = parent(x)()
  z.elem_in_nf = x.elem_in_nf*y.elem_in_nf
  return z
end

doc"""
***
    +(x::NfOrdElem, y::NfOrdElem) -> NfOrdElem

> Returns $x + y$.
"""
function +(x::NfOrdElem, y::NfOrdElem)
  z = parent(x)()
  z.elem_in_nf = x.elem_in_nf + y.elem_in_nf
  return z
end

doc"""
***
    -(x::NfOrdElem, y::NfOrdElem) -> NfOrdElem

> Returns $x - y$.
"""
function -(x::NfOrdElem, y::NfOrdElem)
  z = parent(x)()
  z.elem_in_nf = x.elem_in_nf - y.elem_in_nf
  return z
end

################################################################################
#
#  Ad hoc operations
#
################################################################################

doc"""
***
    *(x::NfOrdElem, y::Union{fmpz, Integer})

> Returns $x \cdot y$.
"""
function *(x::NfOrdElem, y::Integer)
  z = parent(x)()
  z.elem_in_nf = x.elem_in_nf * y
  return z
end

*(x::Integer, y::NfOrdElem) = y * x

function *(x::NfOrdElem, y::fmpz)
  z = parent(x)()
  z.elem_in_nf = x.elem_in_nf * y
  return z
end

*(x::fmpz, y::NfOrdElem) = y * x

Base.dot(x::fmpz, y::NfOrdElem) = y*x

doc"""
***
    +(x::NfOrdElem, y::Union{fmpz, Integer})

> Returns $x + y$.
"""
function +(x::NfOrdElem, y::Integer)
  z = parent(x)()
  z.elem_in_nf = x.elem_in_nf + y
  return z
end

+(x::Integer, y::NfOrdElem) = y + x

function +(x::NfOrdElem, y::fmpz)
  z = parent(x)()
  z.elem_in_nf = x.elem_in_nf + y
  return z
end

+(x::fmpz, y::NfOrdElem) = y + x

doc"""
***
    -(x::NfOrdElem, y::Union{fmpz, Integer})

> Returns $x - y$.
"""
function -(x::NfOrdElem, y::fmpz)
  z = parent(x)()
  z.elem_in_nf = x.elem_in_nf - y
  return z
end

function -(x::NfOrdElem, y::Int)
  z = parent(x)()
  z.elem_in_nf = x.elem_in_nf - y
  return z
end

-(x::fmpz, y::NfOrdElem) = y - x

-(x::Integer, y::NfOrdElem) = y - x

# No sanity checks!
function divexact(x::NfOrdElem, y::fmpz)
  z = parent(x)()
  z.elem_in_nf = divexact(x.elem_in_nf, y)
  return z
end

################################################################################
#
#  Exponentiation
#
################################################################################

doc"""
***
    ^(x::NfOrdElem, y::Union{fmpz, Int})

> Returns $x^y$.
"""
function ^(x::NfOrdElem, y::Union{fmpz, Int})
  z = parent(x)()
  z.elem_in_nf = x.elem_in_nf^y
  return z
end

################################################################################
#
#  Modular reduction
#
################################################################################

doc"""
***
    mod(a::NfOrdElem, m::Union{fmpz, Int}) -> NfOrdElem

> Reduces the coefficient vector of $a$ modulo $m$ and returns the corresponding
> element.
"""
function mod(a::NfOrdElem, m::Union{fmpz, Int})
  ar = copy(elem_in_basis(a))
  for i in 1:degree(parent(a))
    ar[i] = mod(ar[i],m)
  end
  return parent(a)(ar)
end

################################################################################
#
#  Modular exponentiation
#
################################################################################

doc"""
***
    powermod(a::NfOrdElem, i::fmpz, m::Union{fmpz, Int}) -> NfOrdElem

> Returns the element $a^i$ modulo $m$.
"""

function powermod(a::NfOrdElem, i::fmpz, p::fmpz)
  if i == 0 then
    return one(parent(a))
  end
  if i == 1 
    b = mod(a,p)
    return b
  end
  if mod(i,2) == 0 
    j = div(i, 2)
    b = powermod(a, j, p)
    b = b^2
    b = mod(b,p)
    return b
  end
  b = mod(a*powermod(a,i-1,p),p)
  return b
end  

doc"""
***
    powermod(a::NfOrdElem, i::Integer, m::Integer) -> NfOrdElem

> Returns the element $a^i$ modulo $m$.
"""
powermod(a::NfOrdElem, i::Integer, m::Integer)  = powermod(a, fmpz(i), fmpz(m))

doc"""
***
    powermod(a::NfOrdElem, i::fmpz, m::Integer) -> NfOrdElem

> Returns the element $a^i$ modulo $m$.
"""
powermod(a::NfOrdElem, i::fmpz, m::Integer)  = powermod(a, i, fmpz(m))

doc"""
***
    powermod(a::NfOrdElem, i::Integer, m::fmpz) -> NfOrdElem

> Returns the element $a^i$ modulo $m$.
"""
powermod(a::NfOrdElem, i::Integer, m::fmpz)  = powermod(a, fmpz(i), m)

################################################################################
#
#  Representation matrices
#
################################################################################

doc"""
***
    representation_mat(a::NfOrdElem) -> fmpz_mat

> Returns the representation matrix of the element $a$.
"""
function representation_mat(a::NfOrdElem)
  O = parent(a)
  A = representation_mat(a, nf(parent(a)))
  A = basis_mat(O)*A*basis_mat_inv(O)
  !(A.den == 1) && error("Element not in order")
  return A.num
end

doc"""
    representation_mat(a::NfOrdElem, K::AnticNumberField) -> FakeFmpqMat

> Returns the representation matrix of the element $a$ considered as an element
> of the ambient number field $K$. It is assumed that $K$ is the ambient number
> field of the order of $a$.
"""
function representation_mat(a::NfOrdElem, K::AnticNumberField)
  nf(parent(a)) != K && error("Element not in this field")
  d = den(a.elem_in_nf)
  b = d*a.elem_in_nf
  A = representation_mat(b)
  z = FakeFmpqMat(A,d)
  return z
end

################################################################################
#
#  Trace
#
################################################################################

doc"""
***
    trace(a::NfOrdElem) -> fmpz

> Returns the trace of $a$.
"""
function trace(a::NfOrdElem)
  return FlintZZ(trace(elem_in_nf(a)))
end

################################################################################
#
#  Norm
#
################################################################################

doc"""
***
    norm(a::NfOrdElem) -> fmpz

> Returns the norm of $a$.
"""
function norm(a::NfOrdElem)
  return FlintZZ(norm(elem_in_nf(a)))
end

################################################################################
#
#  Random element generation
#
################################################################################

function rand!{T <: Integer}(z::NfOrdElem, O::NfOrdCls, R::UnitRange{T})
  y = O()
  ar = rand(R, degree(O))
  B = basis(O)
  mul!(z, ar[1], B[1])
  for i in 2:degree(O)
    mul!(y, ar[i], B[i])
    add!(z, z, y)
  end
  return z
end

doc"""
***
    rand{T <: Union{Integer, fmpz}}(O::NfOrdCls, R::UnitRange{T}) -> NfOrdElem

> Computes a coefficient vector with entries uniformly distributed in `R` and returns
> the corresponding element of the order.
"""
function rand{T <: Union{Integer, fmpz}}(O::NfOrdCls, R::UnitRange{T})
  z = O()
  rand!(z, O, R)
  return z
end

function rand!(z::NfOrdElem, O::NfOrdCls, n::Union{Integer, fmpz})
  return rand!(z, O, -n:n)
end

doc"""
***
    rand(O::NfOrdCls, n::Union{Integer, fmpz}) -> NfOrdElem

> Computes a coefficient vector with entries uniformly distributed in
> $\{-n,\dotsc,-1,0,1,\dotsc,n\}$ and returns the corresponding element of the
> order $\mathcal O$.
"""
function rand(O::NfOrdCls, n::Integer)
  return rand(O, -n:n)
end

function rand(O::NfOrdCls, n::fmpz)
  z = O()
  rand!(z, O, BigInt(n))
  return z
end

function rand!(z::NfOrdElem, O::NfOrdCls, n::fmpz)
  return rand!(z, O, BigInt(n))
end

################################################################################
#
#  Unsafe operations
#
################################################################################

function add!(z::NfOrdElem, x::NfOrdElem, y::NfOrdElem)
  z.elem_in_nf = x.elem_in_nf + y.elem_in_nf
  if x.has_coord && y.has_coord
    for i in 1:degree(parent(x))
      z.elem_in_basis[i] = x.elem_in_basis[i] + y.elem_in_basis[i]
    end
    z.has_coord = true
  else
    z.has_coord = false
  end
  nothing
end

function mul!(z::NfOrdElem, x::NfOrdElem, y::NfOrdElem)
  z.elem_in_nf = x.elem_in_nf * y.elem_in_nf
  z.has_coord = false
  nothing
end

function mul!(z::NfOrdElem, x::fmpz, y::NfOrdElem)
  z.elem_in_nf = x * y.elem_in_nf
  if y.has_coord
    for i in 1:degree(parent(z))
      z.elem_in_basis[i] = x*y.elem_in_basis[i]
    end
    z.has_coord = true
  else
    z.has_coord = false
  end
  nothing
end

mul!(z::NfOrdElem, x::Integer, y::NfOrdElem) =  mul!(z, ZZ(x), y)

mul!(z::NfOrdElem, x::NfOrdElem, y::Integer) = mul!(z, y, x)

function add!(z::NfOrdElem, x::fmpz, y::NfOrdElem)
  z.elem_in_nf = y.elem_in_nf + x
  nothing
end

add!(z::NfOrdElem, x::NfOrdElem, y::fmpz) = add!(z, y, x)

function add!(z::NfOrdElem, x::Integer, y::NfOrdElem)
  z.elem_in_nf = x + y.elem_in_nf
  nothing
end

add!(z::NfOrdElem, x::NfOrdElem, y::Integer) = add!(z, y, x)

mul!(z::NfOrdElem, x::NfOrdElem, y::fmpz) = mul!(z, y, x)

################################################################################
#
#  Base cases for dot product of vectors
#
################################################################################

dot(x::fmpz, y::nf_elem) = x*y

dot(x::nf_elem, y::fmpz) = x*y

dot(x::NfOrdElem, y::Int64) = y*x

################################################################################
#
#  Conversion
#
################################################################################

Base.call(K::AnticNumberField, x::NfOrdElem) = elem_in_nf(x)

################################################################################
#
#  Minkowski embedding
#
################################################################################

doc"""
***
    minkowski_map(a::NfOrdElem, abs_tol::Int) -> Array{arb, 1}

> Returns the image of $a$ under the Minkowski embedding.
> Every entry of the array returned is of type `arb` with radius less then
> `2^abs_tol`.
"""
function minkowski_map(a::NfOrdElem, abs_tol::Int)
  # Use a.elem_in_nf instead of elem_in_nf(a) to avoid copying the data.
  # The function minkowski_map does not alter the input!
  return minkowski_map(a.elem_in_nf, abs_tol)
end

################################################################################
#
#  Conjugates
#
################################################################################

doc"""
***
    conjugates_arb(x::NfOrdElem, abs_tol::Int) -> Tuple{Array{arb, 1}, Array{acb, 1}}

> Compute the the conjugates of `x` as elements of type `arb` and `acb`
> respectively. Recall that we order the complex conjugates
> $\sigma_{r+1}(x),...,\sigma_{r+2s}(x)$ such that
> $\sigma_{i}(x) = \overline{\sigma_{i + s}(x)}$ for $r + 1 \leq i \leq r + s$.
>
> Every entry `y` of the arrays returned satisfies `radius(y) < 2^abs_tol` or
> `radius(real(y)) < 2^abs_tol`, `radius(imag(y)) < 2^abs_tol` respectively.
"""
function conjugates_arb(x::NfOrdElem, abs_tol::Int)
  # Use a.elem_in_nf instead of elem_in_nf(a) to avoid copying the data.
  # The function minkowski_map does not alter the input!
  return conjugates_arb(x.elem_in_nf, abs_tol)
end

doc"""
***
    conjugates_log(x::NfOrdElem, abs_tol::Int) -> Array{arb, 1}

> Returns the elements
> $(\log(\lvert \sigma_1(x) \rvert),\dotsc,\log(\lvert\sigma_r(x) \rvert),
> \dotsc,2\log(\lvert \sigma_{r+1}(x) \rvert),\dotsc,
> 2\log(\lvert \sigma_{r+s}(x)\rvert))$ as elements of type `arb` radius
> less then `2^abs_tol`.
"""
function conjugates_log(x::NfOrdElem)
  return conjugates_log(x.elem_in_nf)
end

################################################################################
################################################################################
##
##  NfOrdClsIdl : Ideals in NfOrdCls
##
################################################################################
################################################################################

doc"""
***
    ==(x::NfOrdClsIdl, y::NfOrdClsIdl)

> Returns whether $x$ and $y$ are equal.
"""
function ==(x::NfOrdClsIdl, y::NfOrdClsIdl)
  return basis_mat(x) == basis_mat(y)
end

doc"""
***
    +(x::NfOrdClsIdl, y::NfOrdClsIdl)

> Returns $x + y$.
"""
function +(x::NfOrdClsIdl, y::NfOrdClsIdl)
  d = degree(order(x))
  H = vcat(basis_mat(x), basis_mat(y))
  g = gcd(minimum(x),minimum(y))
  H = sub(_hnf_modular_eldiv(H, g, :lowerleft), (d + 1):2*d, 1:d)
  #H = sub(_hnf(vcat(basis_mat(x),basis_mat(y)), :lowerleft), degree(order(x))+1:2*degree(order(x)), 1:degree(order(x)))
  return ideal(order(x), H)
end

doc"""
***
    intersect(x::NfOrdClsIdl, y::NfOrdClsIdl) -> NfOrdClsIdl

> Returns $x \cap y$.
"""
function intersect(x::NfOrdClsIdl, y::NfOrdClsIdl)
  d = degree(order(x))
  H = vcat(basis_mat(x), basis_mat(y))
  K = _kernel(H)
  g = lcm(minimum(x),minimum(y))
  return ideal(order(x), _hnf_modular_eldiv(sub(K, 1:d, 1:d)*basis_mat(x), g, :lowerleft))
  #H = sub(_hnf(vcat(basis_mat(x),basis_mat(y)), :lowerleft), degree(order(x))+1:2*degree(order(x)), 1:degree(order(x)))
end

lcm(x::NfOrdClsIdl, y::NfOrdClsIdl) = intersection(x, y)

doc"""
***
    *(x::NfOrdClsIdl, y::NfOrdClsIdl)

> Returns $x \cdot y$.
"""
function *(x::NfOrdClsIdl, y::NfOrdClsIdl)
  return _mul(x, y)
end

function _mul(x::NfOrdClsIdl, y::NfOrdClsIdl)
  O = order(x)
  d = degree(O)
  l = minimum(x)*minimum(y)
  z = MatrixSpace(FlintZZ, degree(O)*degree(O), degree(O))()
  X = basis(x)
  Y = basis(y)
  for i in 1:d
    for j in 1:d
      t = elem_in_basis(X[i]*Y[j])
      for k in 1:d
        z[i*j, k] = t[k]
      end
    end
  end
  # This is a d^2 x d matrix
  return ideal(O, sub(_hnf_modular_eldiv(z, l, :lowerleft),
                      (d*(d - 1) + 1):d^2, 1:d))
end

################################################################################
#
#  Idempotents
#
################################################################################

function idempotents(x::NfOrdClsIdl, y::NfOrdClsIdl)
  O = order(x)
  d = degree(O)

  # form the matrix
  #
  # ( 1 |  1  | 0 )
  # ( 0 | M_x | I )
  # ( 0 | M_y | 0 )

  V = MatrixSpace(FlintZZ, 1 + 2*d, 1 + 2*d)()

  u = elem_in_basis(one(O))

  V[1, 1] = 1

  for i in 1:d
    V[1, i + 1] = u[i]
  end

  Hecke._copy_matrix_into_matrix(V, 2, 2, basis_mat(x))
  Hecke._copy_matrix_into_matrix(V, 2 + d, 2, basis_mat(y))

  for i in 1:d
    V[1 + i, d + 1 + i] = 1
  end


  H = hnf(V) # upper right

  @assert all([ H[1, i] == 0 for i in 2:(1 + d)])

  z = basis(x)[1]*H[1, d + 2]

  for i in 2:d
    z = z + basis(x)[i]*H[1, d + 1 + i]
  end

  return -z, 1 + z
end

################################################################################
#
#  Inclusion of order elements in ideals
#
################################################################################

doc"""
***
    in(x::NfOrdElem, y::NfOrdClsIdl)

> Returns whether $x$ is contained in $y$.
"""
function in(x::NfOrdElem, y::NfOrdClsIdl)
  v = transpose(MatrixSpace(FlintZZ, degree(parent(x)), 1)(elem_in_basis(x)))
  t = FakeFmpqMat(v, fmpz(1))*basis_mat_inv(y)
  return t.den == 1
end

################################################################################
#
#  Reduction of element modulo ideal
#
################################################################################

doc"""
***
    mod(x::NfOrdElem, I::NfOrdClsIdl)

> Returns the unique element $y$ of the ambient order of $x$ with
> $x \equiv y \bmod I$ and the following property: If
> $a_1,\dotsc,a_d \in \Z_{\geq 1}$ are the diagonal entries of the unique HNF
> basis matrix of $I$ and $(b_1,\dotsc,b_d)$ is the coefficient vector of $y$,
> then $0 \leq b_i < a_i$ for $1 \leq i \leq d$.
"""
function mod(x::NfOrdElem, y::NfOrdClsIdl)
  # this function assumes that HNF is lower left
  # !!! This must be changed as soon as HNF has a different shape
  
  O = order(y)
  b = elem_in_basis(x)
  a = deepcopy(b)

  if isdefined(y, :princ_gen_special) && y.princ_gen_special[1] != 0
    for i in 1:length(a)
      a[i] = mod(a[i], y.princ_gen_special[1 + y.princ_gen_special[1]])
    end
    return O(a)
  end

  O = order(y)
  b = elem_in_basis(x)
  a = deepcopy(b)
  b = basis_mat(y)
  t = fmpz(0)
  for i in degree(O):-1:1
    t = fdiv(a[i],b[i,i])
    for j in 1:i
      a[j] = a[j] - t*b[i,j]
    end
  end
  return O(a)
end

################################################################################
#
#  Compute the p-radical
#
################################################################################

doc"""
***
    pradical(O::NfOrdCls, p::fmpz) -> NfOrdClsIdl

> Given a prime number $p$, this function returns the $p$-radical
> $\sqrt{p\mathcal O}$ of $\mathcal O$, which is 
> just $\{ x \in \mathcal O \mid \exists k \in \mathbf Z_{\geq 0} \colon x^k
> \in p\mathcal O \}$. It is not checked that $p$ is prime.
"""
function pradical(O::NfOrdCls, p::fmpz)
  j = clog(fmpz(degree(O)),p)

  @assert p^(j-1) < degree(O)
  @assert degree(O) <= p^j

  R = ResidueRing(ZZ,p)
  A = MatrixSpace(R, degree(O), degree(O))()
  for i in 1:degree(O)
    t = powermod(basis(O)[i], p^j, p)
    ar = elem_in_basis(t)
    for k in 1:degree(O)
      A[i,k] = ar[k]
    end
  end
  X = kernel(A)
  Mat = MatrixSpace(ZZ, 1, degree(O))
  MMat = MatrixSpace(R, 1, degree(O))
  if length(X) != 0
    m = lift(MMat(X[1]))
    for x in 2:length(X)
      m = vcat(m,lift(MMat(X[x])))
    end
    m = vcat(m,MatrixSpace(ZZ, degree(O), degree(O))(p))
  else
    m = MatrixSpace(ZZ, degree(O), degree(O))(p)
  end
  r = sub(_hnf(m, :lowerleft), rows(m) - degree(O) + 1:rows(m), 1:degree(O))
  return ideal(O, r)
end

doc"""
***
    pradical(O::NfOrdCls, p::Integer) -> NfOrdClsIdl

> Given a prime number $p$, this function returns the $p$-radical
> $\sqrt{p\mathcal O}$ of $\mathcal O$, which is 
> just $\{ x \in \mathcal O \mid \exists k \in \mathbf Z_{\geq 0} \colon x^k
> \in p\mathcal O \}$. It is not checked that $p$ is prime.
"""
function pradical(O::NfOrdCls, p::Integer)
  return pradical(O, fmpz(p))
end

################################################################################
#
#  Promotion
#
################################################################################

Base.promote_rule{T <: Integer}(::Type{NfOrdElem}, ::Type{T}) = NfOrdElem

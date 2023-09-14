using Test
using StatsBase
using SoleLogics
using SoleModels
using Graphs
using Random
using ThreadSafeDicts

features = SoleModels.Feature.(string.('p':'z'))
worlds = SoleLogics.World.(1:10)
fr = SoleLogics.ExplicitCrispUniModalFrame(worlds, SimpleDiGraph(length(worlds), 4))

i_instance = 1

# Boolean
rng = Random.MersenneTwister(1)
bool_logiset = SoleModels.ExplicitBooleanLogiset([(Dict([w => sample(rng, features, 2, replace = false) for w in worlds]), fr)])
bool_condition = SoleModels.ValueCondition(features[1])

@test [SoleModels.checkcondition(bool_condition, bool_logiset, i_instance, w)
    for w in worlds] == Bool[0, 1, 1, 1, 0, 0, 0, 0, 0, 0]

# Scalar (Float)
rng = Random.MersenneTwister(1)
scalar_logiset = SoleModels.ExplicitLogiset([(Dict([w => Dict([f => rand(rng) for f in features]) for w in worlds]), fr)])
scalar_condition = SoleModels.ScalarCondition(features[1], >, 0.5)

@test [SoleModels.checkcondition(scalar_condition, scalar_logiset, i_instance, w)
    for w in worlds] == Bool[0, 0, 1, 1, 0, 1, 0, 1, 0, 0]

# Non-scalar (Vector{Float})
rng = Random.MersenneTwister(2)
nonscalar_logiset = SoleModels.ExplicitLogiset([(Dict([w => Dict([f => rand(rng, rand(rng, 1:3)) for f in features]) for w in worlds]), fr)])

@test SoleModels.featvalue(nonscalar_logiset, 1, worlds[1], features[1]) == SoleModels.featvalue(features[1], nonscalar_logiset, 1, worlds[1])

nonscalar_condition = SoleModels.FunctionalCondition(features[1], (vals)->length(vals) >= 2)

@test [SoleModels.checkcondition(nonscalar_condition, nonscalar_logiset, i_instance, w)
    for w in worlds] == Bool[0, 1, 0, 0, 1, 1, 1, 0, 1, 1]


multilogiset = MultiLogiset([bool_logiset, scalar_logiset, nonscalar_logiset])

@test SoleModels.modalitytype(multilogiset) <:
SoleModels.AbstractLogiset{SoleLogics.World{Int64}, U, SoleModels.Feature{String}, SoleLogics.ExplicitCrispUniModalFrame{SoleLogics.World{Int64}, SimpleDiGraph{Int64}}} where U

SoleModels.AbstractLogiset{SoleLogics.World{Int64}, U, Feature{String}, SoleLogics.ExplicitCrispUniModalFrame{SoleLogics.World{Int64}, SimpleDiGraph{Int64}}} where U <: SoleModels.AbstractLogiset{SoleLogics.World{Int64}, U, Feature{String}, SoleLogics.ExplicitCrispUniModalFrame{SoleLogics.World{Int64}, SimpleDiGraph{Int64}}} where U


@test_nowarn displaystructure(bool_logiset)
@test_nowarn displaystructure(scalar_logiset)
@test_nowarn displaystructure(multilogiset)


############################################################################################

for w in worlds
    @test accessibles(fr, w) == accessibles(scalar_logiset, 1, w)
    @test representatives(fr, w, scalar_condition) == representatives(scalar_logiset, 1, w, scalar_condition)
end

cond1 = SoleModels.ScalarCondition(features[1], >, 0.9)
cond2 = SoleModels.ScalarCondition(features[2], >, 0.3)

for w in worlds
    @test (featvalue(scalar_logiset, 1, w, features[1]) > 0.9) == check(Atom(cond1) ∧ ⊤, scalar_logiset, 1, w)
    @test (featvalue(scalar_logiset, 1, w, features[2]) > 0.3) == check(Atom(cond2) ∧ ⊤, scalar_logiset, 1, w)
end

# Propositional formula
φ = ⊤ → Atom(cond1) ∧ Atom(cond2)
for w in worlds
    @test ((featvalue(scalar_logiset, 1, w, features[1]) > 0.9) && (featvalue(scalar_logiset, 1, w, features[2]) > 0.3)) == check(φ, scalar_logiset, 1, w)
end

# Modal formula
φ = ◊(⊤ → Atom(cond1) ∧ Atom(cond2))
for w in worlds
    @test check(φ, scalar_logiset, 1, w) == (length(accessibles(fr, w)) > 0 && any([
        ((featvalue(scalar_logiset, 1, v, features[1]) > 0.9) && (featvalue(scalar_logiset, 1, v, features[2]) > 0.3))
    for v in accessibles(fr, w)]))
end

# Modal formula on multilogiset
for w in worlds
    @test check(φ, multilogiset, 2, 1, w) == (length(accessibles(fr, w)) > 0 && any([
        ((featvalue(multilogiset, 2, 1, v, features[1]) > 0.9) && (featvalue(multilogiset, 2, 1, v, features[2]) > 0.3))
    for v in accessibles(fr, w)]))
end

############################################################################################

# Check with memoset

w = worlds[1]
W = worldtype(bool_logiset)
bool_supported_logiset = @test_nowarn SupportedLogiset(bool_logiset)
scalar_supported_logiset = @test_nowarn SupportedLogiset(scalar_logiset)
nonscalar_supported_logiset = @test_nowarn SupportedLogiset(nonscalar_logiset)

@test SoleModels.featvalue(nonscalar_logiset, 1, worlds[1], features[1]) == SoleModels.featvalue(nonscalar_supported_logiset, 1, worlds[1], features[1])

@test_nowarn displaystructure(bool_supported_logiset)
@test_nowarn displaystructure(scalar_supported_logiset)
@test_nowarn displaystructure(nonscalar_supported_logiset)

@test_nowarn slicedataset(bool_logiset, [1])
@test_nowarn slicedataset(bool_logiset, [1]; return_view = true)
@test_nowarn slicedataset(bool_supported_logiset, [1])

@test_nowarn SoleModels.allfeatvalues(bool_logiset)
@test_nowarn SoleModels.allfeatvalues(bool_logiset, 1)
@test_nowarn SoleModels.allfeatvalues(bool_logiset, 1, features[1])
@test_nowarn SoleModels.allfeatvalues(bool_supported_logiset)
@test_nowarn SoleModels.allfeatvalues(bool_supported_logiset, 1)
@test_nowarn SoleModels.allfeatvalues(bool_supported_logiset, 1, features[1])

@test SoleLogics.allworlds(bool_logiset, 1) == SoleLogics.allworlds(bool_supported_logiset, 1)
@test SoleLogics.nworlds(bool_logiset, 1) == SoleLogics.nworlds(bool_supported_logiset, 1)
@test SoleLogics.frame(bool_logiset, 1) == SoleLogics.frame(bool_supported_logiset, 1)


@test_throws AssertionError SoleModels.parsecondition(SoleModels.ScalarCondition, "p > 0.5")
@test_nowarn SoleModels.parsecondition(SoleModels.ScalarCondition, "p > 0.5"; featvaltype = String, featuretype = Feature)
@test SoleModels.ScalarCondition(features[1], >, 0.5) == SoleModels.parsecondition(SoleModels.ScalarCondition, "p > 0.5"; featvaltype = String, featuretype = Feature)

############################################################################################
# Memoset's
############################################################################################

memoset = [ThreadSafeDict{SyntaxTree,WorldSet{W}}() for i_instance in 1:ninstances(bool_supported_logiset)]

@test_nowarn check(φ, bool_logiset, 1, w)
@test_nowarn check(φ, bool_logiset, 1, w; use_memo = nothing)
@test_nowarn check(φ, bool_logiset, 1, w; use_memo = memoset)
@test_nowarn check(φ, bool_supported_logiset, 1, w)
@test_nowarn check(φ, bool_supported_logiset, 1, w; use_memo = nothing)
@test_logs (:warn,) check(φ, bool_supported_logiset, 1, w; use_memo = memoset)


bool_supported_logiset2 = @test_nowarn SupportedLogiset(bool_logiset, memoset)
bool_supported_logiset2 = @test_nowarn SupportedLogiset(bool_logiset, (memoset,))
bool_supported_logiset2 = @test_nowarn SupportedLogiset(bool_logiset, [memoset])

@test_throws AssertionError SupportedLogiset(bool_supported_logiset2)

@test_nowarn SupportedLogiset(bool_logiset, bool_supported_logiset2)

@test_nowarn SupportedLogiset(bool_logiset, (bool_supported_logiset2,))
@test_nowarn SupportedLogiset(bool_logiset, [bool_supported_logiset2])


rng = Random.MersenneTwister(1)
alph = ExplicitAlphabet([SoleModels.ScalarCondition(rand(rng, features), rand(rng, [>, <]), rand(rng)) for i in 1:10])
syntaxstring.(alph)
_formulas = [randformula(rng, 4, alph, [NEGATION, CONJUNCTION, IMPLICATION, DIAMOND, BOX]) for i in 1:10]
@test_nowarn syntaxstring.(_formulas)
@test_nowarn syntaxstring.(_formulas; threshold_digits = 2)

c1 = @test_nowarn [check(φ, bool_logiset, 1, w) for φ in _formulas]
c2 = @test_nowarn [check(φ, bool_logiset, 1, w; use_memo = nothing) for φ in _formulas]
c3 = @test_nowarn [check(φ, bool_logiset, 1, w; use_memo = memoset) for φ in _formulas]
c4 = @test_nowarn [check(φ, SupportedLogiset(bool_logiset), 1, w) for φ in _formulas]
c5 = @test_nowarn [check(φ, SupportedLogiset(bool_logiset), 1, w; use_memo = nothing) for φ in _formulas]
# c6 = @test_logs (:warn,) [check(φ, bool_supported_logiset, 1, w; use_memo = memoset) for φ in _formulas]

@test c1 == c2 == c3 == c4 == c5

w = worlds[1]
W = worldtype(scalar_logiset)
memoset = [ThreadSafeDict{SyntaxTree,WorldSet{W}}() for i_instance in 1:ninstances(scalar_logiset)]
@test_throws AssertionError check(φ, scalar_logiset, 1; use_memo = nothing)
@time check(φ, scalar_logiset, 1, w; use_memo = nothing)
@time check(φ, scalar_logiset, 1, w; use_memo = memoset)

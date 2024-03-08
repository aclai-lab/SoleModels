using SoleData
using SoleLogics
using SoleModels
import SoleData: feature, varname

const SPACE = " "
const UNDERCORE = "_"

# This file contains utility functions for porting symbolic models from string and custom representations.

# function feature(
#     φ::LeftmostConjunctiveForm{Atom{ScalarCondition}}
# )::AbstractVector{UnivariateSymbolValue}
#     conditions = value.(atoms(φ))
#     return SoleData.feature.(conditions)
# end
#=
C’è! Per ora è il campo info::NamedTuple, che ciascun modello simbolico ha.
Nel fare la traduzione a modelli di sole,

- nella info di una Rule metti supporting_labels che è un vettore delle labels delle istanze su
cui la regola è costruita (ovvero, quelle che non sono coperte dalle regole precedenti),

- nella info del ConstantModel ci metti un campo supporting_labels con le labels delle istanze che,
tra queste, sono coperte dalla regola.

Valuteremo se bisogna aggiungere anche un campo predicted_labels con le labels predette
dal modello, ma in principio le supporting_labels sono sufficienti per calcolare diverse metriche
=#


# function getdistributions(
#     decision_list_str::AbstractString
# )
#     distributions_list = []

#     for orangerule_str in eachline(IOBuffer(decision_list_str))
#         res = match(r"\[([\d\s,]+)\]", orangerule_str)
#         distribution_str = res.captures[1]
#         push!(distributions_list, parse.(Int, split(distribution_str, ',')))
#     end
#     return distributions_list
# end

"""
Parser for [orange](https://orange3.readthedocs.io/)-style decision lists.
    Reference: https://orange3.readthedocs.io/projects/orange-visual-programming/en/latest/widgets/model/cn2ruleinduction.html
    # Examples
```julia-repl
julia> "
[49, 0, 0] IF petal length<=3.0 AND sepal width>=2.9 THEN iris=Iris-setosa  -0.0
[0, 0, 39] IF petal width>=1.8 AND sepal length>=6.0 THEN iris=Iris-virginica  -0.0
[0, 8, 0] IF sepal length>=4.9 AND sepal width>=3.1 THEN iris=Iris-versicolor  -0.0
[0, 0, 2] IF petal length<=4.9 AND petal width>=1.7 THEN iris=Iris-virginica  -0.0
[0, 0, 5] IF petal width>=1.8 THEN iris=Iris-virginica  -0.0
[0, 35, 0] IF petal length<=5.0 AND sepal width>=2.4 THEN iris=Iris-versicolor  -0.0
[0, 0, 2] IF sepal width>=2.8 THEN iris=Iris-virginica  -0.0
[0, 3, 0] IF petal width<=1.0 AND sepal length>=5.0 THEN iris=Iris-versicolor  -0.0
[0, 1, 0] IF sepal width>=2.7 THEN iris=Iris-versicolor  -0.0
[0, 0, 1] IF sepal width>=2.6 THEN iris=Iris-virginica  -0.0
[0, 2, 0] IF sepal length>=5.5 AND sepal length>=6.2 THEN iris=Iris-versicolor  -0.0
[0, 1, 0] IF sepal length<=5.5 AND petal length>=4.0 THEN iris=Iris-versicolor  -0.0
[0, 0, 1] IF sepal length>=6.0 THEN iris=Iris-virginica  -0.0
[1, 0, 0] IF sepal length<=4.5 THEN iris=Iris-setosa  -0.0
[50, 50, 50] IF TRUE THEN iris=Iris-setosa  -1.584962500721156
" |> parse_orange_decision_list
▣
├[1/14]┐(:petal_length ≤ 3.0) ∧ (:sepal_width ≥ 2.9)
│└ Iris-setosa
├[2/14]┐(:petal_width ≥ 1.8) ∧ (:sepal_length ≥ 6.0)
│└ Iris-virginica
├[3/14]┐(:sepal_length ≥ 4.9) ∧ (:sepal_width ≥ 3.1)
│└ Iris-versicolor
├[4/14]┐(:petal_length ≤ 4.9) ∧ (:petal_width ≥ 1.7)
│└ Iris-virginica
├[5/14]┐(:petal_width ≥ 1.8)
│└ Iris-virginica
├[6/14]┐(:petal_length ≤ 5.0) ∧ (:sepal_width ≥ 2.4)
│└ Iris-versicolor
├[7/14]┐(:sepal_width ≥ 2.8)
│└ Iris-virginica
├[8/14]┐(:petal_width ≤ 1.0) ∧ (:sepal_length ≥ 5.0)
│└ Iris-versicolor
├[9/14]┐(:sepal_width ≥ 2.7)
│└ Iris-versicolor
├[10/14]┐(:sepal_width ≥ 2.6)
│└ Iris-virginica
├[11/14]┐(:sepal_length ≥ 5.5) ∧ (:sepal_length ≥ 6.2)
│└ Iris-versicolor
├[12/14]┐(:sepal_length ≤ 5.5) ∧ (:petal_length ≥ 4.0)
│└ Iris-versicolor
├[13/14]┐(:sepal_length ≥ 6.0)
│└ Iris-virginica
├[14/14]┐(:sepal_length ≤ 4.5)
│└ Iris-setosa
└✘ Iris-setosa
```

See also
[`DecisionList`](@ref).
"""
function parse_orange_decision_list(
    decision_list_str::AbstractString;
    featuretype = SoleData.UnivariateSymbolValue
)
    # Strip whitespaces
    decision_list_str = strip(decision_list_str)

    # Get last line of the decision_list_str string (the line with the total distribution [50, 50, 50])
    lastline = foldl((x,y)->y, eachline(IOBuffer(decision_list_str)))
    res = match(r"\[([\d\s,]+)\]", lastline)
    uncovered_distribution_str = res.captures[1]
    uncovered_distribution = parse.(Int, split(uncovered_distribution_str, ','))

    rulebase = SoleModels.Rule[]
    default_consequent = nothing

    for orangerule_str in eachline(IOBuffer(decision_list_str))

        res = match(r"\s*\[([\d\s,]+)\]\s*IF\s*(.*)\s*THEN\s*(.*)=(.*)\s+([+-]?\d+\.\d*)", orangerule_str)
        if isnothing(res) || length(res.captures) != 5
            error("Malformed decision list line: $(orangerule_str)")
        end

        distribution_str, antecedents_str, consequent_class_name_str, consequent_str, evaluation_str = String.(strip.(res.captures))

        if antecedents_str == "TRUE"
            info = (;
                orange_evaluation = parse(Float64, evaluation_str),
            )
            default_consequent = SoleModels.ConstantModel(consequent_str, info)
            break
        end

        currentrule_distribution = parse.(Int, split(distribution_str, ','))
        antecedent_conditions = String.(strip.(split(antecedents_str, "AND")))
        antecedent_conditions = replace.(antecedent_conditions, SPACE => UNDERCORE)
        antecedent_conditions = match.(r"(.+?)([<>]=?|==)(.*)", antecedent_conditions)

        antecedent = LeftmostConjunctiveForm([begin
            varname, test_operator, treshold = condition.captures[:]

            varname = strip(varname)
            test_operator = strip(test_operator)
            threshold = tryparse(Float64, strip(treshold))

            if isnothing(threshold)
                threshold = treshold_str
            end
            Atom{ScalarCondition}(SoleData.ScalarCondition(
                    featuretype(Symbol(varname)),
                    eval(Meta.parse(test_operator)),
                    threshold
            ))
        end for condition in antecedent_conditions])


        # Info ConstantModel
        info_cm = (;
            orange_evaluation = parse(Float64, evaluation_str),
            supporting_labels = currentrule_distribution
        )
        consequent_cm = SoleModels.ConstantModel(consequent_str, info_cm)

        # Info Rule
        info_r = (;
            supp_lables = uncovered_distribution
        )
        push!(rulebase, Rule(antecedent, consequent_cm, info_r))
        uncovered_distribution = uncovered_distribution.-currentrule_distribution
    end
    if isnothing(default_consequent)
        error("Malformed decision list: default rule was not found.")
    end

    return SoleModels.DecisionList(rulebase, default_consequent)
end

    # Gio:
    #   - The last (floating-point) number (see https://www.oreilly.com/library/view/regular-expressions-cookbook/9781449327453/ch06s10.html )
    #                                      (by the way, what is it..? The entropy gain...? yes)
    #   antecedent = parse(Formula, antecedent_string)
    #   consequent = prendi la parte dopo il segno di uguaglianza da consequent_str, e
    #   wrappalo in un ConstantModel mettendogli un campo `supporting_labels` nelle `info`

    #   avoid producing a rule for the last row, but remember its consequent.
    #   Maybe: And disregard the class distribution of the last rule (it's imprecise...)
    #   Actually it can be computed if one provides the original class distribution as a kwarg parameter

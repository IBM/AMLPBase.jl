### AMLPipelineBase.jl
---------------
| **Documentation** | **Build Status** | **Help** |
|:---:|:---:|:---:|
| [![][docs-dev-img]][docs-dev-url] [![][docs-stable-img]][docs-stable-url] | [![][travis-img]][travis-url] [![][codecov-img]][codecov-url] | [![][slack-img]][slack-url] [![][gitter-img]][gitter-url] |

[AMLPipelineBase.jl](https://github.com/IBM/AMLPipelineBase.jl) 
is the **Base** package of [TSML.jl](https://github.com/IBM/TSML.jl) 
and [AutoMLPipeline.jl](https://github.com/IBM/AutoMLPipeline.jl).
**AMLPipelineBase** is written in pure **Julia**. It exposes the abstract 
types commonly shared by **TSML** and **AutoMLPipeline**.
It also contains basic data preprocessing routines and 
learners for rapid prototyping. **TSML** extends **AMLPipelineBase** capability
by specializing in Time-Series workflow while **AutoMLPipeline**
focuses in ML pipeline optimization. Since
**AMLPipelineBase** is written in pure **Julia** including its
dependencies, the future target will 
be to exploit Julia's native multi-threading 
using thread-safe ML **Julia** libraries for scalability and performance.

**AMLPipelineBase** declares the following abstract data types:
```julia
abstract type Machine end
abstract type Computer    <: Machine  end
abstract type Workflow    <: Machine  end
abstract type Learner     <: Computer end
abstract type Transformer <: Computer end
```

**AMLPipelineBase** dynamically dispatches the **fit!** and **transform!**
functions which must be overloaded by different subtypes of **Machine**.
```julia
function fit!(mc::Machine, input::DataFrame, output::Vector)
   error(typeof(mc),"not implemented")
end

function transform!(mc::Machine, input::DataFrame)
   error(typeof(mc),"not implemented")
end
```

### Motivations
- To provide a **Base** package for common functions and abstractions shared by:
  - [AutoMLPipeline](https://github.com/IBM/AutoMLPipeline.jl): A package for ML Pipeline Optimization
  - [TSML](https://github.com/IBM/TSML.jl): A package for Time-Series ML
- To implement efficient multi-threading reduction workflow

### Package Features
- Symbolic pipeline API for high-level description and 
  easy expression of complex pipeline structures and workflows
- Easily extensible architecture by overloading 
  just two main interfaces: **fit!** and **transform!**
- Meta-ensembles that allow composition of
    ensembles of ensembles (recursively if needed)
    for robust prediction routines
- Categorical and numerical feature selectors for
    specialized preprocessing routines based on types
- Normalizers (zscore, unitrange, pca, fa) and Ensemble learners (voting, stacks, best)

### Extending AMLPipelineBase
If you want to add your own filter/transformer/learner, it is trivial. 
Just take note that filters and transformers process the first 
input features and ignores the target output while learners process both 
the input features and target output arguments of the **fit!** function. 
The **transform!** function always expect one input argument in all cases. 

First, import the abstract types and define your own mutable structure 
as subtype of either Learner or Transformer. Also import the **fit!** and
**transform!** functions to be overloaded. Also load the DataFrames package
to be used for data interchange.

```
using DataFrames
using AMLPipelineBase: AbsTypes, Utils

# import fit! and transform! for function overloading 
import AMLPipelineBase.AbsTypes: fit!, transform!  

export fit!, transform!, MyFilter

# define your filter structure
mutable struct MyFilter <: Transformer
  name::String
  model::Dict
  args::Dict
  function MyFilter(args::Dict())
      ....
  end
end

# filters and transformers ignore the target argument. 
# learners process both the input features and target argument.
function fit!(fl::MyFilter, inputfeatures::DataFrame, target::Vector=Vector())
     ....
end

# transform! function expects an input dataframe and outputs a dataframe
function transform!(fl::MyFilter, inputfeatures::DataFrame)::DataFrame
     ....
end
```
Note that the main data interchange format is a dataframe so transform! 
output should always be a dataframe as well as the input for **fit!** and **transform!**.
This is necessary so that the pipeline passes the dataframe format consistently to
its filters or transformers or learners. Once you created a filter, you can use 
it as part of the pipeline together with the other learners and filters.

### Installation

AMLPipelineBase is in the Julia Official package registry.
The latest release can be installed at the Julia
prompt using Julia's package management which is triggered
by pressing `]` at the julia prompt:
```julia
julia> ]
pkg> update
pkg> add AMLPipelineBase
```

Below outlines some typical way to preprocess and model any dataset.

##### 1. Load Data, Extract Input (X) and Target (Y) 
```julia
# Make sure that the input feature is a dataframe and the target output is a 1-D vector.
using AMLPipelineBase
profbdata = getprofb()
X = profbdata[:,2:end] 
Y = profbdata[:,1] |> Vector;
head(x)=first(x,5)
head(profbdata)
```

#### 2. Load Filters, Transformers, and Learners 
```julia
#### Decomposition
pca = Normalizer(:pca)
fa  = Normalizer(:fa)

#### Scaler 
zscore = Normalizer(:zscore)
unitr  = Normalizer(:unitrange);

#### categorical preprocessing
ohe = OneHotEncoder()

#### Column selector
catf = CatFeatureSelector() 
numf = NumFeatureSelector()

#### Learners
rf    = RandomForest()
ada   = Adaboost()
pt    = PrunedTree()
stack = StackEnsemble()
best  = BestLearner()
vote  = VoteEnsemble()
```

#### 3. Filter categories and hot-encode them
```julia
pohe = @pipeline catf |> ohe
tr = fit_transform!(pohe,X,Y)
```

#### 4. Numerical Feature Extraction Example 

##### 4.1 Filter numeric features, scale with zscore, extract fa and pca features, and combine both features
```julia
pdec = @pipeline numf |> zscore |> (fa + pca)
tr = fit_transform!(pdec,X,Y)
```

##### 4.2 Filter numeric features, transform to robust and power transform scaling, perform ica and pca, respectively, and combine both
```julia
ppt = @pipeline numf |> (( zscore |> fa) + (unitr |> pca))
tr = fit_transform!(ppt,X,Y)
```

#### 5. A Pipeline for the Voting Ensemble Classification
```julia
# take all categorical columns and hot-bit encode each, 
# concatenate them to the numerical features,
# and feed them to the voting ensemble
pvote = @pipeline  (catf |> ohe) + (numf) |> vote
pred = fit_transform!(pvote,X,Y)
sc=score(:accuracy,pred,Y)
println(sc)
### cross-validate
acc(X,Y) = score(:accuracy,X,Y)
crossvalidate(pvote,X,Y,acc,10,true)
```

#### 6. Use `@pipelinex` instead of `@pipeline` to print the corresponding function calls in 6
```julia
julia> @pipelinex (catf |> ohe) + (numf) |> vote
:(Pipeline(ComboPipeline(Pipeline(catf, ohe), numf), vote))

# another way is to use @macroexpand with @pipeline
julia> @macroexpand @pipeline (catf |> ohe) + (numf) |> vote
:(Pipeline(ComboPipeline(Pipeline(catf, ohe), numf), vote))
```

#### 7. A Pipeline for the Random Forest (RF) Classification
```julia
# compute the pca, ica, fa of the numerical columns,
# combine them with the hot-bit encoded categorical features
# and feed all to the random forest classifier
prf = @pipeline (catf|> ohe) + (numf |> ((zscore |> fa) + (unitr |> pca) + (zscore |> pca)))  |> rf
pred = fit_transform!(prf,X,Y)
score(:accuracy,pred,Y) |> println
crossvalidate(prf,X,Y,acc,10)
```

#### 9. A Pipeline for Random Forest Regression
```julia
using Statistics
iris = getiris()
Xreg = iris[:,1:3]
Yreg = iris[:,4] |> Vector
rfreg = @pipeline (catf |> ohe) + (numf) |> rf
pred=fit_transform!(rfreg,Xreg,Yreg)
rmse(X,Y) = mean((X .- Y).^2) |> sqrt
res=crossvalidate(rfreg,Xreg,Yreg,rmse,10,true)
```

Note: More examples can be found in the **TSML** and **AutoMLPipeline** packages. 
Since the code is written in Julia, you are highly encouraged to read the source
code and feel free to extend or adapt the package to your problem. Please
feel free to submit PRs to improve the package features. 

#### 10. Performance Comparison of Several Learners
##### 10.1 Sequential Processing
```julia
using Random
using DataFrames
Random.seed!(1)

zscore = Normalizer(Dict(:method =>:zscore))
pca    = Normalizer(Dict(:method =>:pca))
disc   = CatNumDiscriminator()
catf   = CatFeatureSelector()
numf   = NumFeatureSelector()
ohe    = OneHotEncoder()
rf     = RandomForest()
ada    = Adaboost()
tree   = PrunedTree()
stack  = StackEnsemble()
best   = BestLearner()
vote   = VoteEnsemble()

learners = DataFrame()
for learner in [rf,ada,tree,stack,vote,best]
    pcmc = @pipeline disc |> ((catf |> ohe) + (numf |> zscore |> pca)) |> learner
    println(learner.name)
    mean,sd,_ = crossvalidate(pcmc,X,Y,acc,10,true)
    learners = vcat(learners,DataFrame(name=learner.name,mean=mean,sd=sd))
end;
@show learners;
```

##### 10.2 Parallel Processing
```julia
using Random
using DataFrames
using Distributed

nprocs() == 1 && addprocs()
@everywhere using DataFrames
@everywhere using AMLPipelineBase

zscore = Normalizer(Dict(:method =>:zscore))
pca    = Normalizer(Dict(:method =>:pca))
rf     = RandomForest()
ada    = Adaboost()
tree   = PrunedTree()
stack  = StackEnsemble()
best   = BestLearner()
vote   = VoteEnsemble()
disc   = CatNumDiscriminator()
catf   = CatFeatureSelector()
numf   = NumFeatureSelector()

@everywhere acc(X,Y) = score(:accuracy,X,Y)

learners = @distributed (vcat) for learner in [rf,ada,tree,stack,vote,best]
    pcmc = @pipeline disc |> ((catf |> ohe) + (numf |> zscore |> pca)) |> learner
    println(learner.name)
    mean,sd,_ = crossvalidate(pcmc,X,Y,acc,10,true)
    DataFrame(name=learner.name,mean=mean,sd=sd)
end
@show learners;
```

#### 11. Automatic Selection of Best Learner
You can use `*` operation as a selector function which outputs the result of the best learner.
If we use the same pre-processing pipeline in 10, we expect that the average performance of
best learner which is `lsvc` will be around 73.0.
```julia
Random.seed!(1)
pcmc = @pipeline disc |> ((catf |> ohe) + (numf |> zscore)) |> (rf * ada * tree)
crossvalidate(pcmc,X,Y,acc,10,true)
```

#### 12. Learners as Transformers
It is also possible to use learners in the middle of expression to serve
as transformers and their outputs become inputs to the final learner as illustrated
below.
```julia
expr = @pipeline ( 
                   ((numf |> zscore)+(catf |> ohe) |> ada) + ((numf |> zscore)+(catf |> ohe) |> rf) 
                 ) |> ohe |> rf;                
crossvalidate(expr,X,Y,acc,10,true)
```
One can even include selector function as part of transformer preprocessing routine:
```julia
pjrf = @pipeline disc |> ((catf |> ohe) + (numf |> zscore)) |> 
                 ((rf * ada ) + (rf * tree * vote)) |> ohe |> ada
crossvalidate(pjrf,X,Y,acc,10,true)
```
Note: The `ohe` is necessary in both examples
because the outputs of the learners and selector function are categorical 
values that need to be hot-bit encoded before feeding to the final `ada` learner.

#### 13. Tree Visualization of the Pipeline Structure
You can visualize the pipeline by using AbstractTrees Julia package. 
```julia
# package installation 
using Pkg
Pkg.update()
Pkg.add("AbstractTrees") 

# load the packages
using AbstractTrees
using AMLPipelineBase

julia> expr = @pipelinex (catf |> ohe) + (numf |> pca) + (numf |> fa) |> rf
:(Pipeline(ComboPipeline(Pipeline(catf, ohe), Pipeline(numf, pca), Pipeline(numf, fa)), rf))

julia> print_tree(stdout, expr)
:(Pipeline(ComboPipeline(Pipeline(catf, ohe), Pipeline(numf, pca), Pipeline(numf, ica)), rf))
├─ :Pipeline
├─ :(ComboPipeline(Pipeline(catf, ohe), Pipeline(numf, pca), Pipeline(numf, ica)))
│  ├─ :ComboPipeline
│  ├─ :(Pipeline(catf, ohe))
│  │  ├─ :Pipeline
│  │  ├─ :catf
│  │  └─ :ohe
│  ├─ :(Pipeline(numf, pca))
│  │  ├─ :Pipeline
│  │  ├─ :numf
│  │  └─ :pca
│  └─ :(Pipeline(numf, ica))
│     ├─ :Pipeline
│     ├─ :numf
│     └─ :ica
└─ :rf
```


### Feature Requests and Contributions

We welcome contributions, feature requests, and suggestions. Here is the link to open an [issue][issues-url] for any problems you encounter. If you want to contribute, please follow the guidelines in [contributors page][contrib-url].

### Help usage

Usage questions can be posted in:
- [Julia Community](https://julialang.org/community/) 
- [Gitter AutoMLPipeline Community][gitter-url]
- [Julia Discourse forum][discourse-tag-url]


[contrib-url]: https://github.com/IBM/AMLPipelineBase.jl/blob/master/CONTRIBUTORS.md
[issues-url]: https://github.com/IBM/AMLPipelineBase.jl/issues

[discourse-tag-url]: https://discourse.julialang.org/

[gitter-url]: https://gitter.im/AutoMLPipelineLearning/community
[gitter-img]: https://badges.gitter.im/ppalmes/TSML.jl.svg

[slack-img]: https://img.shields.io/badge/chat-on%20slack-yellow.svg
[slack-url]: https://julialang.slack.com/


[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://ibm.github.io/AutoMLPipeline.jl/stable/
[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://ibm.github.io/AutoMLPipeline.jl/dev/

[travis-img]: https://travis-ci.com/IBM/AMLPipelineBase.jl.svg?branch=master
[travis-url]: https://travis-ci.com/IBM/AMLPipelineBase.jl

[codecov-img]: https://codecov.io/gh/IBM/AMLPipelineBase.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/IBM/AMLPipelineBase.jl

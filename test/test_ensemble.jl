module TestEnsembleMethods

using Test
using Random
using AMLPipelineBase
using DataFrames: nrow

function generateXY()
    Random.seed!(123)
    iris = getiris()
    indx = Random.shuffle(1:nrow(iris))
    features=iris[indx,1:4] 
    sp = iris[indx,5] |> Vector
    (features,sp)
end

function getprediction(model,features,output)
  res = fit_transform!(model,features,output)
  res1 = fit_transform(model,features,output)
  @test sum(res .== output)/length(output)*100 > 90.0
  @test sum(res1 .== output)/length(output)*100 > 90.0
end

function test_ensembles()
  tstfeatures,tstoutput = generateXY()
  models = [VoteEnsemble(),StackEnsemble(),BestLearner()]
  for model in models
     getprediction(model,tstfeatures,tstoutput) 
  end
end
@testset "Ensemble learners" begin
  Random.seed!(123)
  test_ensembles()
end

function test_vararg()
  rf = RandomForest()
  ada = Adaboost()
  pt = PrunedTree()
  
  X,Y = generateXY()
  vote = VoteEnsemble(rf,ada,pt)
  stack = StackEnsemble(rf,ada,pt)
  best = BestLearner(rf,ada,pt)
  v=fit_transform!(vote,X,Y) 
  s=fit_transform!(stack,X,Y) 
  p=fit_transform!(best,X,Y) 
  @test score(:accuracy,v,Y) > 90.0
  @test score(:accuracy,s,Y) > 90.0
  @test score(:accuracy,p,Y) > 90.0
end # module
@testset "Vararg Ensemble Test" begin
  Random.seed!(123)
  test_vararg()
end

end

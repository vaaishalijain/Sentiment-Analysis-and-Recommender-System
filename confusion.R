#packages
Needed <- c("tm", "SnowballCC", "RColorBrewer", "ggplot2", "wordcloud", "biclust", "cluster", "igraph", "fpc")   
install.packages(Needed, dependencies=TRUE)   
install.packages("Rcampdf", repos = "http://datacube.wu.ac.at/", type = "source")    
install.packages("lettercloud")
install.packages("Rcpp")
install.packages("SnowballC")   
install.packages("maxent")

#libraries
library(tm)
library(SnowballC)   

amazon<-iphone4[1:300, ]
amazonReviews <- amazon$Reviews
lb<-as.matrix(amazon$Actual.Sentiment)

convTweets <- iconv(amazonReviews, to = "utf-8", sub="")
amazonReviews <- (convTweets[!is.na(convTweets)])
amazonReviews<-VCorpus(VectorSource(amazonReviews))
amazonReviews<-tm_map(amazonReviews,removePunctuation)
amazonReviews<-tm_map(amazonReviews,removeNumbers)
amazonReviews<-tm_map(amazonReviews,tolower)
rt_rem <- c(stopwords('english'), "can", "came", "get", "got", "just", "will", "day")
amazonReviews<-tm_map(amazonReviews,removeWords,rt_rem)
amazonReviews <- tm_map(amazonReviews, stemDocument)
amazonReviews <- tm_map(amazonReviews, stripWhitespace)
amazonReviews <- tm_map(amazonReviews, PlainTextDocument)

dtm <- DocumentTermMatrix(amazonReviews, control = list(weighting = function(x) weightTfIdf(x, normalize = FALSE)))
writeLines(as.character(amazonReviews[[4]]))

# sentiment dictionary
pos = scan('positive-words.txt', what='character', comment.char=';')
pos = c(pos, 'upgrade', 'awsum')
neg = scan('negative-words.txt', what='character', comment.char=';')
neg = c(neg, 'no', 'not','cracked',"didn't",'without','wtf')
nsml<-DocumentTermMatrix(amazonReviews,list(dictionary = c(neg)))
nsen=rowSums(as.matrix(nsml))
psml<-DocumentTermMatrix(amazonReviews,list(dictionary = c(pos)))
psen=rowSums(as.matrix(psml))
total<-DocumentTermMatrix(amazonReviews)
nusen=rowSums(as.matrix(total))
nusen<-nusen-(psen+nsen)
senscore<-c(psen-nsen)

library(maxent)
# maximal entropy
sparse <- as.compressed.matrix(dtm)
model <- maxent(sparse[1:150,],as.factor(amazon$Actual.Sentiment)[1:150])
results <- predict(model,sparse[151:300,])

n <- "null"
res <- c(rep(n,times=300))
mres<- c(rep(n,times=300))
for(i in 151:300)
{
  mres[i]=results[i-150,1]
}

senmat = matrix(c(psen,nsen,nusen,senscore,res,lb,mres),ncol = 7,nrow = 300)
colnames(senmat)<-c("Positive","Negative","Neutral","Score","Result","Label","MaxEnt")

c<-0
for(i in 1:300)
{
  if(senmat[i,4]>0)
    senmat[i,5]="Positive"
  else if(senmat[i,4]<0)
    senmat[i,5]="Negative"
  else
    senmat[i,5]="Neutral"
  if(senmat[i,5]==senmat[i,6])
    c<-c+1
}
accu<-(c/300)*100

ar<-0
for(i in 1:150)
{
  if(results[i,1]==senmat[i+150,5])
    ar<-ar+1
}
mac<-(ar/150)*100

b<-0
for(i in 1:150)
{
  if(results[i,1]==senmat[i+150,6])
    b<-b+1
}
bac<-(b/150)*100
senmat[151:170,]


cat("Accuracy:",accu,"%\n","Maxent Accuracy:",mac,"%\n","Maxent vs Actual Accuracy:",bac,"%\n")


#naive-bayes
library(e1071)
nb <- naiveBayes(iphone4$Actual.Sentiment[1:150] ~ ., data = iphone4[1:150, ])
nb
summary(nb)
str(nb)
#…and the moment of reckoning
nb_test_predict <- predict(nb ,iphone4[151:300,-6])
summary(nb_test_predict)
#confusion matrix
table(pred=nb_test_predict,true=iphone4$Actual.Sentiment[151:300])

library(caret)
# actual vs predicted
result<-results[1:150,1]
actual<-lb[151:300]
output<-table(result,actual)
mean(result!=actual)
confusionMatrix(output)

# actual vs dtm
actual1<-senmat[1:300,6]
result1<-senmat[1:300,5]
output1<-table(result1,actual1)
mean(result1!=actual1)
confusionMatrix(output1)

# predicted vs dtm
a<-nb_test_predict
b<-iphone4$Actual.Sentiment[151:300]  
output2<-table(a,b)
mean(a!=b)
confusionMatrix(output2)

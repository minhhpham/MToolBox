#' Save Publication-quality plot
#' @description Savev a plot in a high-quality jpeg file for publication
#' @param plot any plot or ggplot object
#' @param res resolution (dpi)
#' @param height height (in pixels)
#' @param width width (in pixels)
#' @param dir saving directory
#' @param filename file name
#' @export

Plot.PublishPlot = function(plot,  res = 600, height = 2000, width = 4000, dir = getwd(), filename = "Plot Output"){
  jpeg(filename = paste0(dir, "/", filename, ".jpg"), res =  res, height = height, width = width)
  print(plot); dev.off()
  graphics.off()
}




#' Visualize High-dimensional data in a 3D scatter plot
#' @description Use dimension reduction (Principle Component Analysis) to visualize a classification/regression data in a 2D or 3D plot
#' @param formula regression or classification formula. If classification, the left hand side must be a factor or character. If regression, the left hand side must be numeric.
#' @param data Data Frame or matrix for the formula
#' @param dim Dimmension to be plotted. If null, will plot 2D if only 2 predictors, 3D otherwise.
#' 
#' @import plotly
#' @import ggplot2
#' @return A list of: \code{Plot}: the plot, \code{VarExplained}: proportion of variance explained by each PC, \code{TotalVarExplained}: total proportion of variance explained by PCs
#' @export
Plot.VisualizeSupervise = function(formula, data, dim = NULL){
  y = data[all.vars(formula)[1]]
  x = model.matrix(formula, data); x = x[,colnames(x) != "(Intercept)"]
  if (is.null(dim)) dim = min(3, ncol(x))
  
  # PCA
  PCA = prcomp(x)
  
  # plot
  if (is.factor(y[[1]]) | is.character(y)){
    # Classfication
    VarExplained = (PCA$sdev^2/sum(PCA$sdev^2))[1:dim]
    PCs = PCA$x[,1:dim]
    
    Group = y; colnames(Group) = "Group"
    PlotData = as.data.frame(cbind(PCs, Group)); PlotData$Group = as.factor(PlotData$Group)
    if (dim == 3){
      Plot = plot_ly(data = PlotData, x = ~PC1, y = ~PC2, z = ~PC3, color = ~Group,
                     colors = "Set1") %>%
        add_markers(marker = list(size = 5))
    }
    if (dim == 2){
      Plot = ggplot(data = PlotData, aes(x = PC1, y = PC2, col = Group)) +
        geom_point()
    }
  }else if (is.numeric(y)) {
    # Regression
    VarExplained = (PCA$sdev^2/sum(PCA$sdev^2))[1:(dim-1)]
    PCs = PCA$x[,1:(dim-1)]
    
    PlotData = as.data.frame(cbind(PCs, y))
    if (dim == 3){
      Plot = plot_ly(data = PlotData, x = ~PC1, y = ~PC2, z = ~y) %>%
        add_markers(marker = list(size = 5))
    }
    if (dim == 2){
      Plot = ggplot(data = PlotData, aes(x = PC1, y = y)) +
        geom_point()
    }
    
  }
  
  return(list(Plot = Plot, VarExplained = VarExplained, TotalVarExplained = sum(VarExplained)))
}


wss <- function(d) {
  sum(scale(d, scale = FALSE)^2)
}
wrap <- function(i, hc, x) {
  cl <- cutree(hc, i)
  spl <- split(x, cl)
  wss <- sum(sapply(spl, wss))
  wss
}

#' Plot the Elbow curve for clustering
#' @description use hierachical clustering to plot the within-group variance against number of clusters
#' @export
Plot.ClusterElbow = function(Data, kmax = 8){
  WSS = rep(NA, kmax)
  hc = hclust(dist(Data), method = "ward.D2")  # cluster by ward's method, squared euclidean distance
  res <- sapply(seq.int(1, kmax), wrap, h = hc, x = Data)
  Plot = ggplot(data.frame(k = 1:kmax, WSS = res),
				aes(x = k, y = WSS)) +
			geom_line() + 
			xlab("Number of Clusters") + 
			ylab("Within-Group Sum of Squares") + 
      scale_x_continuous(breaks = 1:kmax)
  return(Plot)
}


#' Diagnostics for Logistic Regression
#' @description compute VIF and graph predictor-log(odds) relationships, graph outliers, and residual plot
#' @import tidyverse
#' @import ggplot2
#' @import broom
#' @export
Plot.LogisticRegDiag = function(Model){
  if (! "glm" %in% class(Model)) stop("Not Logistic regression model")
  
  # multi colinearity
  Out.VIF = car::vif(Model)
  
  # graph predictor-log(oods)
  probs = predict(Model, type = "response")

  plotdata <- Model$data %>%
    dplyr::select_if(is.numeric) 
  target = all.vars(Model$formula)[1] 
  if (target %in% colnames(plotdata))
    plotdata = select(plotdata, -target)# remove target variable
  
  predictors <- colnames(plotdata)
  plotdata = plotdata %>%
    mutate(logit = log(probs/(1-probs))) %>%
    gather(key = "predictors", value = "predictor.value", -logit)
  Out.RelationshipPlot = ggplot(plotdata, aes(logit, predictor.value))+
    geom_point(size = 0.5, alpha = 0.5) +
    geom_smooth(method = "auto") + 
    theme_bw() + 
    facet_wrap(~predictors, scales = "free_y") +
    xlab("Log of odds") + 
    ylab("Predictor value")
  
  # influential points
  plot.new()
  plot(Model, which = 4, id.n = 3) 
  Out.influential = recordPlot()
  dev.off()
  
  # Residual plots
  modelData = broom::augment(Model) %>% 
    mutate(index = 1:n()) 
  Out.Residual = ggplot(modelData, aes(index, .std.resid)) + 
    geom_point(aes(color = Model$y), alpha = .5) +
    theme_bw()  
  
  return(list(
    VIF = Out.VIF,
    RelationshipPlot = Out.RelationshipPlot,
    InfluentialPlot = Out.influential,
    ResidualPlot = Out.Residual
  ))
}

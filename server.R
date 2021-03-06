shinyServer(function(input, output, session) {

  observe({
    nodesList<<-input$.nodesData
  })
  
  TreeStruct=reactive({
    m=structure.list[[input$m]]
    df=m
    if(is.null(input$.nodesData)){
      df=m
    }else{
      x.filter=tree.filter(input$.nodesData,m)
      if(!is.null(x.filter)) df=ddply(x.filter,.(id),function(a.x){m%>%filter_(.dots = list(a.x$x2))%>%distinct})
    }
    df<-df%>%select(-c(id,value))%>%mutate_each(funs(factor))
    df.global<<-df
    df
  })
  
  StanSelect=reactive({
    if(input$goButton==0){
      sim.output=stan.sim.output
    }else{
      out=read.stan(RunStan()[['out']],structure.list[['Stan']])
    }
    
    out=read.stan(sim.output,TreeStruct())
    
    return(out)
  })
  
  RunStan<-eventReactive(input$goButton,{
    ex=TreeStruct()%>%select(r.files)%>%mutate_each(funs(as.character))%>%unique
    ex$chapter=unlist(lapply(lapply(strsplit(ex$r.files,'[\\_]'),'[',1),function(x) paste('Ch',strsplit(x,'[\\.]')[[1]][1],sep='.')))
    ex$example=unlist(lapply(lapply(strsplit(ex$r.files,'[\\_]'),'[',1),function(x) strsplit(x,'[\\.]')[[1]][2]))
    
    out=dlply(ex,.(r.files),.fun=function(x) {
      RunStanGit(url.loc='https://raw.githubusercontent.com/stan-dev/example-models/master/ARM/',
                 dat.loc=paste0(x$chapter,'/'),
                 r.file=x$r.files)
      },.progress = 'text')
    msg<-'Done'
    structure.list$Stan<<-stan.tree.construct(out)%>%mutate(value=NA)%>%distinct
    return(list(msg=msg,out=out))
  })
  
  RunShinyStan<-eventReactive(input$shinystan,{
    if(input$goButton==0){
      sim.output=stan.sim.output
    }else{
      sim.output=RunStan()[['out']]
    }
    
    output.names=ldply(sim.output,.fun=function(x) data.frame(stan.obj.output=names(x)))
    
    df=output.names%>%filter(stan.obj.output==input$TableView)
    check.global<<-df
    launch_shinystan(sim.output[[df$r.files]][[df$stan.obj.output]])
  })
  
  output$d3 <- reactive({
    m=structure.list[[input$m]]
    if(is.null(input$Hierarchy)){
      p=m
    }else{
      p=m%>%select(one_of(c(input$Hierarchy,"value")))%>%unique  
    }
    
    list(root = df2tree(p), layout = 'collapse')
    })
  
  output$table <- DT::renderDataTable(expr = {
    
    if(input$m=='Stan') {
      x.out=StanSelect()[[input$TableView]]
      x.out=x.out[,!apply(x.out,2,function(x) all(is.na(x)))]
    }else{
        x.out=TreeStruct()
    }
    
    return(x.out)
  },
    extensions = c('Buttons','Scroller','ColReorder','FixedColumns'), 
    filter='top',
    options = list(   deferRender = TRUE,
                      scrollX = TRUE,
                      pageLength = 50,
                      scrollY = 500,
                      scroller = TRUE,
                      dom = 'Bfrtip',
                      colReorder=TRUE,
                      fixedColumns = TRUE,
                      buttons = c('copy', 'csv', 'excel', 'pdf', 'print','colvis'))
  )

  output$results <- renderPrint({
    str.out=''
    if(!is.null(input$.nodesData)) str.out=tree.filter(input$.nodesData,m)
    str.out.global<<-str.out
    return(str.out)
  })
  
  output$results2 <- renderPrint({
  RunStan()[['msg']]
  })
  
  output$Hierarchy <- renderUI({
    Hierarchy=names(structure.list[[input$m]])
    Hierarchy=Hierarchy[-length(Hierarchy)]
    Hierarchy=Hierarchy[!(Hierarchy%in%c("stan.obj.output","model.eq"))]
    if(input$m=='Stan') Hierarchy=c('stan.obj.output','Chain','Measure','variable')
    selectInput("Hierarchy","Tree Hierarchy",choices = Hierarchy,multiple=T,selected = Hierarchy)
  })
  
  output$TableView <- renderUI({
    nm=names(StanSelect())
    selectInput("TableView","Stan Output Objects",choices = nm,multiple=F,selected = nm[1])
  })
  
  output$downloadSave <- downloadHandler(
    filename = "StanOutput.RData",
    content = function(con) {
      
      unpack.list <- function(object) {
        for(.x in names(object)){
          assign(value = object[[.x]], x=.x, envir = parent.frame())
        }
      }
      
      if(input$goButton==0){
        shiny.output=stan.sim.output
      }else{
        shiny.output=RunStan()[['out']]
      }
      
      ret.obj=as.character(unlist(lapply(shiny.output,names)))
      
      for(i in 1:length(shiny.output)) unpack.list(shiny.output[[i]])

      save(list=ret.obj, file=con)
    }
  )
  
})
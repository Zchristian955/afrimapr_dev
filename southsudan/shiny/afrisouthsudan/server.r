#afrimapr_dev/southsudan/afrisouthsudan/server.r

# app to view south sudan health facility data

library(remotes)
library(leaflet)
library(ggplot2)
library(patchwork) #for combining ggplots

if(!require(afrihealthsites)){
  remotes::install_github("afrimapr/afrihealthsites")
}

library(afrihealthsites)
#library(mapview)


#global variables

# load moh health facility data
# created in compare_moh_south_sudan.Rmd
load('sfssd.rda')

sfssdcoords <- sfssd[which(sfssd$Location!="0.00000, 0.00000"),] 

# to try to allow retaining of map zoom, when type checkboxes are selected
zoom_view <- NULL
# when country is changed I want whole map to change
# but when input$hs_amenity or input$selected_who_cats are changed I want to retain zoom
# perhaps can just reset zoomed view to NULL when country is changed


# Define a server for the Shiny app
function(input, output) {

  ######################################
  # mapview interactive leaflet map plot
  output$serve_healthsites_map <- renderLeaflet({

    mapplot <- afrihealthsites::compare_hs_sources("south sudan",
                                                   datasources=c('healthsites','who'),
                                                   plot='mapview',
                                                   plotshow=FALSE,
                                                   hs_amenity=input$hs_amenity,
                                                   type_column = input$who_type_option, #allows for 9 broad cats
                                                   who_type=input$selected_who_cats,
                                                   admin_level=input$cboxadmin,
                                                   admin_names=input$selected_admin_names)

    ###################################################################
    # adding the MoH data to the mapplot object
    

    # TODO add UI element for MoH types & allow selection here
    
    # allow subset by admin region
    # sfssdcoords <- afrihealthsites::afrihealthsites("south sudan", datasource = sfssdcoords, plot = FALSE,
    #                                           admin_level=input$cboxadmin,
    #                                           admin_names=input$selected_admin_names)
    # adding facility type selection too 
    sfssdcoords <- afrihealthsites::afrihealthsites("south sudan", datasource = sfssdcoords, plot = FALSE,
                                                    type_column = "type", #TODO allow for broad cats
                                                    type_filter=input$selected_moh_cats,                                                    
                                                    admin_level=input$cboxadmin,
                                                    admin_names=input$selected_admin_names)    
    
    
    numcolours <- length(unique(sfssdcoords$type))
    mapplot <- mapplot + mapview::mapview(sfssdcoords,
                                          zcol = "type",
                                          label=paste("MoH",sfssdcoords[["type"]],sfssdcoords[["Facility"]]),
                                          layer.name = "MoH",
                                          col.regions = RColorBrewer::brewer.pal(numcolours, "Oranges"))    
    
    # to retain zoom if only types have been changed
    if (!is.null(zoom_view))
    {
      mapplot@map <- leaflet::fitBounds(mapplot@map, lng1=zoom_view$west, lat1=zoom_view$south, lng2=zoom_view$east, lat2=zoom_view$north)
    }


    #important that this returns the @map bit
    #otherwise get Error in : $ operator not defined for this S4 class
    mapplot@map

    })

  #########################################################################
  # trying to detect map zoom as a start to keeping it when options changed
  observeEvent(input$serve_healthsites_map_bounds, {

    #print(input$serve_healthsites_map_bounds)

    #save to a global object so can reset to it
    zoom_view <<- input$serve_healthsites_map_bounds
  })

  ####################################################################
  # perhaps can just reset zoomed view to NULL when country is changed
  # hurrah! this works, is it a hack ?
  # observe({
  #   input$country
  #   zoom_view <<- NULL
  # })


  ###################################
  # to update map without resetting everything use leafletProxy
  # see https://rstudio.github.io/leaflet/shiny.html
  # Incremental changes to the map should be performed in
  # an observer. Each independent set of things that can change
  # should be managed in its own observer.
  # BUT I don't quite know how to use with a mapview map ...
  # observe({
  #   #pal <- colorpal()
  #   # leafletProxy("map", data = filteredData()) %>%
  #   #   clearShapes() %>%
  #   #   addCircles(radius = ~10^mag/10, weight = 1, color = "#777777",
  #   #              fillColor = ~pal(mag), fillOpacity = 0.7, popup = ~paste(mag)
  #   #  )
  # })


  ################################################################################
  # dynamic selectable list of who facility categories for selected country
  output$select_who_cat <- renderUI({

    # get categories in who for this country
    # first get the sf object - but later don't need to do that
    # TODO add a function to afrihealthsites package to return just the cats
    sfwho <- afrihealthsites::afrihealthsites("south sudan", datasource = 'who', plot = FALSE)

    #who_cats <- unique(sfwho$`Facility type`)
    # allowing for 9 cat reclass, & 4 Tiers
    who_cats <- sort(unique(sfwho[[input$who_type_option]]))

    #"who-kemri categories"
    checkboxGroupInput("selected_who_cats", label = NULL, #label = h5("who-kemri categories"),
                       choices = who_cats,
                       selected = who_cats,
                       inline = FALSE)
  })
  
  ################################################################################
  # dynamic selectable list of MoH facility categories 
  output$select_moh_cat <- renderUI({
    
    # I could repeat acquiring data to allow admin region selection to occur
    # simpler here just uses whole datset so that it doesn't change based on admin region selection
    
    # TODO could allowing for 4 Tiers reclass when I've done
    #moh_cats <- sort(unique(sfwho[[input$who_type_option]]))
    moh_cats <- sort(unique(sfssd[["type"]]))
        
    #"who-kemri categories"
    checkboxGroupInput("selected_moh_cats", label = "MoH categories",
                       choices = moh_cats,
                       selected = moh_cats,
                       inline = FALSE)
  })  
  

  ################################################################################
  # dynamic selectable list of admin regions for selected country [&later admin level]
  output$select_admin <- renderUI({


    # get categories in who for this country
    # first get the sf object - but maybe later don't need to do that
    # TODO? add a function to afriadmin package to return just the cats
    sfadmin <- afriadmin::afriadmin("south sudan", datasource = 'geoboundaries', plot = FALSE)

    admin_names <- unique(sfadmin$shapeName)

    #should I allow multiple regions or just one ?
    #problem doing this as checkboxGroupInput is that it takes up loads of space
    #better  MVP may be to offer selectInput() with just one regions selectable
    #or selectInput even with multiple selections allowed takes less space
    #checkboxGroupInput("selected_admin_names", label = NULL, #label = h5("who-kemri categories"),
    selectInput("selected_admin_names", label = NULL, #label = h5("who-kemri categories"),
                       choices = admin_names,
                       selected = admin_names[1],
                       size=5, selectize=FALSE, multiple=TRUE)
  })

  ########################
  # barplot of facility types
  output$plot_fac_types <- renderPlot({


    #palletes here set to match those in map from compare_hs_sources()

    gg1 <- afrihealthsites::facility_types("south sudan",
                                    datasource = 'healthsites',
                                    plot = TRUE,
                                    type_filter = input$hs_amenity,
                                    #ggcolour_h=c(0,175)
                                    brewer_palette = "YlGn",
                                    admin_level=input$cboxadmin,
                                    admin_names=input$selected_admin_names )

    gg2 <- afrihealthsites::facility_types("south sudan",
                                           datasource = 'who',
                                           plot = TRUE,
                                           type_filter = input$selected_who_cats,
                                           type_column = input$who_type_option, #allows for 9 broad cats
                                           #ggcolour_h=c(185,360)
                                           brewer_palette = "BuPu",
                                           admin_level=input$cboxadmin,
                                           admin_names=input$selected_admin_names )
    
    #moh data
    #BEWARE whether to use sfssd including those with no coords ?
    gg3 <- afrihealthsites::facility_types("south sudan",
                                           datasource = sfssd, #using sf stops it from needing names of coord columns
                                           plot = TRUE,
                                           #lonlat_columns =
                                           type_column = "type", #TODO allow for broad cats
                                           type_filter=input$selected_moh_cats,    
                                           brewer_palette = "Oranges",
                                           admin_level=input$cboxadmin,
                                           admin_names=input$selected_admin_names )

    # avoid error for N.Africa countries with no WHO data
    if (is.null(gg2))
    {
      gg1

    } else
    {
      #set xmax to be the same for both plots
      #hack to find max xlim for each object
      #TODO make this less hacky ! it will probably fail when ggplot changes
      max_x1 <- max(ggplot_build(gg1)$layout$panel_params[[1]]$x$continuous_range)
      max_x2 <- max(ggplot_build(gg2)$layout$panel_params[[1]]$x$continuous_range)
      max_x3 <- max(ggplot_build(gg3)$layout$panel_params[[1]]$x$continuous_range)
      
      #set xmax for all plots to this
      max_x <- max(max_x1,max_x2,max_x3, na.rm=TRUE)
      gg1 <- gg1 + xlim(c(0,max_x))
      gg2 <- gg2 + xlim(c(0,max_x))
      gg3 <- gg3 + xlim(c(0,max_x))
      
      #set size of y plots to be dependent on num cats
      #y axis has cats, this actually gets max of y axis, e.g. for 6 cats is 6.6
      max_y1 <- max(ggplot_build(gg1)$layout$panel_params[[1]]$y$continuous_range)
      max_y2 <- max(ggplot_build(gg2)$layout$panel_params[[1]]$y$continuous_range)
      max_y3 <- max(ggplot_build(gg3)$layout$panel_params[[1]]$y$continuous_range)      

      #setting heights to num cats makes bar widths constant between cats
      gg3 / gg1 / gg2 + plot_layout(heights=c(max_y3, max_y1, max_y2)) #patchwork
    }



  })

  #######################
  # table of raw who data
  output$table_raw_who <- DT::renderDataTable({

    sfwho <- afrihealthsites::afrihealthsites("south sudan", datasource = 'who', who_type = input$selected_who_cats, plot = FALSE,
                                              admin_level=input$cboxadmin,
                                              admin_names=input$selected_admin_names)

    # drop the geometry column - not wanted in table
    sfwho <- sf::st_drop_geometry(sfwho)

    DT::datatable(sfwho, options = list(pageLength = 50))

  })

  ###############################
  # table of raw healthsites data
  output$table_raw_hs <- DT::renderDataTable({

    sfhs <- afrihealthsites::afrihealthsites("south sudan", datasource = 'healthsites', hs_amenity = input$hs_amenity, plot = FALSE,
                                             admin_level=input$cboxadmin,
                                             admin_names=input$selected_admin_names)

    # drop the geometry column and few others - not wanted in table
    sfhs <- sf::st_drop_geometry(sfhs)
    sfhs <- sfhs[, which(names(sfhs)!="iso3c" & names(sfhs)!="country")]

    DT::datatable(sfhs, options = list(pageLength = 50))
  })
  
  ###############################
  # table of raw moh data
  output$table_raw_moh <- DT::renderDataTable({
    
    # This uses sfssd to include data without coords
    # sfssdcoords removes the ~300 locations without coords
    
    # TODO add UI elemnt for MoH types & allow selection here
    
    # allow subset by admin region
    sfssd <- afrihealthsites::afrihealthsites("south sudan", datasource = sfssd, plot = FALSE,
                                              type_column = "type", #TODO allow for broad cats
                                              type_filter=input$selected_moh_cats,    
                                              admin_level=input$cboxadmin,
                                              admin_names=input$selected_admin_names)
    
    # drop the geometry column and few others - not wanted in table
    sfssd <- sf::st_drop_geometry(sfssd)
    #keep LOcation in so can see when null
    #sfssd <- sfssd[, which(names(sfssd)!="Location")]
    #sfhs <- sfhs[, which(names(sfhs)!="iso3c" & names(sfhs)!="country")]
        
    DT::datatable(sfssd, options = list(pageLength = 50))
  })  
  

  ###############################
  # table of national list (MFL) availability
  output$table_national_list_avail <- DT::renderDataTable({


    DT::datatable(national_list_avail(), options = list(pageLength = 55))
  })

}

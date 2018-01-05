options(warn=-1)

# get command line options ====
localExecute <- FALSE
write_config <- ''
args <- commandArgs(trailingOnly=TRUE)
if(length(args) > 0){
        if(args[1] == '-l'){
                localExecute <- TRUE
                if(length(args) == 2){
                        write_config <- args[2]
                } else {
                        stop('invalid parameters')
                }
                args <- args[c(FALSE, rep(TRUE, length(args)-1))]
        } else {
                write_config <- args[1]
        }
}
configParsed <- ''
if(nchar(write_config) > 0){
        if(!jsonlite::validate(write_config)){
                stop('invalid input: parameters - cannot parse JSON')
        }
        configParsed <- jsonlite::fromJSON(write_config, simplifyVector = FALSE)
} else {
        stop('invalid parameters: configuration missing')
}

# get data from STDIN ====
myStdin <- file("stdin")
input <- suppressWarnings(readLines(myStdin))
close(myStdin)
if(!jsonlite::validate(input)){
        stop('invalid input: stdin - cannot parse JSON')
}
inputParsed <- as.data.frame(jsonlite::fromJSON(input))

# validation ====
pia_url <- ''
if('pia_url' %in% names(configParsed)){
        pia_url <- configParsed$pia_url 
} else {
        stop('invalid format: attribute "pia_url" missing')
}

app_key <- ''
if('app_key' %in% names(configParsed)){
        app_key <- configParsed$app_key 
} else {
        stop('invalid format: attribute "app_key" missing')
}

app_secret <- ''
if('app_secret' %in% names(configParsed)){
        app_secret <- configParsed$app_secret 
} else {
        stop('invalid format: attribute "app_secret" missing')
}

repo <- ''
if('repo' %in% names(configParsed)){
        repo <- configParsed$repo 
} else {
        stop('invalid format: attribute "repo" missing')
}

repo_name <- ''
if('repo_name' %in% names(configParsed)){
        repo <- configParsed$repo_name 
} else {
        repo_name <- repo
}

delete_all <- FALSE
if('delete' %in% names(configParsed)){
        if(configParsed$delete != 'all'){
                stop('invalid input: attribute "delete" has invalid value')
        }
        delete_all <- TRUE
}

if(!('map' %in% names(configParsed))){
        stop('invalid format: attribute "map" missing')
}

# load helpeR ====
if(localExecute){
        srcPath <- '/Users/christoph/oyd/service-pia_write/docker/srv-pia_write/script/'
} else {
        srcPath <- '/srv-pia_write/'
}
source(paste0(srcPath, 'srvBase.R'))
source(paste0(srcPath, 'srvHelper.R'))
source(paste0(srcPath, 'general.R'))

# connect to PIA ====
app <- setupApp(pia_url, app_key, app_secret, '')
repo_url <- itemsUrl(app$url, repo)

# option: delete all items before import ====
if(delete_all){
        deleteRepo(app, repo_url)
}

# partial: subset of input ===
if('partial' %in% names(configParsed)){
        inputParsed <- inputParsed[configParsed$partial]
}


# create data.frame from input with new mapping
new_items <- data.frame()
if(nrow(inputParsed) > 0){
        for(i in 1:length(configParsed$map)){
                el <- configParsed$map[[i]]
                key <- names(el)
                val <- as.character(el[key])
                old_names <- colnames(new_items)
                if(nrow(new_items) == 0){
                        new_items <- as.data.frame(inputParsed[val])
                } else {
                        new_items <- cbind(new_items, inputParsed[val])
                }
                colnames(new_items) <- c(old_names, key)
        }

        if("merge" %in% names(configParsed)){
                pia_items <- readItems(app, repo_url)
                pia_items <- createDigest(pia_items, unlist(configParsed$merge))
                new_items <- createDigest(new_items, unlist(configParsed$merge))
                for(i in 1:nrow(new_items)){
                        if(!(new_items[i,'digest'] %in% pia_items$digest)){
                                record <- as.list(new_items[, ])
                                record$digest <- NULL
                                writeItem(app, repo_url, record)
                        }
                }
        } else {
                for(i in 1:nrow(new_items)){
                        tmp <- writeItem(app, repo_url, as.list(new_items[i,]))
                }
        }
}
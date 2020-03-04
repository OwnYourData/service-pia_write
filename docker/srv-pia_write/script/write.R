# write data to data vault
# last update: 2018-01-07

#options(warn=-1)

# get command line options ====
write_config <- ''
args <- commandArgs(trailingOnly=TRUE)
if(length(args) > 0){
        write_config <- args[1]
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
inputJSON <- jsonlite::fromJSON(input)

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

# connect to PIA ====
app <- oydapp::setupApp(pia_url, app_key, app_secret, '')
repo_url <- oydapp::itemsUrl(app$url, repo)
public_key <- oydapp::getRepoPubKey(app, repo)

if(nchar(public_key) > 0){
        app$encryption <- data.frame(
                repo = as.character(repo),
                key  = public_key,
                read = FALSE,
                stringsAsFactors = FALSE
        )
}

# option: delete all items before import ====
if(delete_all){
        oydapp::deleteRepo(app, repo_url)
}

# partial: subset of input ===
if('partial' %in% names(configParsed)){
        inputParsed <- as.data.frame(inputJSON[configParsed$partial])
} else {
        inputParsed <- as.data.frame(inputJSON)
}
inputParsed <- jsonlite::flatten(inputParsed, recursive = TRUE)

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
                pia_items <- oydapp::readItems(app, repo_url)
                pia_items <- oydapp::createDigest(pia_items, 
                                                  unlist(configParsed$merge))
                check_items <- oydapp::createDigest(new_items, 
                                                    unlist(configParsed$merge))
                for(i in 1:nrow(new_items)){
                        if(!(check_items[i,'digest'] %in% pia_items$digest)){
                                record <- as.list(new_items[i, ])
                                retVal <- oydapp::writeOydItem(app, 
                                                               repo_url, 
                                                               record)
                        }
                }
        } else {
                for(i in 1:nrow(new_items)){
                        retVal <- oydapp::writeOydItem(app, 
                                                    repo_url,
                                                    as.list(new_items[i,]))
                        cat(paste(toString(retVal), " \n"))
                }
        }
}
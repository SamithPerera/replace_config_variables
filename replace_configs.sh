#!/bin/bash

# Refference
# https://jqplay.org/ You can use this app to create config maps for type json.  
# https://stedolan.github.io/jq/ Used to read json files and objects.


mapperJSON="value-mapper.json";
config_output="config_map";
CURRENT_LOCATION="$(pwd .)"

#check source file location is set and assign value to a vaiarble
if $(./libs/jq -e '. | has("sourceFiles")' $mapperJSON); then

    FILEDEST_STR=$(./libs/jq '.sourceFiles'  $mapperJSON);
    FILEDEST="${FILEDEST_STR%\"}";
    FILEDEST="${FILEDEST#\"}";

else
    echo "ERROR - Couldn't find sourceFiles key in Mapper JSON"; 
fi

# Delete Old Config File
function removeExistingConfig {
    if test -f "${CURRENT_LOCATION}/"$config_output; then
        rm -rf "${CURRENT_LOCATION}/"$config_output;
    fi
}


#Get configurations from mapper JSON file.
function readMapperJson {
    
    if $(./libs/jq -e '. | has("configs")' $mapperJSON); then
        

        #get config object
        for obj in $(./libs/jq -c '.configs[]' $mapperJSON); do
            
            if $(./libs/jq -e '. | has("key")' <<< "$obj") && $(./libs/jq -e '. | has("type")' <<< "$obj"); then
                #remove quote
                KEY_STR=$(./libs/jq '.key' <<< "$obj");
                KEY="${KEY_STR%\"}";
                KEY="${KEY#\"}";

                #remove quote
                TYPE_STR=$(./libs/jq '.type' <<< "$obj");
                TYPE="${TYPE_STR%\"}";
                TYPE="${TYPE#\"}";

                if [ -z "$TYPE" ] || [ -z "$KEY" ] 
                    then
                        echo "ERROR - Key or Type not defined in Mapper JSON configs :" $obj;
                        exit 1;
                
                elif [ $TYPE = "json" ]
                then
                        if $(./libs/jq -e '. | has("jsonPath")' <<< "$obj");
                        then

                            JSONPATH_STR=$(./libs/jq '.jsonPath' <<< "$obj");
                            JSONPATH="${JSONPATH_STR%\"}";
                            JSONPATH="${JSONPATH#\"}";

                            createConfigMap $KEY $JSONPATH;
 
                        else
                            echo "ERROR - Json file path not mentioned in config Object :" $obj; 
                            exit 1;
                        fi

                elif [ $TYPE = "inline" ]
                    then
                        createConfigMap $KEY;
                        
                else
                    echo "ERROR - Unsupported type '"$KEY"' type should be json or inline :" $obj; 
                    exit 1;
                fi
            else
                echo "ERROR - Unsupported format in config Object :" $obj; 
                exit 1;
            fi

        done
    else
        echo "ERROR - Couldn't find configs in Mapper JSON"; 
        exit 1;
    fi

}


function createConfigMap {


    ####
        #Params
        # $1 - mapper json parent Key.
        # $2 - If type is json, path to JSON file.
    ####

    for k in $(./libs/jq '.'${1}'[] | keys | .[]' $mapperJSON); do

        if [ -z "$1" ]
        then
            echo "ERR - Mention parent key in mapper json when call the function"
        else
            
            #remove quote
            PLACEHOLDER="${k%\"}";
            PLACEHOLDER="${PLACEHOLDER#\"}";

            #get value
            VALUE_STR=$(./libs/jq .${1}[].$PLACEHOLDER $mapperJSON);

            #remove quote
            VALUE="${VALUE_STR%\"}";
            VALUE="${VALUE#\"}";


            if [ ! -z "$2" ]
            then
                #get values from given JSON file
                CONFIG_STR=$(./libs/jq $VALUE  $2);   

                #remove quote
                CONFIG="${CONFIG_STR%\"}";
                CONFIG="${CONFIG#\"}"; 
            else
                CONFIG=$VALUE;
            fi

            echo $PLACEHOLDER"="$CONFIG >> $config_output ;

        fi


    done
    
}

function getVerification {
    ####
        #Params
        # $1 - New Config map path.
    ####

    cat $1;
    echo "  ";
    echo "***********************************************************************";
    echo "  ";

    read -p "Verify all configs are valid (y/n)?" CONT
    if [ "$CONT" = "y" ]; then
        replcaePlaceHoldersInTemplatefiles $1;
    else
        echo "Exited";
    fi
}


function replcaePlaceHoldersInTemplatefiles {
    ####
        #Params
        # $1 - New Config map path.
    ####
    FILEPATH=$1;

    while IFS='=' read -r CONFIG_PLACEHOLDER CONFIG_VALUE
    do

        #find placeholders and replace with values
        find "${CURRENT_LOCATION}/${FILEDEST}" -type f -exec sed -i -e 's|{'${CONFIG_PLACEHOLDER}'}|'${CONFIG_VALUE}'|g' {} \;

    done < $FILEPATH;
}




#copy template files to output folder (For Dev Purpose)
function copyTemplatefiles {
    
    appFolder="${CURRENT_LOCATION}/files/*";
    fileDest="${CURRENT_LOCATION}/${FILEDEST}";
    cp -rpvf $appFolder $fileDest;

}


copyTemplatefiles;
removeExistingConfig;
readMapperJson;
getVerification "${CURRENT_LOCATION}/"$config_output;


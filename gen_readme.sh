#!/bin/bash

## Usage
## From the root of the git repo, call `./gen_readme.sh` 
## followed by the module name you updated
## Example: `./gen_readme.sh domain_join`

if [[ $1 != "" ]]
then
  modules=$1
else
  modules=$(ls -d */)
fi

for module in $(ls -d */)
do
  module=$(echo $module | tr -d '/')
  readme_file="${module}/README.md"

  echo "# ${module} Module" > ${readme_file}
  echo >> ${readme_file}
  echo >> ${readme_file}
  cat ${module}/description >> ${readme_file}
  echo >> ${readme_file}

  if [[ -f ${module}/manifests/init.pp ]]
  then
    class="init"
    echo "## ${module} Class" >> ${readme_file}
    while read -r line
    do
      echo $line
      if [[ $line == "#" ]]
      then
        break
      fi
      echo $line | sed 's/^#//' | sed 's/$/  /' >> ${readme_file}
    done < ${module}/manifests/${class}.pp

    echo "### Parameters" >> ${readme_file}
    echo "|Name|Description|" >> ${readme_file}
    echo "|---|---|" >> ${readme_file}
    cat ${module}/manifests/${class}.pp | grep '^# @param' | cut -d' ' -f3- | sed 's/ /|/' | awk '{print "|" $0 "|" }' >> ${readme_file}
  fi

  for class in $(ls ${module}/manifests)
  do
    if [[ $class == "init.pp" ]]
    then
      continue
    fi

    class=${class/.pp/}

    echo "## ${module}::${class} Parameters" >> ${readme_file}
    echo "|Name|Description|" >> ${readme_file}
    echo "|---|---|" >> ${readme_file}
    cat ${module}/manifests/${class}.pp | grep '^# @param' | cut -d' ' -f3- | sed 's/ /|/' | awk '{print "|" $0 "|" }' >> ${readme_file}
  done
done

if [[ $1 == "" ]]
then
  readme_file="README.md"
  echo "# Puppet Modules" > ${readme_file}
  for module in $(ls -d */)
  do
    module=$(echo $module | tr -d '/')
    echo "1. [${module}](${module}/README.md)  " >> ${readme_file}
    cat ${module}/description >> ${readme_file}
    echo >> ${readme_file}
  done
fi
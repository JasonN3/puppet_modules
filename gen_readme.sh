#!/bin/bash

## Usage
## From the root of the git repo, call `./gen_readme.sh` 
## followed by the module name you updated
## Example: `./gen_readme.sh domain_join`

function gen_class_info() {
  while read -r line
  do
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
  echo >> ${readme_file}
  echo "---" >> ${readme_file}
  echo >> ${readme_file}
}

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
    echo "## Class ${module}" >> ${readme_file}
    gen_class_info
  fi

  for class in $(ls ${module}/manifests)
  do
    if [[ $class == "init.pp" || $class = lib_* ]]
    then
      continue
    fi

    class=${class/.pp/}

    echo "## Class ${module}::${class}" >> ${readme_file}
    gen_class_info
  done
done

if [[ $1 == "" ]]
then
  readme_file="README.md"
  echo -n > ${readme_file}
  if [[ -f .readme/header.md ]]
  then
    cat .readme/header.md >> ${readme_file}
    echo '---' >> ${readme_file}
  fi
  echo "## Modules list" >> ${readme_file}
  for module in $(ls -d */)
  do
    module=$(echo $module | tr -d '/')
    echo "1. [${module}](${module}/README.md)  " >> ${readme_file}
    cat ${module}/description >> ${readme_file}
    echo >> ${readme_file}
  done
  if [[ -f .readme/footer.md ]]
  then
    echo '---' >> ${readme_file}
    cat .readme/footer.md >> ${readme_file}
  fi
fi
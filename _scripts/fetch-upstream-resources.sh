#!/bin/bash

# Fetches upstream resources from docker/docker and docker/distribution
# before handing off the site to Jekyll to build
# Relies on the following environment variables which are usually set by
# the Dockerfile. Uncomment them here to override for debugging

# Parse some variables from _config.yml and make them available to this script
# This only finds top-level variables with _version in them that don't have any
# leading space. This is brittle!

SOURCE="$1"

if [ -z "$SOURCE" ]; then
  echo "No source passed in, assuming md_source/..."
  SOURCE="md_source"
fi

while read i; do
  # Store the key as a variable name and the value as the variable value
  varname=$(echo "$i" | sed 's/"//g' | awk -F ':' {'print $1'} | tr -d '[:space:]')
  varvalue=$(echo "$i" | sed 's/"//g' | awk -F ':' {'print $2'} | tr -d '[:space:]')
  echo "Setting \$${varname} to $varvalue"
  declare "$varname=$varvalue"
done < <(cat ${SOURCE}/_config.yml |grep '_version:' |grep '^[a-z].*')

# Replace variable in toc.yml with value from above
echo "Replacing the string 'site.latest_stable_docker_engine_api_version' in _data/toc.yml with ${latest_stable_docker_engine_api_version}"
sed -i "s/{{ site.latest_stable_docker_engine_api_version }}/${latest_stable_docker_engine_api_version}/g" ${SOURCE}/_data/toc.yaml

# Directories to get via SVN. We use this because you can't use git to clone just a portion of a repository
svn co https://github.com/docker/docker-ce/${ENGINE_SVN_BRANCH}/components/cli/docs/extend ${SOURCE}/engine/extend || (echo "Failed engine/extend download" && exit 1)
svn co https://github.com/docker/docker-ce/${ENGINE_SVN_BRANCH}/components/engine/docs/api ${SOURCE}/engine/api    || (echo "Failed engine/api download" && exit 1) # This will only get you the old API MD files 1.18 through 1.24
svn co https://github.com/docker/distribution/${DISTRIBUTION_SVN_BRANCH}/docs/spec         ${SOURCE}/registry/spec || (echo "Failed registry/spec download" && exit 1)
svn co https://github.com/docker/compliance/trunk/docs/compliance                          ${SOURCE}/compliance    || (echo "Failed docker/compliance download" && exit 1)

## Get dockerd.md for stable and edge, from upstream
#curl  --create-dirs -fsSL -o ${SOURCE}/engine/reference/commandline/dockerd.md https://raw.githubusercontent.com/docker/docker-ce/${ENGINE_BRANCH}/components/cli/docs/reference/commandline/dockerd.md           || (echo "Failed to fetch stable dockerd.md" && exit 1)
#curl  --create-dirs -fsSL -o ${SOURCE}/edge/engine/reference/commandline/dockerd.md https://raw.githubusercontent.com/docker/docker-ce/${ENGINE_EDGE_BRANCH}/components/cli/docs/reference/commandline/dockerd.md || (echo "Failed to fetch edge dockerd.md" && exit 1)
#
## Add an admonition to the edge dockerd file
#EDGE_DOCKERD_INCLUDE='{% include edge_only.md section=\"dockerd\" %}'
#sed -i "s/^#\ daemon/${EDGE_DOCKERD_INCLUDE}/1" ${SOURCE}/edge/engine/reference/commandline/dockerd.md
#
## Get a few one-off files that we use directly from upstream
#curl  --create-dirs -fsSL -o ${SOURCE}/engine/reference/builder.md https://raw.githubusercontent.com/docker/docker-ce/${ENGINE_BRANCH}/components/cli/docs/reference/builder.md || (echo "Failed engine/reference/builder.md download" && exit 1)
#curl  --create-dirs -fsSL -o ${SOURCE}/engine/reference/run.md https://raw.githubusercontent.com/docker/docker-ce/${ENGINE_BRANCH}/components/cli/docs/reference/run.md         || (echo "Failed engine/reference/run.md download" && exit 1)
## Adjust this one when Edge != Stable
#curl  --create-dirs -fsSL -o ${SOURCE}/edge/engine/reference/run.md https://raw.githubusercontent.com/docker/docker-ce/${ENGINE_BRANCH}/components/cli/docs/reference/run.md    || (echo "Failed engine/reference/run.md download" && exit 1)
#curl  --create-dirs -fsSL -o ${SOURCE}/engine/reference/commandline/cli.md https://raw.githubusercontent.com/docker/docker-ce/${ENGINE_BRANCH}/components/cli/docs/reference/commandline/cli.md || (echo "Failed engine/reference/commandline/cli.md download" && exit 1)
#curl  --create-dirs -fsSL -o ${SOURCE}/engine/deprecated.md https://raw.githubusercontent.com/docker/docker-ce/${ENGINE_BRANCH}/components/cli/docs/deprecated.md   || (echo "Failed engine/deprecated.md download" && exit 1)
#curl  --create-dirs -fsSL -o ${SOURCE}/registry/configuration.md https://raw.githubusercontent.com/docker/distribution/${DISTRIBUTION_BRANCH}/docs/configuration.md || (echo "Failed registry/configuration.md download" && exit 1)

# Remove things we don't want in the build
rm -f  ${SOURCE}/registry/spec/api.md.tmpl

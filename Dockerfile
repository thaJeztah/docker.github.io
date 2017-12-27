# This Dockerfile builds the docs for https://docs.docker.com/
# from the master branch of https://github.com/docker/docker.github.io
#
# Here is the sequence:
# 1.  Fetch upstream resources
# 2.  Set up the build
# 3.  Build static HTML from master
# 4.  Reset to clean tiny nginx image
# 5.  Copy Nginx config and archive HTML, which don't change often and can be cached
# 6.  Copy static HTML from previous build stage (step 3)
#
# When the image is run, it starts Nginx and serves the docs at port 4000

####### START UPSTREAM RESOURCES ########
FROM alpine AS upstream_resources

RUN apk add --no-cache bash curl sed subversion

# Set the source directory
ENV SOURCE=md_source

# Get the Engine APIs that are in Swagger
# When you change this you need to make sure to copy the previous
# directory into a new one in the docs git and change the index.html
ADD https://raw.githubusercontent.com/docker/docker/v1.13.0/api/swagger.yaml     ${SOURCE}/engine/api/v1.25/swagger.yaml
ADD https://raw.githubusercontent.com/docker/docker/v17.03.0-ce/api/swagger.yaml ${SOURCE}/engine/api/v1.26/swagger.yaml
ADD https://raw.githubusercontent.com/docker/docker/v17.03.2-ce/api/swagger.yaml ${SOURCE}/engine/api/v1.27/swagger.yaml
ADD https://raw.githubusercontent.com/docker/docker/v17.04.0-ce/api/swagger.yaml ${SOURCE}/engine/api/v1.28/swagger.yaml
ADD https://raw.githubusercontent.com/docker/docker/v17.05.0-ce/api/swagger.yaml ${SOURCE}/engine/api/v1.29/swagger.yaml

# New location for swagger.yaml for 17.06 and up
ADD https://raw.githubusercontent.com/docker/docker-ce/17.06/components/engine/api/swagger.yaml ${SOURCE}/engine/api/v1.30/swagger.yaml
ADD https://raw.githubusercontent.com/docker/docker-ce/17.07/components/engine/api/swagger.yaml ${SOURCE}/engine/api/v1.31/swagger.yaml
ADD https://raw.githubusercontent.com/docker/docker-ce/17.09/components/engine/api/swagger.yaml ${SOURCE}/engine/api/v1.32/swagger.yaml
ADD https://raw.githubusercontent.com/docker/docker-ce/17.10/components/engine/api/swagger.yaml ${SOURCE}/engine/api/v1.33/swagger.yaml
ADD https://raw.githubusercontent.com/docker/docker-ce/17.11/components/engine/api/swagger.yaml ${SOURCE}/engine/api/v1.34/swagger.yaml

RUN chmod -R 644 ${SOURCE}/engine/api/

# TODO COPY/REPLICATE SWAGGER BOILERPLATING TO EACH DIRECTORY!!

# Set vars used by fetch-upstream-resources.sh script
## Branch to pull from, per ref doc
## To get master from svn the svn branch needs to be 'trunk'. To get a branch from svn it needs to be 'branches/branchname'

# Engine
ENV ENGINE_BRANCH=17.09
ENV ENGINE_SVN_BRANCH=branches/${ENGINE_BRANCH}
ENV ENGINE_EDGE_BRANCH=17.11

# Distribution
ENV DISTRIBUTION_BRANCH=release/2.6
ENV DISTRIBUTION_SVN_BRANCH=branches/${DISTRIBUTION_BRANCH}

# Get dockerd.md for stable and edge, from upstream
ADD https://raw.githubusercontent.com/docker/docker-ce/${ENGINE_BRANCH}/components/cli/docs/reference/commandline/dockerd.md ${SOURCE}/engine/reference/commandline/dockerd.md

#curl  --create-dirs -fsSL -o ${SOURCE}/edge/engine/reference/commandline/dockerd.md https://raw.githubusercontent.com/docker/docker-ce/${ENGINE_EDGE_BRANCH}/components/cli/docs/reference/commandline/dockerd.md || (echo "Failed to fetch edge dockerd.md" && exit 1)
#
## Add an admonition to the edge dockerd file
#EDGE_DOCKERD_INCLUDE='{% include edge_only.md section=\"dockerd\" %}'
#sed -i "s/^#\ daemon/${EDGE_DOCKERD_INCLUDE}/1" ${SOURCE}/edge/engine/reference/commandline/dockerd.md

# Get a few one-off files that we use directly from upstream
ADD https://raw.githubusercontent.com/docker/docker-ce/${ENGINE_BRANCH}/components/cli/docs/reference/builder.md            ${SOURCE}/engine/reference/builder.md
ADD https://raw.githubusercontent.com/docker/docker-ce/${ENGINE_BRANCH}/components/cli/docs/reference/run.md                ${SOURCE}/engine/reference/run.md

# Adjust this one when Edge != Stable
ADD https://raw.githubusercontent.com/docker/docker-ce/${ENGINE_BRANCH}/components/cli/docs/reference/run.md                ${SOURCE}/edge/engine/reference/run.md
ADD https://raw.githubusercontent.com/docker/docker-ce/${ENGINE_BRANCH}/components/cli/docs/reference/commandline/cli.md    ${SOURCE}/engine/reference/commandline/cli.md
ADD https://raw.githubusercontent.com/docker/docker-ce/${ENGINE_BRANCH}/components/cli/docs/deprecated.md                   ${SOURCE}/engine/deprecated.md

ADD https://raw.githubusercontent.com/docker/distribution/${DISTRIBUTION_BRANCH}/docs/configuration.md                      ${SOURCE}/registry/configuration.md

# Fetch upstream resources
COPY ./_data/toc.yaml ${SOURCE}/_data/toc.yaml
COPY ./_scripts ${SOURCE}/_scripts
COPY ./_config.yml ${SOURCE}/_config.yml

RUN ./${SOURCE}/_scripts/fetch-upstream-resources.sh ${SOURCE}


FROM docs/docker.github.io:docs-builder AS samples

# Set the source and target directory
ENV SOURCE=md_source
ENV TARGET=/usr/share/nginx/html

# Fetch upstream resources
COPY ./_data/toc.yaml ${SOURCE}/_data/toc.yaml
COPY ./_config.yml ${SOURCE}/_config.yml
COPY ./_includes   ${SOURCE}/_includes
COPY ./_layouts    ${SOURCE}/_layouts
COPY ./_samples    ${SOURCE}/_samples
COPY ./_scripts    ${SOURCE}/_scripts
COPY ./samples     ${SOURCE}/samples

RUN ./${SOURCE}/_scripts/generate-library-front-matter.sh

# Build the static HTML, now that everything is in place
RUN jekyll build -s ${SOURCE} -d ${TARGET} --config ${SOURCE}/_config.yml

# TODO ADD GZIP COMPRESSION AND OPTIMIZATION HERE!!!!

# Get basic configs and Jekyll env
FROM docs/docker.github.io:docs-builder AS builder

# Set the target again
ENV TARGET=/usr/share/nginx/html

# Set the source directory to md_source
ENV SOURCE=md_source

# Get a colliding file out of the way
RUN rm -f ${SOURCE}/index.html

# Get the current docs from the checked out branch
# ${SOURCE} will contain a directory for each archive
COPY . ${SOURCE}

# ${SOURCE} now contains the Markdown files for master.
# We still need to fetch upstream resources and then to build with Jekyll.
COPY --from=upstream_resources ${SOURCE} ${SOURCE}

# Build the static HTML, now that everything is in place

RUN jekyll build -s ${SOURCE} -d ${TARGET} --config ${SOURCE}/_config.yml

# Fix up some links, don't touch the archives
RUN find ${TARGET} -type f -name '*.html' | grep -vE "v[0-9]+\." | while read i; do sed -i 's#href="https://docs.docker.com/#href="/#g' "$i"; done

# TODO ADD GZIP COMPRESSION AND OPTIMIZATION HERE!!!!

# BUILD OF MASTER DOCS IS NOW DONE!

# Reset to alpine so we don't get any docs source or extra apps
FROM nginx:alpine

# Set the target again
ENV TARGET=/usr/share/nginx/html

# Get the nginx config from the nginx-onbuild image
# This hardly ever changes so should usually be cached
COPY --from=docs/docker.github.io:nginx-onbuild /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf

# Serve the site (target), which is now all static HTML
CMD echo -e "Docker docs are viewable at:\nhttp://0.0.0.0:4000"; exec nginx -g 'daemon off;'

# Get all the archive static HTML and put it into place
# Go oldest-to-newest to take advantage of the fact that we change older
# archives less often than new ones.
# To add a new archive, add it here
# AND ALSO edit _data/docsarchives/archives.yaml to add it to the drop-down
COPY --from=docs/docker.github.io:v1.4 ${TARGET} ${TARGET}
COPY --from=docs/docker.github.io:v1.5 ${TARGET} ${TARGET}
COPY --from=docs/docker.github.io:v1.6 ${TARGET} ${TARGET}
COPY --from=docs/docker.github.io:v1.7 ${TARGET} ${TARGET}
COPY --from=docs/docker.github.io:v1.8 ${TARGET} ${TARGET}
COPY --from=docs/docker.github.io:v1.9 ${TARGET} ${TARGET}
COPY --from=docs/docker.github.io:v1.10 ${TARGET} ${TARGET}
COPY --from=docs/docker.github.io:v1.11 ${TARGET} ${TARGET}
COPY --from=docs/docker.github.io:v1.12 ${TARGET} ${TARGET}
COPY --from=docs/docker.github.io:v1.13 ${TARGET} ${TARGET}
COPY --from=docs/docker.github.io:v17.03 ${TARGET} ${TARGET}
COPY --from=docs/docker.github.io:v17.06 ${TARGET} ${TARGET}

# Get a colliding file out of the way
RUN rm -f ${SOURCE}/index.html

# Get the built docs output from the previous build stage
# This ordering means all previous layers can come from cache unless an archive
# changes
COPY --from=builder ${TARGET} ${TARGET}

# Copy the library-samples on top (they have the correct navigation)
COPY --from=samples ${TARGET} ${TARGET}

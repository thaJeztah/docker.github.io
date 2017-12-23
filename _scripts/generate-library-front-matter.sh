#!/usr/bin/env bash

# Get the Library docs
svn co https://github.com/docker-library/docs/trunk ${SOURCE}/_samples/library || (echo "Failed library download" && exit 1)
# Remove symlinks to maintainer.md because they break jekyll and we don't use em
find ${SOURCE}/_samples/library -maxdepth 9  -type l -delete

# Loop through the README.md files, turn them into rich index.md files
FILES=$(find ${SOURCE}/_samples/library -type f -name 'README.md')
for f in $FILES
do
  curdir=$(dirname "${f}")
  repo_name="${curdir##*/}"
  if [ -e ${curdir}/README-short.txt ]
  then
    shortrm=$(cat ${curdir}/README-short.txt)
  fi
  echo "Adding front-matter to ${f} ..."
  echo --- >> ${curdir}/front-matter.txt
  echo title: "${repo_name}" >> ${curdir}/front-matter.txt
  echo keywords: library, sample, ${repo_name} >> ${curdir}/front-matter.txt
  echo repo: "${repo_name}" >> ${curdir}/front-matter.txt
  echo layout: docs >> ${curdir}/front-matter.txt
  echo permalink: /samples/library/${repo_name}/ >> ${curdir}/front-matter.txt
  echo redirect_from: >> ${curdir}/front-matter.txt
  echo - /samples/${repo_name}/ >> ${curdir}/front-matter.txt
  echo description: \| >> ${curdir}/front-matter.txt
  echo \ \ ${shortrm} >> ${curdir}/front-matter.txt
  echo --- >> ${curdir}/front-matter.txt
  echo >> ${curdir}/front-matter.txt
  echo ${shortrm} >> ${curdir}/front-matter.txt
  echo >> ${curdir}/front-matter.txt
  if [ -e ${curdir}/github-repo ]
  then
    gitrepo=$(cat ${curdir}/github-repo)
    echo >> ${curdir}/front-matter.txt
    echo GitHub repo: \["${gitrepo}"\]\("${gitrepo}"\)\{: target="_blank"\} >> ${curdir}/front-matter.txt
    echo >> ${curdir}/front-matter.txt
  fi
  cat ${curdir}/front-matter.txt ${SOURCE}/_samples/boilerplate.txt > ${curdir}/header.txt
  echo {% raw %} >> ${curdir}/header.txt
  cat ${curdir}/header.txt ${curdir}/README.md > ${curdir}/index.md
  echo {% endraw %} >> ${curdir}/index.md
  rm -f ${curdir}/*.txt
  rm -f ${curdir}/content.md
  rm -f ${curdir}/issues.md
  rm -f ${curdir}/license.md
  rm -f ${curdir}/maintainer.md
  rm -f ${curdir}/README.md
  rm -f ${curdir}/github-repo
done

#rm -f  ${SOURCE}/_samples/library/index.md
rm -f ${SOURCE}/_samples/boilerplate.txt

# remove stray files in directory
find ${SOURCE}/_samples/library/ -maxdepth 1 -type f -delete

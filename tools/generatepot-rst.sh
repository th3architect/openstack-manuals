#!/bin/bash -xe

#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

REPOSITORY=$1
USE_DOC=$2
DOCNAME=$3

if [ $# -lt 3 ] ; then
    echo "usage $0 REPOSITORY USE_DOC DOCNAME"
    exit 1
fi

DIRECTORY=$DOCNAME
TOPDIR=""
if [ "$USE_DOC" = "1" ] ; then
    DIRECTORY="doc/$DOCNAME"
    TOPDIR="doc/"
fi

if [ -x "$(command -v getconf)" ]; then
    NUMBER_OF_CORES=$(getconf _NPROCESSORS_ONLN)
else
    NUMBER_OF_CORES=2
fi

# For Liberty, translation target is install guide only.
# To minimize the translatin resource,
# generate pot from install guide only.
# However, use common-rst process to keep current translation process.

# common-rst is imported from various RST documents, but what files are
# used varies across RST documents. Thus we need an index file to include
# all files under common-rst. To this aim, we create such document called
# 'common-rst-work' dynamically to generate the POT file of common-rst.
if [[ "$REPOSITORY" = "openstack-manuals" && "$DOCNAME" = "common-rst" ]] ; then
    # Do not generate common-rst from the whole common-rst directory.
    # common-rst.pot is generated by install guide build process.
    exit 0
    # DIRECTORY="doc/common-rst-work"
    # TOPDIR="doc/"
    # mkdir -p $DIRECTORY/source
    # cp doc/common-rst/source/conf.py $DIRECTORY/source/conf.py
    # ln -sf ../../common-rst $DIRECTORY/source/common
    # cat <<EOF > $DIRECTORY/source/index.rst
# .. toctree::
#    :maxdepth: 2
#    :glob:

#    common/*
# EOF
fi

if [ "$REPOSITORY" = "openstack-manuals" ] ; then
    # Build Glossary
    tools/glossary2rst.py doc/common-rst/glossary.rst
fi
# First remove the old pot file, otherwise the new file will contain
# old references

rm -f ${DIRECTORY}/source/locale/$DOCNAME.pot

# We need to extract all strings, so add all supported tags
TAG=""
if [ ${DOCNAME} = "install-guide" ] ; then
    TAG="-t obs -t rdo -t ubuntu -t debian"
fi
if [ ${DOCNAME} = "firstapp" ] ; then
    TAG="-t libcloud -t dotnet -t fog -t pkgcloud -t shade"
fi
sphinx-build -j $NUMBER_OF_CORES -b gettext $TAG ${DIRECTORY}/source/ \
    ${DIRECTORY}/source/locale/

if [[ "$REPOSITORY" = "openstack-manuals" && "$DOCNAME" = "install-guide" ]] ; then
    # save common.pot as common-rst to translate
    mv -f ${DIRECTORY}/source/locale/common.pot \
      ${TOPDIR}common-rst/source/locale/common-rst.pot

    # common-rst is translated as part of openstack-manuals, do not
    # include the file in the combined tree if it exists.
    # rm -f ${DIRECTORY}/source/locale/common.pot
    # Take care of deleting all temporary files so that
    # "git add ${DIRECTORY}/source/locale" will only add the
    # single pot file.
    # Remove UUIDs, those are not necessary and change too often
    msgcat --sort-by-file ${DIRECTORY}/source/locale/*.pot | \
        awk '$0 !~ /^\# [a-z0-9]+$/' > ${DIRECTORY}/source/$DOCNAME.pot
    rm  ${DIRECTORY}/source/locale/*.pot
    rm -rf ${DIRECTORY}/source/locale/.doctrees/
    mv ${DIRECTORY}/source/$DOCNAME.pot ${DIRECTORY}/source/locale/$DOCNAME.pot
fi

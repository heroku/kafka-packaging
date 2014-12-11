#!/bin/bash
#
# Creates an archive suitable for distribution (standard layout for binaries,
# libraries, etc.) from a release archive. Assumes that .

set -e

if [ -z ${VERSION} -o -z ${SCALA_VERSION} -o -z ${DESTDIR} ]; then
    echo "VERSION, SCALA_VERSION, and DESTDIR environment variables must be set."
    exit 1
fi

if [ -z ${PREFIX} ]; then
    PREFIX="/usr/local"
fi

if [ -z ${SYSCONFDIR} ]; then
    SYSCONFDIR="${PREFIX}/etc/kafka"
fi

if [ -z ${INCLUDE_WINDOWS_BIN} ]; then
    INCLUDE_WINDOWS_BIN="yes"
fi

if `echo ${SCALA_VERSION} | grep '^2[.]8[.]' >/dev/null` || `echo ${SCALA_VERSION} | grep '^2[.]9[.]' >/dev/null`; then
    SCALA_VERSION_SHORT=${SCALA_VERSION}
else
    SCALA_VERSION_SHORT=`echo ${SCALA_VERSION} | awk -F. '{print $1"."$2}'`
fi

BINPATH=${PREFIX}/bin
LIBPATH=${PREFIX}/share/kafka

INSTALL="install -D -m 644"
INSTALL_X="install -D -m 755"
TMP_ARCHIVE_PATH="kafka_archive_tmp"

rm -rf ${TMP_ARCHIVE_PATH}
mkdir -p ${TMP_ARCHIVE_PATH}
tar -xf core/build/distributions/kafka_${SCALA_VERSION_SHORT}-${VERSION}.tgz -C ${TMP_ARCHIVE_PATH} --strip-components 1

rm -rf ${DESTDIR}${PREFIX}
mkdir -p ${DESTDIR}${PREFIX}
mkdir -p ${DESTDIR}${BINPATH}
mkdir -p ${DESTDIR}${LIBPATH}
mkdir -p ${DESTDIR}${SYSCONFDIR}

${INSTALL_X} -o root -g root ${TMP_ARCHIVE_PATH}/bin/*.sh ${DESTDIR}${BINPATH}/
if [ "${INCLUDE_WINDOWS_BIN}" == "yes" ]; then
    mkdir -p ${DESTDIR}${BINPATH}/windows
    ${INSTALL_X} -o root -g root ${TMP_ARCHIVE_PATH}/bin/windows/*.bat ${DESTDIR}${BINPATH}/windows/
fi
${INSTALL} -o root -g root ${TMP_ARCHIVE_PATH}/libs/* ${DESTDIR}${LIBPATH}/
for path in ${TMP_ARCHIVE_PATH}/config/*; do
    ${INSTALL} -o root -g root ${path} ${DESTDIR}${SYSCONFDIR}/`basename ${path}`.example
done

ln -s ./kafka_${SCALA_VERSION_SHORT}-${VERSION}.jar ${DESTDIR}${LIBPATH}/kafka.jar # symlink for unversioned access to jar

${INSTALL} -o root -g root ${TMP_ARCHIVE_PATH}/libs/kafka-clients-${VERSION}.jar ${DESTDIR}${LIBPATH}/

rm -rf ${TMP_ARCHIVE_PATH}

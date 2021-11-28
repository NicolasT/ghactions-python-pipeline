# syntax=docker.io/docker/dockerfile:1.3.1

# {{{ Build the source distribution
FROM docker.io/fedora:35 as build-sdist

RUN --mount=type=cache,id=dnf-fedora,target=/var/cache/dnf,sharing=locked \
    dnf install -y \
        python3-build \
        python3-poetry-core \
    && \
    useradd -m -U build

USER build
WORKDIR /home/build

COPY . ghactions-python-pipeline/

# Note: --no-isolation because otherwise poetry-core is installed from PyPI
RUN --network=none \
    python3 -m build --no-isolation --sdist --wheel --outdir dist ghactions-python-pipeline
# }}}

# {{{ Container for the sdist
FROM scratch as artefacts-sdist

COPY --from=build-sdist /home/build/dist/* /
# }}}

# {{{ CentOS build host
FROM docker.io/centos:7.9.2009 as centos7-build

RUN --mount=type=cache,id=yum-centos7,target=/var/cache/yum,sharing=locked \
    yum install -y \
        epel-release \
        rpm-build \
        rpmdevtools \
    && \
    yum makecache --repo epel && \
    useradd -m -U build

USER build
WORKDIR /home/build

RUN --network=none \
    rpmdev-setuptree
# }}}

# {{{ Build SRPM package
FROM centos7-build as build-srpm

COPY ghactions-python-pipeline.spec rpmbuild/SPECS/
COPY artefacts/ghactions-python-pipeline-*.tar.gz rpmbuild/SOURCES/

RUN --network=none \
    rpmbuild -bs rpmbuild/SPECS/artesca-kerberos-auth.spec
# }}}

# {{{ Container for SRPM
FROM scratch as artefacts-srpm

COPY --from=build-srpm /home/build/rpmbuild/SRPMS/* /
# }}}

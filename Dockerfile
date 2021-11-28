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

# {{{ CentOS 8 build host
FROM docker.io/centos:8.4.2105 as centos8-build

RUN --mount=type=cache,id=dnf-centos8,target=/var/cache/dnf,sharing=locked \
    dnf install -y \
        dnf-plugins-core \
        rpm-build \
        rpmdevtools \
    && \
    useradd -m -U build

USER build
WORKDIR /home/build

RUN --network=none \
    rpmdev-setuptree
# }}}

# {{{ Fedora build host
FROM docker.io/fedora:35 as fedora-build

RUN --mount=type=cache,id=dnf-fedora,target=/var/cache/dnf,sharing=locked \
    dnf install -y \
        dnf-plugins-core \
        rpm-build \
        rpmdevtools \
    && \
    useradd -m -U build

USER build
WORKDIR /home/build

RUN --network=none \
    rpmdev-setuptree
# }}}

# {{{ Build SRPM package
FROM centos8-build as build-srpm

COPY ghactions-python-pipeline.spec rpmbuild/SPECS/
COPY artefacts/ghactions-python-pipeline-*.tar.gz rpmbuild/SOURCES/

RUN --network=none \
    rpmbuild -bs rpmbuild/SPECS/ghactions-python-pipeline.spec
# }}}

# {{{ Container for SRPM
FROM scratch as artefacts-srpm

COPY --from=build-srpm /home/build/rpmbuild/SRPMS/* /
# }}}

# {{{ Build the CentOS 8 RPM
FROM centos8-build as build-rpm-centos8

COPY artefacts/ghactions-python-pipeline-*.src.rpm rpmbuild/SRPMS/

USER root
RUN --mount=type=cache,id=dnf-centos8,target=/var/cache/dnf,sharing=locked \
    dnf --setopt="keepcache=1" builddep -y rpmbuild/SRPMS/ghactions-python-pipeline-*.src.rpm

USER build

RUN --network=none \
    rpmbuild --rebuild rpmbuild/SRPMS/ghactions-python-pipeline-*.src.rpm
# }}}

# {{{ Container for the CentOS 8 RPM
FROM scratch as artefacts-centos8-rpm

COPY --from=build-rpm-centos8 /home/build/rpmbuild/RPMS/*/* /
# }}}

# {{{ Build the Fedora RPM
FROM fedora-build as build-rpm-fedora

COPY artefacts/ghactions-python-pipeline-*.src.rpm rpmbuild/SRPMS/

USER root
RUN --mount=type=cache,id=dnf-fedora,target=/var/cache/dnf,sharing=locked \
    dnf --setopt="keepcache=1" builddep -y rpmbuild/SRPMS/ghactions-python-pipeline-*.src.rpm

USER build

RUN --network=none \
    rpmbuild --rebuild rpmbuild/SRPMS/ghactions-python-pipeline-*.src.rpm
# }}}

# {{{ Container for the Fedora RPM
FROM scratch as artefacts-fedora-rpm

COPY --from=build-rpm-fedora /home/build/rpmbuild/RPMS/*/* /
# }}}

# {{{ CentOS 8 E2E container
FROM centos:8.4.2105 as e2e-centos8

COPY artefacts/ghactions-python-pipeline-*.el8.noarch.rpm /tmp

RUN --mount=type=cache,id=dnf-centos8,target=/var/cache/dnf,sharing=locked \
    --mount=type=bind,source=artefacts/,target=/tmp/artefacts \
    dnf --setopt="keepcache=1" install -y /tmp/artefacts/ghactions-python-pipeline-*.el8.noarch.rpm

ENTRYPOINT ["ghactions-python-pipeline"]
# }}}

# {{{ CentOS 8 E2E container
FROM docker.io/fedora:35 as e2e-fedora

RUN --mount=type=cache,id=dnf-fedora,target=/var/cache/dnf,sharing=locked \
    --mount=type=bind,source=artefacts/,target=/tmp/artefacts \
    dnf --setopt="keepcache=1" install -y /tmp/artefacts/ghactions-python-pipeline-*.fc*.noarch.rpm

ENTRYPOINT ["ghactions-python-pipeline"]
# }}}

# {{{ E2E container for sdist packages
FROM docker.io/alpine:3.15.0 as e2e-sdist

RUN apk add --no-cache \
    python3 \
    py3-pip

ARG PACKAGE

RUN --mount=type=bind,source=artefacts/,target=/tmp/artefacts \
    python3 -m pip install /tmp/artefacts/$PACKAGE

ENTRYPOINT ["ghactions-python-pipeline"]
# }}}

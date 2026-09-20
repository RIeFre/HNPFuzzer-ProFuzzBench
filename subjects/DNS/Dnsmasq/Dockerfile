FROM ubuntu:22.04

# Install common dependencies
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -y update && \
    apt-get -y upgrade && \
    apt-get -y install sudo \
    apt-utils \
    build-essential \
    cmake \
    openssl \
    graphviz-dev \
    git \
    autoconf \
    automake \
    libtool \
    pkg-config \
    autoconf-archive \
    libgnutls28-dev \
    libssl-dev \
    liburcu-dev \
    libedit-dev \
    liblmdb-dev \
    libidn2-dev \
    libcap-ng-dev \
    python3-pip \
    python3-setuptools \
    nano \
    net-tools \
    vim \
    gdb \
    netcat-openbsd \
    strace \
    wget \
    ca-certificates \
    libcap-dev

# Install LLVM/Clang 12.
#
# HNPFuzzer is an AFLNet fork and reuses the same LLVM pass, which calls
# IRBuilder::CreateLoad()/CreateGEP() without an explicit element type. Both
# overloads were removed in LLVM 14, so the pass only builds against LLVM 12/13.
RUN apt-get -y install clang-12 llvm-12-dev && \
    update-alternatives --install /usr/bin/clang clang /usr/bin/clang-12 100 && \
    update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-12 100 && \
    update-alternatives --install /usr/bin/llvm-config llvm-config /usr/bin/llvm-config-12 100

# Add a new user ubuntu, pass: ubuntu
RUN (getent group ubuntu > /dev/null || groupadd ubuntu) && \
    (id -u ubuntu > /dev/null 2>&1 || \
     useradd -rm -d /home/ubuntu -s /bin/bash -g ubuntu -G sudo -u 1000 ubuntu -p "$(openssl passwd -1 ubuntu)")

RUN chmod 777 /tmp

# Pin the gcovr release validated by the 2026-09 coverage audit.
RUN pip3 install gcovr==8.6

# Use ubuntu as default username
USER ubuntu
WORKDIR /home/ubuntu

# Import environment variable to pass as parameter to make (e.g., to make parallel builds with -j)
ARG MAKE_OPT

# =============================================================================
# Everything above is byte-identical to profuzzbench-new's ubuntu:22.04 prefix
# so Docker shares these layers with the already-built "new" images. The fuzzer
# differs from here on.
# =============================================================================

# Set up HNPFuzzer (an AFLNet fork carrying sock2shm.so, LD_PRELOAD-ed into the
# target via AFL_PRELOAD in run.sh so afl-fuzz and the target exchange message
# buffers over shared memory instead of a socket).
#
# -fcommon: sock2shm_utils.h declares `msg* session_msg;` at file scope without
# extern -- a tentative definition. GCC 9 merges the per-TU copies; GCC 10+
# defaults to -fno-common and every TU emits a strong definition, so linking
# afl-fuzz fails with "multiple definition of session_msg". -fcommon restores
# the pre-GCC-10 semantics, which is what the code wants: the real definition
# lives in sock2shm.c, which is linked only into sock2shm.so and never into
# afl-fuzz, so afl-fuzz and the LD_PRELOAD-ed .so each own their session_msg
# and rendezvous via shmat(). Marking it `extern` instead makes afl-fuzz fail
# with "undefined reference".
#
# CFLAGS MUST come from the environment: `make CFLAGS=...` overrides rather than
# extends the Makefile's own `CFLAGS +=`, dropping -DBIN_PATH and failing
# afl-gcc.c with "'BIN_PATH' undeclared".
RUN git clone https://github.com/veltavid/HNPFuzzer.git && \
    cd HNPFuzzer && \
    export CFLAGS="-O3 -funroll-loops -fcommon" && \
    make clean all $MAKE_OPT && \
    cd llvm_mode && make $MAKE_OPT

ENV WORKDIR="/home/ubuntu/experiments"
ENV HNPFUZZER="/home/ubuntu/HNPFuzzer"
ENV PATH="${PATH}:${HNPFUZZER}:/home/ubuntu/.local/bin:${WORKDIR}"
ENV AFL_PATH="${HNPFUZZER}"
ENV AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1 \
    AFL_SKIP_CPUFREQ=1 \
    AFL_NO_AFFINITY=1

RUN mkdir -p ${WORKDIR}

# Set up environment variables for ASAN.
# Kept verbatim from profuzzbench-new. NOTE: no target in this repository is
# built with ASAN -- AFL_USE_ASAN=1 and -fsanitize=address from "new" are
# deliberately stripped, which changes crash-detection power vs. new's runs.
ENV ASAN_OPTIONS='abort_on_error=1:symbolize=0:detect_leaks=0:detect_stack_use_after_return=1:detect_container_overflow=0:poison_array_cookie=0:malloc_fill_byte=0:max_malloc_fill_size=16777216'

# =============================================================================
# Target-specific section below.
# =============================================================================

# dnsmasq 2.93 comes from the Debian source mirror: the upstream site
# (thekelleys.org.uk) is unreachable from this build network, and its git
# daemon hangs. The Debian pool carries the identical orig tarball.
COPY --chown=ubuntu:ubuntu dnsmasq.patch ${WORKDIR}/dnsmasq.patch
COPY --chown=ubuntu:ubuntu dnsmasq-reply.patch ${WORKDIR}/dnsmasq-reply.patch

# Download and compile Dnsmasq for fuzzing
RUN cd $WORKDIR && \
    wget -q -O dnsmasq.tar.gz https://mirrors.kernel.org/debian/pool/main/d/dnsmasq/dnsmasq_2.93.orig.tar.gz && \
    tar -xzf dnsmasq.tar.gz && \
    mv dnsmasq-2.93 dnsmasq && \
    cd dnsmasq && \
    patch -p1 < ${WORKDIR}/dnsmasq.patch && \
    patch -p1 < ${WORKDIR}/dnsmasq-reply.patch && \
    CC=afl-clang-fast make $MAKE_OPT

# Download and compile Dnsmasq for coverage analysis
RUN cd $WORKDIR && \
    wget -q -O dnsmasq.tar.gz https://mirrors.kernel.org/debian/pool/main/d/dnsmasq/dnsmasq_2.93.orig.tar.gz && \
    tar -xzf dnsmasq.tar.gz && \
    mv dnsmasq-2.93 dnsmasq-gcov && \
    cd dnsmasq-gcov && \
    patch -p1 < ${WORKDIR}/dnsmasq.patch && \
    patch -p1 < ${WORKDIR}/dnsmasq-reply.patch && \
    make CFLAGS="-fprofile-arcs -ftest-coverage" LDFLAGS="-fprofile-arcs -ftest-coverage" $MAKE_OPT

COPY --chown=ubuntu:ubuntu in-dns ${WORKDIR}/in-dns
COPY --chown=ubuntu:ubuntu dns.dict ${WORKDIR}/dns.dict
COPY --chown=ubuntu:ubuntu cov_script.sh ${WORKDIR}/cov_script
COPY --chown=ubuntu:ubuntu run.sh ${WORKDIR}/run
COPY --chown=ubuntu:ubuntu dnsmasq.conf ${WORKDIR}/dnsmasq.conf

# dnsmasq reads /etc/dnsmasq.conf when started without -C (run.sh relies on it);
# dig for debugging, like the legacy image
USER root
RUN cp ${WORKDIR}/dnsmasq.conf /etc/dnsmasq.conf && \
    apt-get -y update && apt-get -y install dnsutils
USER ubuntu
WORKDIR /home/ubuntu

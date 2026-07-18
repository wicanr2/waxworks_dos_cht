FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq && apt-get install -y -qq \
    build-essential libsdl2-dev libsdl2-net-dev libfreetype6-dev \
    libpng-dev libjpeg-turbo8-dev pkg-config zlib1g-dev nasm \
    libsdl2-2.0-0 libsdl2-net-2.0-0 libfreetype6 libsndio7.0 \
    python3 python3-freetype fonts-noto-cjk \
    xvfb x11-utils imagemagick xdotool dosbox \
    zstd zip unzip curl file && rm -rf /var/lib/apt/lists/*

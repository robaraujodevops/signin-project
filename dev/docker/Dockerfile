FROM node:16-bullseye-slim

RUN apt-get update \
    && apt-get -y install \
        git \
        build-essential \
        python \
        make \
        cmake \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

CMD ["yarn","dev"]  

FROM --platform=$BUILDPLATFORM swift:latest AS smabuilder
WORKDIR /swift
COPY . .
RUN swift build -c release
RUN chmod -R u+rwX,go+rX-w /swift/.build/release/

FROM --platform=$TARGETPLATFORM swift:slim
WORKDIR /sma2mqtt
ENV PATH="$PATH:/sma2mqtt"
COPY --from=smabuilder /swift/.build/release/sma2mqtt .
CMD ["sma2mqtt"]

# create your own docker image:
#
# docker build . --file sma2mqtt.product.dockerfile --tag sma2mqtt
# docker run --name sma2mqtt sma2mqtt


# multiarch build to docker.io:
#
# docker buildx create --use --name multiarch-builder
# docker buildx inspect --bootstrap
# docker buildx build --no-cache --platform linux/amd64,linux/arm64 --tag jollyjinx/sma2mqtt:latest --tag jollyjinx/sma2mqtt:3.1.2 --file sma2mqtt.product.dockerfile --push .
# docker buildx imagetools inspect jollyjinx/sma2mqtt:latest

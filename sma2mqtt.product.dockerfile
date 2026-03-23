# syntax=docker/dockerfile:1.7
FROM swift:6.2 AS sma2mqttbuilder
WORKDIR /swift
ENV SWIFTPM_BUILD_TESTS=false
COPY Package.swift ./
RUN --mount=type=cache,target=/root/.cache \
    --mount=type=cache,target=/root/.swiftpm \
    swift package resolve
COPY Sources ./Sources
COPY Tests ./Tests
RUN --mount=type=cache,target=/root/.cache \
    --mount=type=cache,target=/root/.swiftpm \
    --mount=type=cache,target=/swift/.build \
    swift build -c release --product sma2mqtt \
    && install -Dm755 /swift/.build/release/sma2mqtt /out/sma2mqtt \
    && cp -R /swift/.build/release/sma2mqtt_sma2mqttLibrary.resources /out/sma2mqtt_sma2mqttLibrary.resources

FROM swift:6.2-slim
WORKDIR /sma2mqtt
ENV PATH="$PATH:/sma2mqtt"
COPY --from=sma2mqttbuilder /out/sma2mqtt .
COPY --from=sma2mqttbuilder /out/sma2mqtt_sma2mqttLibrary.resources ./sma2mqtt_sma2mqttLibrary.resources
CMD ["sma2mqtt"]

# create your own docker image:
#
# docker build . --file sma2mqtt.product.dockerfile --tag sma2mqtt
# docker run --name sma2mqtt sma2mqtt
# docker buildx build --no-cache --platform linux/amd64,linux/arm64 --tag jollyjinx/sma2mqtt:development --file sma2mqtt.product.dockerfile --push .


# multiarch build to docker.io:
#
# docker buildx create --use --name multiarch-builder
# docker buildx inspect --bootstrap
# version=development
# docker buildx build --no-cache --platform linux/amd64,linux/arm64 --tag "jollyjinx/sma2mqtt:$version" --file sma2mqtt.product.dockerfile --push .
# docker buildx build --no-cache --platform linux/amd64,linux/arm64 --tag jollyjinx/sma2mqtt:latest --tag jollyjinx/sma2mqtt:development --tag "jollyjinx/sma2mqtt:3.2.0" --file sma2mqtt.product.dockerfile --push .
# docker buildx imagetools inspect jollyjinx/sma2mqtt:latest

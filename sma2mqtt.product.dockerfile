FROM --platform=$BUILDPLATFORM swift:latest AS sma2mqttbuilder
WORKDIR /swift
COPY Package.swift Package.swift
COPY Sources Sources
COPY Tests Tests
RUN swift build -c release
RUN chmod -R u+rwX,go+rX-w /swift/.build/release/

FROM swift:slim
WORKDIR /sma2mqtt
ENV PATH="$PATH:/sma2mqtt"
COPY --from=sma2mqttbuilder /swift/.build/release/sma2mqtt .
COPY --from=sma2mqttbuilder /swift/.build/release/sma2mqtt_sma2mqttLibrary.resources ./sma2mqtt_sma2mqttLibrary.resources
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
# docker buildx build --no-cache --platform linux/amd64,linux/arm64 --tag jollyjinx/sma2mqtt:latest --tag jollyjinx/sma2mqtt:3.1.2 --file sma2mqtt.product.dockerfile --push .
# docker buildx imagetools inspect jollyjinx/sma2mqtt:latest

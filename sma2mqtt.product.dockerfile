FROM swift:latest as builder
WORKDIR /swift
COPY . .
RUN swift build -c release
RUN chmod -R u+rwX,go+rX-w /swift/.build/release/

FROM swift:slim
WORKDIR /sma2mqtt
ENV PATH "$PATH:/sma2mqtt"
RUN chmod -R ugo+rwX /sma2mqtt
COPY --from=builder /swift/.build/release/sma2mqtt .
COPY --from=builder /swift/.build/release/sma2mqtt_sma2mqttLibrary.resources ./sma2mqtt_sma2mqttLibrary.resources
CMD ["sma2mqtt"]

# create your own docker image:
#
# docker build . --file sma2mqtt.product.dockerfile --tag sma2mqtt
# docker run --name sma2mqtt sma2mqtt


# following lines are for publishing on docker hub
#
# docker build . --file sma2mqtt.product.dockerfile --tag jollyjinx/sma2mqtt:latest && docker push jollyjinx/sma2mqtt:latest
# docker build . --file sma2mqtt.product.dockerfile --tag jollyjinx/sma2mqtt:development && docker push jollyjinx/sma2mqtt:development


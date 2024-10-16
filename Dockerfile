FROM golang:1.23.1-alpine as base
WORKDIR /root

RUN apk add git

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Build service in seperate stage.
FROM base as builder
RUN go build


# Test build.
FROM base as testing

RUN apk add build-base

CMD go vet ./... && go test ./...


# Development build.
FROM base as development

RUN ["go", "install", "github.com/githubnemo/CompileDaemon@latest"]
EXPOSE 9012

CMD CompileDaemon -log-prefix=false -build="go build" -command="./openslides-vote-service"

FROM development as development-fullstack

COPY --from=autoupdate / /openslides-autoupdate-service
RUN echo 'replace github.com/OpenSlides/openslides-autoupdate-service => /openslides-autoupdate-service' >> go.mod && \
    go mod tidy

# Productive build
FROM scratch

LABEL org.opencontainers.image.title="OpenSlides Vote Service"
LABEL org.opencontainers.image.description="The OpenSlides Vote Service handles the votes for electronic polls."
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.source="https://github.com/OpenSlides/openslides-vote-service"

COPY --from=builder /root/openslides-vote-service .
EXPOSE 9013

ENTRYPOINT ["/openslides-vote-service"]
HEALTHCHECK CMD ["/openslides-vote-service", "health"]

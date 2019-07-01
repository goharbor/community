#!/bin/bash

docker run --rm -it -v ${PWD}:/documents/ asciidoctor/docker-asciidoctor \
  asciidoctor-pdf -r asciidoctor-diagram scanner_adapters_architecture.adoc -v -o scanner_adapters_architecture.pdf

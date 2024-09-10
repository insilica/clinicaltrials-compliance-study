ARG PG_BASE_IMAGE=postgres:15.6

ARG APT_PKGS_RUN="            \
unzip                         \
"

FROM $PG_BASE_IMAGE AS db
ARG APT_PKGS_RUN

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
	$APT_PKGS_RUN

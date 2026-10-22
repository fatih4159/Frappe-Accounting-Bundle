# Vendored Frappe Docker resources

Source: https://github.com/frappe/frappe_docker
Commit: fcc73cf55d202e68ab58885cdcc61a8616d08b51
Upstream license: MIT, retained in LICENSE.

The root Dockerfile derives from images/custom/Containerfile at this commit.
Changes: resource COPY paths point here; public apps.json is supplied through an
app-manifest build stage and a read-only BuildKit bind mount for automatic cache
invalidation; FFmpeg and the bundle bootstrap script are added to the final image.
Do not place repository credentials in apps.json.

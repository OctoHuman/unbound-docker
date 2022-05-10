# Unbound Docker
The Dockerfile creates a contained instance of Unbound.

The container is automatically rebuilt several times per month to keep it up to date.

## Usage
Pull the image using
```bash
docker pull ghcr.io/OctoHuman/unbound:latest
```

Note that Unbound does not run as root inside of the container, so Unbound can't bind directly to port 53. This shouldn't matter though, as in most cases you will have to export the container's port to the host.

In addition, you'll need to bind your `unbound.conf` into the `/unbound/` directory. For example:
```bash
docker run --mount type=bind,source=/path/to/unbound.conf,target=/unbound/unbound.conf,readonly -p <host port>:<container port>/udp -p <host port>:<container port>/tcp unbound
```
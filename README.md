# docker-gdns

This is a simple Docker container for updating the Google Cloud DNS record dynamically.
Both IPv4 and IPv6 are supported.

## Usage

Run:

Original repository
```bash
sudo docker run -d \
    --name=gdns \
    -v /etc/localtime:/etc/localtime:ro \
    -v /config/dir/path:/config \
    davebv/docker-gdns
```
For authentication, you will need to provide the auth key file from a service account page.
How to Authorizing with a service account (https://cloud.google.com/sdk/docs/authorizing).

If you would like to pass it as a environment variable, include this in your docker run command:
```bash
    -e "GCLOUD_AUTH=$(cat auth.json | openssl enc -base64)"
```

When run for the first time, a file named gdns.conf will be created in the config dir, and the container will exit. Edit this file, adding your domain and token. Then rerun the command.

## IPv4/IPv6
By default only IPV4 is enabled.

Disable IPV4
`IPV4=no`
Enable IPV4
`IPV4=yes`
Disable IPV6
`IPV6=no`
Enable IPV6
`IPV6=yes`


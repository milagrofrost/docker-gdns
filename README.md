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
    milagrofrost/docker-gdns
    -e ZONE='zonename-com'
    -e DOMAIN='site.zonename.com'
    -e IPV4='yes'
    -e GCLOUD_ACCOUNT='exampleaccount@genuine-ether-999999.iam.gserviceaccount.com'
    -e GCLOUD_PROJECT='genuine-ether-99999'
    -e GCLOUD_AUTH_FILE='auth.json'
```
For authentication, you will need to provide the auth key file from a service account page.
How to Authorizing with a service account (https://cloud.google.com/sdk/docs/authorizing).

If you would like to pass it as a environment variable, include this in your docker run command:
```bash
    -e "GCLOUD_AUTH=$(cat auth.json | openssl enc -base64)"
```

Required variables
```
ZONE              (ex. zonename-com) Google DNS Zone resource name
DOMAIN            (ex. site.zonename.com) FQDN of DNS record
IPV4 AND/OR IPV6  (ex. yes) must be set to 'yes' or 'no'
GCLOUD_AUTH_FILE  (ex. auth.json) Gcloud auth key created from a service account or user that has permissions to edit the DNS resource.  Place in /config/folder
GCLOUD_PROJECT    (ex. genuine-ether-99999) The project associated with the auth key file
GCLOUD_ACCOUNT    (ex. exampleaccount@genuine-ether-999999.iam.gserviceaccount.com) The account associated with the auth key file
```

Instead of specifying a GCLOUD_AUTH_FILE you can pass a local file's full contents to a variable, although I've had limited success with this method:
```
GCLOUD_AUTH=$(cat auth.json | openssl enc -base64)
```

When run for the first time, if the ZONE extra_parameter is not defined, a file named gdns.conf will be created in the config dir, and the container will exit. Edit this file, adding your domain and token. Then rerun the command.

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

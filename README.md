# fly-ftp-server

A simple FTP server for [Fly.io](https://fly.io) (based on [alpine-ftp-server](https://hub.docker.com/r/delfer/alpine-ftp-server)) using `vsftpd` _very secure FTP daemon_.

## Customise

Edit the `name` in the `fly.toml` to one of your choice:

```toml
app = "fly-ftp-server"
```

The `[env]` block in the `fly.toml` contains the port range for passive connections:

```toml
[env]
MIN_PORT = 21000
MAX_PORT = 21005
```

If you change them, that `MIN_PORT` and `MAX_PORT` must match up with the ports in the `fly.toml` file's `[services]` section. Unfortunately Fly [does](https://fly.io/docs/reference/configuration/) [not](https://community.fly.io/t/define-port-range-for-service/1938/2?u=greg) currently support providing a port range for TCP. So you need to provide them individually. Which makes providing a large number of ports harder, but possible.

You may also want to adjust the FTP options. Take a look at the `conf/vsftpd.conf` file, adjusting that to your needs. We have generally used default values but made some changes better suited for Fly, such as using IPv6.

## Deploy

**Note:** Say _No_ at the end, since you need to do a couple of things before you can deploy:

```
$ fly launch
An existing fly.toml file was found
? Would you like to copy its configuration to the new app? Yes
Creating app in /path/to/it
Scanning source code
Detected a Dockerfile app
? App Name (leave blank to use an auto-generated name): your-name-here
? Select organization: personal (personal)
? Select region: lhr (London)
Created app your-name-here in organization personal
Wrote config file fly.toml
? Would you like to setup a Postgresql database now? No
? Would you like to deploy now? No
Your app is ready. Deploy with `flyctl deploy`
```

Why _not_ deploy right now?

1. You need to create a volume to store the uploaded files.

2. You need to specify the `USERS` that are permitted to connect to the server.

So let's do that:

## Storage

The provided storage is ephemeral so you will need to create a [volume](https://fly.io/docs/reference/volumes/) in the region you plan on deploying your app in (for example `lhr`). The size is in GB. For example:

```
fly volumes create ftp_data --region lhr --size 1
```

Volumes are by default encrypted. The command should return its details to show it was successful.

## Users

The `USERS` value must be a space-separated list of users. Each user _must_ have a name and password. And can _optionally_ have a home folder. And _optionally_ a UID. We'll mount the volume above to the `/data` folder. So for example you _could_ run this which would create a user called **example**, with a password of **example**:

```
fly secrets set USERS="example|example|/data/example"
```

... but of course your command should use a better name and a more secure password. Each user should be separated by a space. Some examples of the structure:

#USERS="user|password foo|bar|/home/foo"
#USERS="user|password|/home/user/dir|10000"
#USERS="user|password||10000"
```

You should then see:

```
Secrets are staged for the first deployment
```

Now you can go ahead and deploy the app:

```
fly deploy
```

You should see it build, push the image, then create the release:

```
==> Monitoring deployment
 1 desired, 1 placed, 1 healthy, 0 unhealthy
--> v7 deployed successfully
```

Conform the app is running with `fly status`. Now try connecting to it using your FTP client. Initially you can use `your-app-name.fly.dev` as the hostname, the port 21, and a username and password from your `USERS` value. You will need to use plain FTP and so there may be a warning about security.

## Debugging

Use `fly logs` to see what is output.

Assuming your app successfully deployed, try running `fly ssh console` to connect to a vm. Once there you can check `vsftpd` is running e.g:

```
ps -a | grep vsftpd
523 root      0:00 /sbin/tini -- /bin/start_vsftpd.sh
528 root      0:00 pidproxy /var/run/vsftpd/vsftpd.pid true
550 root      0:00 vsftpd -opasv_min_port=21000 -opasv_max_port=21005 /etc/vsftpd/vsftpd.conf
722 root      0:00 grep vsftpd
```

You can also check files are uploaded by users into the `/data` folder. Run `cd data` and you should see the folders for your users there e.g `/data/example`. Check the folder's owner matches the one you set in your `USERS` secret. If not, that would explain if a particular user can't connect.


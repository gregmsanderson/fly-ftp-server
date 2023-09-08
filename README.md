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

The `[env]` block also has an `ADDRESS` value. Run `fly info` to get _your_ app's IPv4:
```toml
ADDRESS = '1.2.3.4'
```

You may also want to adjust the FTP options. Take a look at the `conf/vsftpd.conf` file, adjusting that to your needs. We have generally used default values.

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

... but of course your command should use a better name and a more secure password. Each user should be separated by a space. For example these examples create _two_ users:

```
USERS="username|password|/data/username foo|bar|/data/foo"
USERS="username|password|/data/username|5000 foo|bar|/data/foo|5001"
```

Run that and you should then see:

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
--> v1 deployed successfully
```

Conform the app is running with `fly status`. Now try connecting to it using your FTP client. Use `your-app-name.fly.dev` as the hostname, 21 as the port, and one of the username/password from your secret `USERS` value. You will need to use plain FTP and so there _may_ be a warning about security.

## Debugging

Use `fly logs` to see what is output and look for any errors. If you have left our default TCP healthcheck in the `fly.toml`, you should see _its_ connections roughly every five seconds:

```
2022-06-08T16:02:09Z app[abcdefg] lhr [info]Wed Jun  8 16:02:09 2022 [pid 2] CONNECT: Client "1.2.3.4"
2022-06-08T16:02:14Z app[abcdefg] lhr [info]Wed Jun  8 16:02:14 2022 [pid 2] CONNECT: Client "1.2.3.4"
```

Try running `fly ssh console` to connect to a vm. Once there you can check `vsftpd` is running e.g:

```
ps -a | grep vsftpd
528 root      0:00 pidproxy /var/run/vsftpd/vsftpd.pid true
550 root      0:00 vsftpd -opasv_min_port=21000 -opasv_max_port=21005 /etc/vsftpd/vsftpd.conf
722 root      0:00 grep vsftpd
```

From there you can also check files uploaded by users (into the `/data` folder). Run `cd data` and you should see the folders for your users e.g `/data/username`. Check the folder's owner matches the one _you_ set in your `USERS` secret. If not, that would explain if a particular user can't connect. And look inside the folder to see the files are present and valid.

This basic FTP server does not use FTPS. In _theory_ you should be able to modify it to use Fly's provided TLS handler or provide your own certificate.


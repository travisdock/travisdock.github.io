---
layout: post
title: "Setting up an Ubuntu 22.04 server for a Rails 7 app"
draft: true
---

### Table of Contents

* TOC
{:toc}

### Update before anything else
```
apt update
apt upgrade
reboot
```

Just keep hitting 'y' or enter to accept defaults as it prompts you.

After reboot you may have to wait a minute or two before it will allow you ssh back in.

### Add deploy user and set up ssh
```
adduser deploy
adduser deploy sudo
mkdir /home/deploy/.ssh
chmod 700 /home/deploy/.ssh
cp /root/.ssh/authorized_keys /home/deploy/.ssh/authorized_keys
chmod 600 /home/deploy/.ssh/authorized_keys
chown -R deploy:deploy /home/deploy/.ssh
```

Now log out and log back in as your new user

### Install Nginx
```
sudo apt update
sudo apt install nginx
sudo ufw allow 'Nginx HTTP'
service nginx status
```
If nginx is active you should be able to visit the ip address of your server in the browser now and see the nginx default welcome page.

> DO NOT FORGET TO ALLOW SSH IN UFW OR YOU WILL GET LOCKED OUT OF YOUR SHIT


### Configure Nginx proxy
> https://www.digitalocean.com/community/tutorials/how-to-configure-nginx-as-a-reverse-proxy-on-ubuntu-22-04

Create a site configuration file for nginx

```
sudo vim /etc/nginx/sites-available/your_domain
```

Add the following configuration to the file: (hint: use `:set paste` first in vim before you paste)

```
server {
    listen 80;
    listen [::]:80;

    server_name your_domain www.your_domain;
        
    location / {
        proxy_pass http://127.0.0.1:3000;
        include proxy_params;
    }
}
```

Link that file to the sites-enabled folder to make the configuration live:

```
sudo ln -s /etc/nginx/sites-available/your_domain /etc/nginx/sites-enabled/
```

Make sure your configuration file is valid:

```
sudo nginx -t
```

Then restart nginx to enable the new configuration:

```
sudo systemctl restart nginx
```

We will test this later once we get our rails up running on port 3000

### Install Postgres
>https://www.digitalocean.com/community/tutorials/how-to-install-postgresql-on-ubuntu-22-04-quickstart

```
sudo apt update
sudo apt install postgresql postgresql-contrib
```

> ### Postgres User Note
> Postgres by default uses "peer" authentication for all local connections from the Unix domain socket (that is what we use when we run `psql`). From the postges docs:
> > The peer authentication method works by obtaining the client's operating system user name from the kernel and using it as the allowed database user name (with optional user name mapping). This method is only supported on local connections.
>
> For us, this means that if you create a new postgres user that does not coincide with a linux user on our server then we will never be able to start a postgres session as them via the command line. So if we ever need to do postgres stuff via the command line we will need to create a linux user to do that.

Create a user:

```
sudo -u postgres createuser --interactive --pwprompt
```

The script will prompt you with the following:

```
Enter name of role to add: youruser
Enter password for new role:
Enter it again:
Shall the new role be a superuser? (y/n) y
```


### Install Docker
> https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-22-04

```
sudo apt install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
apt-cache policy docker-ce
sudo apt install docker-ce
service docker status
```

In order to be able to run docker without sudo:

```
sudo usermod -aG docker ${USER}
```

Then log out and log back into the server for the change to take effect. Run `docker ps` to make sure it worked.

### Log in and pull your production Docker image
I stored my image on Github Container Registry so I had to log in there:

```
export TOKEN=github_token
echo $TOKEN | docker login ghcr.io -u USERNAME --password-stdin
docker pull ghcr.io/bla/bla/bla
```
### Setting up production Rails app

> Because we are using a proxy server we need to set the `config.public_file_server.enabled = true` in the `config/environments/production.rb` file. This is false by default because nginx and apache normally do this for us but because we are only using them as a proxy that isn't happening and none of your precompiled assets will be available.

Create a file called `production.env` to store your production credentials. I found this easier than using rails credentials although perhaps less secure.

```
DB_PASSWORD=abc123
SECRET_KEY_BASE=asdf
```

Run your container with bash to set up some configs before running your server:

```
docker run --network=host --env-file ./production.env image_name
```

Or create a `docker-compose.yml` file:

```
services:
  app:
    image: docker pull image:latest
    network_mode: "host"
    environment:
      - DB_PASSWORD=abc123
      - SECRET_KEY_BASE=asdf
    restart: always
    name: app_production
```

### Install Cerbot for Nginx
> https://www.digitalocean.com/community/tutorials/how-to-secure-nginx-with-let-s-encrypt-on-ubuntu-22-04
>
> https://www.vultr.com/docs/setup-letsencrypt-on-linux/

Use snap to install

```
sudo snap install core; sudo snap refresh core
```

Remove any old version

```
sudo apt remove certbot
```

Install your fresh copy

```
sudo snap install --classic certbot
```

Link certbot command

```
sudo ln -s /snap/bin/certbot /usr/bin/certbot
```

Check ufw status

```
sudo ufw status
```

Allow full instead of just HTTP

```
sudo ufw allow 'Nginx Full'
sudo ufw delete allow 'Nginx HTTP'
```

Check the status again to make sure it is correct

Obtain SSL Certificate

```
sudo certbot --nginx -d example.com -d www.example.com
```

### Backup Postgres
> https://www.linode.com/docs/guides/back-up-a-postgresql-database/

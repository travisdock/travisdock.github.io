---
layout: post
title: "How I set up an Ubuntu 22.04 server for a Rails 7 app with Nginx, Postgres, and Docker"
---

### Table of Contents

* TOC
{:toc}

### Update before anything else

Download new package information

```
apt update
```

Upgrade installed packages using new information.  Just keep hitting 'y' or enter to accept defaults as it prompts you.

```
apt upgrade
```

Restart the server in order for some upgrades to take effect

```
reboot
```

After reboot you may have to wait a minute or two before it will allow you ssh back in.

### Add deploy user and set up ssh
> [https://www.digitalocean.com/community/tutorials/initial-server-setup-with-ubuntu-22-04](https://www.digitalocean.com/community/tutorials/initial-server-setup-with-ubuntu-22-04){:target="_blank"}

Create your user. I used the name `deploy` but you can use what you wish.

```
adduser deploy
```
Add this new user to the sudo group so that they can run privileged commands.

```
adduser deploy sudo
```
Copy the authorized keys from root to your new user and give them the proper permissions.

```
rsync --archive --chown=deploy:deploy ~/.ssh /home/deploy
```

Now log out of root and log back in as your new user.

### Install and Configure Nginx
> [https://www.digitalocean.com/community/tutorials/how-to-configure-nginx-as-a-reverse-proxy-on-ubuntu-22-04](https://www.digitalocean.com/community/tutorials/how-to-configure-nginx-as-a-reverse-proxy-on-ubuntu-22-04){:target="_blank"}

Make sure apt can fetch the correct packages

```
sudo apt update
```

Install nginx

```
sudo apt install nginx
```

If nginx is active you should be able to visit the ip address of your server in the browser now and see the nginx default welcome page.


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

Check status to make sure it is working

```
service nginx status
```

We will test this later once we get our rails up running on port 3000

### Enable UFW (Uncomplicated Fire Wall)

Allow ssh so that you can get back into your instance when you need to

```
sudo ufw allow ssh
```

Allow all full https and http requests

```
sudo ufw allow 'Nginx Full'
```

Turn ufw on

```
sudo ufw enable
```

Check status to make sure it is working

```
sudo ufw status
```

You should see:

```
Status: active

To                         Action      From
--                         ------      ----
Nginx Full                 ALLOW       Anywhere                  
22/tcp                     ALLOW       Anywhere                  
Nginx Full (v6)            ALLOW       Anywhere (v6)             
22/tcp (v6)                ALLOW       Anywhere (v6)
```

### Install Postgres
>[https://www.digitalocean.com/community/tutorials/how-to-install-postgresql-on-ubuntu-22-04-quickstart](https://www.digitalocean.com/community/tutorials/how-to-install-postgresql-on-ubuntu-22-04-quickstart){:target="_blank"}

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
> [https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-22-04](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-22-04){:target="_blank"}

Install the necessary packages

```
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
```

Add docker gpg

```
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

Update apt so it can now download docker, then install

```
sudo apt update
apt-cache policy docker-ce
sudo apt install -y docker-ce
```

Check that it is working

```
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
export TOKEN=<github_token>
```

```
echo $TOKEN | docker login ghcr.io -u <github_username> --password-stdin
```

```
docker pull ghcr.io/bla/bla/bla:latest
```
### Setting up production Rails app

> Because we are using a proxy server we need to set the `config.public_file_server.enabled = true` in the `config/environments/production.rb` file. This is false by default because nginx and apache normally do this for us but because we are only using them as a proxy that isn't happening and none of your precompiled assets will be available.

Create a `docker-compose.yml` file with instructions for docker to start the container and important credentials to add to the env. I found this easier than using rails credentials although perhaps less secure.

```
services:
  app:
    image: ghcr.io/bla/bla/bla:latest
    network_mode: "host"
    environment:
      - DB_PASSWORD="abc123"
      - SECRET_KEY_BASE=asdf
    restart: always
    container_name: app_production
```

You can create a secret by first running your docker container

```
docker run -it <image_id> bash
```

And once inside, running the following command:

```
bin/rake secret
```

Now you may run your application using `docker compose up -d` and visit your ip address to see if it is working.

### Install Cerbot for Nginx
> [https://www.digitalocean.com/community/tutorials/how-to-secure-nginx-with-let-s-encrypt-on-ubuntu-22-04](https://www.digitalocean.com/community/tutorials/how-to-secure-nginx-with-let-s-encrypt-on-ubuntu-22-04){:target="_blank"}
>
> [https://www.vultr.com/docs/setup-letsencrypt-on-linux/](https://www.vultr.com/docs/setup-letsencrypt-on-linux/){:target="_blank"}

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

Obtain SSL Certificate

```
sudo certbot --nginx -d example.com -d www.example.com
```

### Backup Postgres
> [https://www.linode.com/docs/guides/back-up-a-postgresql-database/](https://www.linode.com/docs/guides/back-up-a-postgresql-database/){:target="_blank"}
> 
> [https://www.postgresql.org/docs/current/libpq-pgpass.html](https://www.postgresql.org/docs/current/libpq-pgpass.html){:target="_blank"}

I decided to back up my postgres db nightly at first to make sure it is working and then less often as I gain confidence

Add the following to your crontab via `crontab -e`. This will backup nightly and write logs in case there are errors.

```
0 0 * * 0 pg_dump -U postgres dbname > ~/backups/dbname.bak 2>> ~/logs/dbname.bak.log
```

Then you can add a password for the user in their home directory called `.pgpass`

```
hostname:port:database:username:password
```
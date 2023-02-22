---
layout: post
title: "How I copied my production rails database to development for debugging using pgAdmin 4 and Docker"
---

### Table of Contents

* TOC
{:toc}

### Connect to Production Database with pgAdmin 4

These were the only pages I edited in pgAdmin. I used an ssh tunnel so the connection was localhost. My user did not have a password (bad for production? lol). Swap out postgres for your user and your db name in the Maintenance database field.

![connection-image](/assets/pics/pgAdmin_connection.png){: width="400" .centered }

![ssh-image](/assets/pics/pgAdmin_ssh.png){: width="400" .centered }

### Backup the Database

- Right click on your database and choose backup.
- Add a filename on the **General** tab. Save it somewhere you can find it from the command line.
- Tab: **Data/Objects**
  - Section: **Type of Objects**
    - Only data
    - uncheck 'Blobs'
  - Section: **Do not save**
    - Owner
    - Privilege
- Tab: **Options**
  - Use Column Inserts

![ssh-image](/assets/pics/pgAdmin_data_objects.png){: width="400" .centered }
![ssh-image](/assets/pics/pgAdmin_options.png){: width="400" .centered }


### Restore the database

I didn't care about the data in my database so in order to prepare I did

```
rails db:drop db:create db:migrate
```

Then I ran

```
docker exec -i <db_container_name> pg_restore -U <postgres_user> -v -d <database_name> < /path/to/dump/file.sql
```

Migration commands failed because I had already run the migrations. That was ok.

And *voila*. Database copied.

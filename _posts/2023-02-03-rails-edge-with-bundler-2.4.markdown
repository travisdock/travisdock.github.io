---
layout: post
title: "Creating a new Rails edge application using Docker and Bundler 2.4"
categories: docker rails bundler
---

There is a feature in the newest version of Bundler (2.4) that speeds up installation of gems with git sources. In previous versions it would clone the full repository and with a big repo like Rails it could take a while (~30 seconds).  Now it is much faster and we can start a new application from the as-yet-unreleased version of rails by using the rails repo as our gem source in less than a minute.

Here's how:

Jump into a docker ruby environment

```
docker run -it ruby:latest bash
```

Update bundler to the latest version (2.4 at the time of this writing)

```
gem update bundler
```

Add rubygems source and the rails gem straight from Github to a Gemfile

```
echo "source 'https://rubygems.org'" >> Gemfile
echo "gem 'rails', github: 'rails/rails'" >> Gemfile
```

Run bundler

```
bundler install
```

Start a new rails app using the version we just installed using bundler.

```
bundle exec rails new testing --dev
```

You can read more about [Bundler 2.4][bundler-release]

[bundler-release]: https://bundler.io/blog/2023/01/31/bundler-v2-4.html

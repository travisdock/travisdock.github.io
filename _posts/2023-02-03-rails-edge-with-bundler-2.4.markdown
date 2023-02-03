---
layout: post
title: "Creating a new Rails edge application using Docker and bundler 2.4"
categories: docker rails bundler
---

There is a feature in the newest version of Bundler (2.4) that speeds up installation of gems with git sources. In previous versions it would clone the full repository and with a big repo like Rails it could take a while (~30 seconds).  Now it is much faster and we can start a new application from the as-yet-unreleased version of rails by using the rails repo as our gem source in less than a minute.

Here's how:
{% highlight bash %}
docker run -it ruby:latest bash
gem update bundler
echo "source 'https://rubygems.org'" >> Gemfile
echo "gem 'rails', github: 'rails/rails'" >> Gemfile
bundler install
bundle exec rails new testing --dev
{% endhighlight %}

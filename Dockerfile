FROM jekyll/jekyll:latest

WORKDIR /site

COPY Gemfile* ./
RUN bundle install --jobs 8

EXPOSE 4000


CMD [ "bundle", "exec", "jekyll", "serve", "--force_polling", "-H", "0.0.0.0", "-P", "4000" ]

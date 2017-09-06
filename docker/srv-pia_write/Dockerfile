FROM ruby:2.2-alpine
MAINTAINER "Christoph Fabianek" christoph@ownyourdata.eu

RUN gem install 'httparty' 'activesupport' \
	&& mkdir -p /srv-pia_write

COPY script/run.sh /bin/run.sh
COPY script/write.rb /srv-pia_write/write.rb

CMD ["/bin/run.sh"]
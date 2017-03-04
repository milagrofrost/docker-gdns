FROM phusion/baseimage:0.9.19

MAINTAINER David Becerril <david@davebv.com>

# Add gcloud engine
RUN echo "deb https://packages.cloud.google.com/apt cloud-sdk-$(lsb_release -c -s) main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

RUN apt-get -qq update
RUN apt-get -qq install -y google-cloud-sdk iproute2 dnsutils

VOLUME ["/config"]

# Add dynamic dns script
ADD update.sh /root/gdns/update.sh
RUN chmod +x /root/gdns/update.sh

# Create template config file
ADD gdns.conf /root/gdns/gdns.conf

# Run update.sh immediately when the container starts, and start cron for subsequent runs
CMD /root/gdns/update.sh

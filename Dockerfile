FROM debian:stable-slim

MAINTAINER Suriya Soutmun <suriya@odd.works>

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qqy \
  && apt-get -qqy install \
       wget curl \
       ca-certificates apt-transport-https \
       ttf-wqy-zenhei \
       fonts-thai-tlwg-ttf \
       sudo \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

#==================
# Google-Chrome
#==================

ARG CHROME_VERSION="google-chrome-beta"
# Install Key
RUN wget -q -O linux.pub https://dl-ssl.google.com/linux/linux_signing_key.pub && apt-key add linux.pub  && rm -f linux.pub
RUN echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list \
  && apt-get update -qqy \
  && apt-get -qqy install \
    ${CHROME_VERSION:-google-chrome-stable}
RUN rm /etc/apt/sources.list.d/google-chrome.list \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

#======================
# add user headless
#======================

RUN useradd headless --shell /bin/bash --create-home \
  && usermod -a -G sudo headless \
  && echo 'ALL ALL = (ALL) NOPASSWD: ALL' >> /etc/sudoers \
  && echo 'headless:nopassword' | chpasswd

#==============
# open jdk 8
#==============

RUN mkdir -p /usr/share/man/man1 \
  && echo "deb http://http.debian.net/debian jessie-backports main" >> /etc/apt/sources.list.d/jessie-backports.list \
  && apt-get update -qqy \
  && apt-get -qqy --no-install-recommends install \
    -t jessie-backports openjdk-8-jre-headless \
    unzip \
    wget \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/*


#==========
# Selenium
#==========
RUN  mkdir -p /opt/selenium \
  && wget --no-verbose https://selenium-release.storage.googleapis.com/3.4/selenium-server-standalone-3.4.0.jar \
    -O /opt/selenium/selenium-server-standalone.jar


#==================
# Chrome webdriver
#==================
ARG CHROME_DRIVER_VERSION=2.30
RUN wget --no-verbose -O /tmp/chromedriver_linux64.zip https://chromedriver.storage.googleapis.com/$CHROME_DRIVER_VERSION/chromedriver_linux64.zip \
  && rm -rf /opt/selenium/chromedriver \
  && unzip /tmp/chromedriver_linux64.zip -d /opt/selenium \
  && rm /tmp/chromedriver_linux64.zip \
  && mv /opt/selenium/chromedriver /opt/selenium/chromedriver-$CHROME_DRIVER_VERSION \
  && chmod 755 /opt/selenium/chromedriver-$CHROME_DRIVER_VERSION \
  && ln -fs /opt/selenium/chromedriver-$CHROME_DRIVER_VERSION /usr/bin/chromedriver

#========================
# Selenium Configuration
#========================
# As integer, maps to "maxInstances"
ENV NODE_MAX_INSTANCES 5
# As integer, maps to "maxSession"
ENV NODE_MAX_SESSION 5
# In milliseconds, maps to "registerCycle"
ENV NODE_REGISTER_CYCLE 5000
# In milliseconds, maps to "nodePolling"
ENV NODE_POLLING 5000
# In milliseconds, maps to "unregisterIfStillDownAfter"
ENV NODE_UNREGISTER_IF_STILL_DOWN_AFTER 60000
# As integer, maps to "downPollingLimit"
ENV NODE_DOWN_POLLING_LIMIT 2
# As string, maps to "applicationName"
ENV NODE_APPLICATION_NAME "drs_robot"

COPY generate_config /opt/selenium/generate_config
RUN chmod +x /opt/selenium/generate_config
RUN /opt/selenium/generate_config > /opt/selenium/config.json

#=================================
# Chrome Launch Script Modication
#=================================
COPY chrome_launcher.sh /opt/google/chrome/google-chrome

RUN chown -R headless:headless /opt/selenium

USER headless
# Following line fixes
# https://github.com/SeleniumHQ/docker-selenium/issues/87
ENV DBUS_SESSION_BUS_ADDRESS=/dev/null

ENTRYPOINT ["java", "-jar", "/opt/selenium/selenium-server-standalone.jar"]

EXPOSE 4444

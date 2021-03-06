# Download base image ubuntu 18.04 LTS
FROM ubuntu:18.04
LABEL MAINTAINER Dinesh Shetty <dinezh.shetty@gmail.com>

# To handle automatic installations
ENV DEBIAN_FRONTEND=noninteractive

# Setup variables
ENV VNCPASSWORD "Dinesh@123!"
ENV SSHPASS "Dinesh@123!"

# Software Versions
ENV ANDROID_SDK_VERSION "4333796"
ENV ANDROID_BUILD_TOOLS_VERSION "28.0.3"
ENV DROZER_VERSION "2.4.4"
ENV APKTOOL_VERSION 2.4.0"
ENV SIMPLIFY_VERSION "1.2.1"


# Update Ubuntu Software repository
RUN apt-get update

# Install Java
RUN apt-get install -y software-properties-common
RUN add-apt-repository ppa:webupd8team/java -y
#RUN apt-get install -y debconf-utils
RUN echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | debconf-set-selections
RUN echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 seen true" | debconf-set-selections
RUN apt-get install -y oracle-java8-installer
ENV JAVA_HOME /usr/lib/jvm/java-8-oracle


# Install network tools for ipconfig
RUN apt-get install -y net-tools

# Installing some required softwares
RUN apt-get install -y unzip wget tar firefox curl python-setuptools python-pip build-essential

# Install and configure supervisor
RUN apt-get install -y supervisor
RUN mkdir -p /var/log/supervisor

RUN echo "[supervisord]" > /etc/supervisor/conf.d/supervisord.conf
RUN echo "nodaemon=true" >> /etc/supervisor/conf.d/supervisord.conf
RUN echo "" >> /etc/supervisor/conf.d/supervisord.conf

#setup SSH for supervisor
EXPOSE 22
RUN apt-get install -y openssh-server
RUN apt-get install -y ssh
RUN mkdir /var/run/sshd

RUN echo "root:$SSHPASS" | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
RUN echo "X11UseLocalhost no" >> /etc/ssh/sshd_config
RUN echo "X11Forwarding yes" >> /etc/ssh/sshd_config

RUN echo "[program:sshd]" >> /etc/supervisor/conf.d/supervisord.conf
RUN echo "command=/usr/sbin/sshd -D" >> /etc/supervisor/conf.d/supervisord.conf
RUN echo "" >> /etc/supervisor/conf.d/supervisord.conf

# Setup VNC for supervisor
EXPOSE 5901
RUN mkdir -p /root/.vnc
RUN apt-get install -y x11vnc
RUN apt-get install -y xfce4 
RUN apt-get install -y xvfb 
RUN apt-get install -y xfce4-terminal
RUN apt-get install -y vnc4server
RUN x11vnc -storepasswd $VNCPASSWORD /root/.vnc/passwd
RUN chmod 600 /root/.vnc/passwd

RUN echo '#!/bin/bash' >> /root/.vnc/newvnclauncher.sh
RUN echo "/usr/bin/vncserver :1 -name vnc -geometry 800x640" >> /root/.vnc/newvnclauncher.sh
RUN chmod +x /root/.vnc/newvnclauncher.sh

RUN echo "[program:vncserver]" >> /etc/supervisor/conf.d/supervisord.conf
RUN echo "command=/bin/bash /root/.vnc/newvnclauncher.sh" >> /etc/supervisor/conf.d/supervisord.conf
RUN echo "" >> /etc/supervisor/conf.d/supervisord.conf

# Create a folder to store all the tools in
RUN mkdir -p /tools


# Install and Setup Android SDK

# Handle "Warning: File /root/.android/repositories.cfg could not be loaded" error
RUN mkdir -p /root/.android/
RUN touch /root/.android/repositories.cfg


#Downloading SDK https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip

RUN wget -qO /tools/sdk-tools.zip https://dl.google.com/android/repository/sdk-tools-linux-$ANDROID_SDK_VERSION.zip
RUN unzip -q /tools/sdk-tools.zip -d /tools/android-sdk-linux
RUN mv /tools/android-sdk-linux /tools/android-sdk
RUN chown -R root:root /tools/android-sdk/
RUN rm -f /tools/sdk-tools.zip

# Setup Android Environment variables
ENV ANDROID_HOME /tools/android-sdk
ENV ANDROID_ROOT /tools/android-sdk
ENV PATH $PATH:$ANDROID_HOME/tools
ENV PATH $PATH:$ANDROID_HOME/platform-tools


# Update the Android SDK
RUN /tools/android-sdk/tools/bin/sdkmanager --update

# Installing additional ADB dependencies
RUN apt-get install -y lib32z1 


# Install required Android tools (you can choose more from sdkmanager --list)
# Include echo 'y' | to accept license
RUN apt-get install -y qemu-kvm libvirt-bin ubuntu-vm-builder bridge-utils
RUN yes | /tools/android-sdk/tools/bin/sdkmanager --licenses
RUN echo 'y' | /tools/android-sdk/tools/bin/sdkmanager "build-tools;$ANDROID_BUILD_TOOLS_VERSION"
RUN echo 'y' | /tools/android-sdk/tools/bin/sdkmanager "emulator" "platform-tools" "tools" 

# Enable only if required
# RUN /tools/android-sdk/tools/bin/sdkmanager "ndk-bundle" "extras;google;google_play_services" \
# "extras;android;m2repository" "extras;google;m2repository"

# Setup SDK for running Android API 28 x86. Disabled for time being.
#RUN echo 'y' | /tools/android-sdk/tools/bin/sdkmanager "platforms;android-28" "sources;android-28" \
#	"system-images;android-28;google_apis;x86"

# Enable only if required
# RUN echo 'y' | /tools/android-sdk/tools/bin/sdkmanager "system-images;android-28;google_apis;x86_64"

# Creating a new x86 AVD. Disabled for time being.
#RUN echo "no" | /tools/android-sdk/tools/bin/avdmanager create avd -n "Android-API29-x86" --abi google_apis/x86 --package 'system-images;android-28;google_apis;x86' --device "Nexus 5X" --force

# Launch the newly created AVD
#RUN /tools/android-sdk/emulator/emulator -avd "Android-API29-x86" -noaudio -no-boot-anim -gpu off

# Setup and use ARM based device
RUN /tools/android-sdk/tools/bin/sdkmanager "system-images;android-24;default;armeabi-v7a"
RUN /tools/android-sdk/tools/bin/sdkmanager "platform-tools" "platforms;android-24" "emulator"
RUN /tools/android-sdk/tools/bin/sdkmanager "system-images;android-24;default;armeabi-v7a"
RUN echo "no" | /tools/android-sdk/tools/bin/avdmanager create avd -n armTestDevice1 -k "system-images;android-24;default;armeabi-v7a"
# /tools/android-sdk/emulator/emulator -avd armTestDevice1 -noaudio -memory 2048 -no-boot-anim -gpu off

ENV QT_XKB_CONFIG_ROOT /usr/share/X11/xkb
ENV PATH $PATH:$QT_XKB_CONFIG_ROOT


EXPOSE 5554
EXPOSE 5555
EXPOSE 5037

# Setup Drozer
RUN mkdir /tools/drozer
RUN wget -c https://github.com/mwrlabs/drozer/releases/download/$DROZER_VERSION/drozer_$DROZER_VERSION.deb -O /tools/drozer/drozer_$DROZER_VERSION.deb
RUN apt-get install -y /tools/drozer/drozer_$DROZER_VERSION.deb
EXPOSE 31415
RUN echo 'adb forward tcp:31415 tcp:31415'

# Setup Apktool
RUN mkdir /tools/apktool
RUN wget -qO -c https://bitbucket.org/iBotPeaches/apktool/downloads/apktool_$APKTOOL_VERSION.jar -O /tools/apktool/apktool.jar
RUN chmod +x /tools/apktool/apktool.jar
RUN wget -qO -c https://raw.githubusercontent.com/iBotPeaches/Apktool/master/scripts/linux/apktool -O /tools/apktool/apktool
RUN chmod +x /tools/apktool/apktool
ENV PATH $PATH:/tools/apktool/apktool

# Setup APKiD
RUN mkdir /tools/apkid
RUN git clone --recursive https://github.com/rednaga/yara-python-1 /tools/apkid/yara-python
RUN cd /tools/apkid/yara-python && python setup.py build --enable-dex install
RUN pip install apkid


# Setup Simplify
RUN mkdir /tools/simplify
RUN wget -qO -c https://github.com/CalebFenton/simplify/releases/download/v$SIMPLIFY_VERSION/simplify-$SIMPLIFY_VERSION.jar -O /tools/simplify/simplify.jar
RUN wget -qO -c https://github.com/CalebFenton/simplify/blob/master/simplify/obfuscated-app.apk?raw=true -O /tools/simplify/obfuscated-app.apk

# Setup Kwetza
RUN pip install beautifulsoup4
RUN git clone https://github.com/sensepost/kwetza.git /tools/kwetza



# Setup workdirectory
RUN mkdir -p /workdirectory
WORKDIR /workdirectory

CMD [ "/usr/bin/supervisord", "-c",  "/etc/supervisor/conf.d/supervisord.conf" ]

# Additional Clean-up
RUN rm -rf /var/lib/apt/lists/*
RUN apt-get clean
RUN apt-get autoremove
RUN apt-get autoclean

# Setup envt variables
RUN echo "export PATH=$PATH" >> /etc/profile
#RUN source /etc/profile
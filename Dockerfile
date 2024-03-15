FROM clux/muslrust:stable
# docker build -t didkit:latest --build-arg known_hosts="$(cat ~/.ssh/known_hosts)" --build-arg ssh_prv_key="$(cat ~/.ssh/github)" --build-arg ssh_pub_key="$(cat ~/.ssh/github.pub)" --squash .
# docker build -t didkit:latest .

ENV DEBIAN_FRONTEND="noninteractive"
ENV JAVA_VERSION="17"
ENV ANDROID_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-7583922_latest.zip"
ENV ANDROID_VERSION="29"
ENV ANDROID_BUILD_TOOLS_VERSION="29.0.3"
ENV ANDROID_ARCHITECTURE="x86_64"
ENV ANDROID_SDK_ROOT="/usr/local/android-sdk"
ENV FLUTTER_CHANNEL="stable"
ENV FLUTTER_VERSION="3.19.3"
ENV GRADLE_VERSION="7.2"
ENV GRADLE_USER_HOME="/opt/gradle"
ENV GRADLE_URL="https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip"
ENV FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/$FLUTTER_CHANNEL/linux/flutter_linux_$FLUTTER_VERSION-$FLUTTER_CHANNEL.tar.xz"
ENV FLUTTER_ROOT="/opt/flutter"
ENV PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/platforms:$FLUTTER_ROOT/bin:$GRADLE_USER_HOME/bin:$PATH"

COPY ssh /root/.ssh
COPY altme_files /volume/altme_files
# Install the necessary dependencies.
RUN apt-get update \
  && apt-get install --yes --no-install-recommends \
    openjdk-$JAVA_VERSION-jdk \
    curl \
    unzip \
    sed \
    git \
    bash \
    xz-utils \
    libglvnd0 \
    ssh \
    xauth \
    x11-xserver-utils \
    libpulse0 \
    libxcomposite1 \
    libgl1-mesa-glx \
    wget \
    nano \
  && rm -rf /var/lib/{apt,dpkg,cache,log}

# Install Gradle.
RUN curl -L $GRADLE_URL -o gradle-$GRADLE_VERSION-bin.zip \
  && apt-get install -y unzip \
  && unzip gradle-$GRADLE_VERSION-bin.zip \
  && mv gradle-$GRADLE_VERSION $GRADLE_USER_HOME \
  && rm gradle-$GRADLE_VERSION-bin.zip

  ##ANDROID SDK AND NDK which 
RUN cd $HOME \
&& wget https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip \
&& unzip sdk-tools-linux-4333796.zip -d Android \
&& rm sdk-tools-linux-4333796.zip \
&& wget https://dl.google.com/android/repository/commandlinetools-linux-6200805_latest.zip \
&& unzip commandlinetools-linux-6200805_latest.zip -d Android/cmdline-tools \
&& rm commandlinetools-linux-6200805_latest.zip \
&& echo 'export ANDROID_SDK_ROOT=$HOME/Android' >> $HOME/.bashrc \
&& echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> $HOME/.bashrc \
&& echo 'export PATH=$ANDROID_SDK_ROOT/cmdline-tools/tools/bin:"$PATH"' >> $HOME/.bashrc \
&& echo 'export PATH=$ANDROID_SDK_ROOT/cmdline-tools/tools/lib:"$PATH"' >> $HOME/.bashrc \
&& echo 'export PATH=$ANDROID_SDK_ROOT/tools:"$PATH"' >> $HOME/.bashrc \
&& echo 'export PATH=$JAVA_HOME/bin:"$PATH"' >> $HOME/.bashrc \
&& . $HOME/.bashrc \
&& /root/Android/cmdline-tools/tools/bin/sdkmanager --sdk_root=$ANDROID_SDK_ROOT --install "system-images;android-29;google_apis;x86" \
&& /root/Android/cmdline-tools/tools/bin/sdkmanager --sdk_root=$ANDROID_SDK_ROOT --install "system-images;android-29;google_apis;x86_64" \
&& yes "y" | /root/Android/cmdline-tools/tools/bin//sdkmanager "platform-tools" \
&& /root/Android/cmdline-tools/tools/bin/sdkmanager --sdk_root=$ANDROID_SDK_ROOT --install "platforms;android-29" \
&& /root/Android/cmdline-tools/tools/bin/sdkmanager --sdk_root=$ANDROID_SDK_ROOT --install "build-tools;29.0.3" \
&& /root/Android/cmdline-tools/tools/bin/sdkmanager --sdk_root=$ANDROID_SDK_ROOT --install "cmdline-tools;latest" \
  && /root/Android/cmdline-tools/tools/bin/sdkmanager --sdk_root=$ANDROID_SDK_ROOT --install "ndk;26.1.10909125" \
&& /root/Android/cmdline-tools/tools/bin/sdkmanager --licenses \
# Install Flutter.
&& curl -o flutter.tar.xz $FLUTTER_URL \
  && mkdir -p $FLUTTER_ROOT \
  && tar xf flutter.tar.xz -C /opt/ \
  && rm flutter.tar.xz \
  && git config --global --add safe.directory /opt/flutter \
  && flutter config --no-analytics \
  && flutter precache \
  && yes "y" | flutter doctor --android-licenses \
  && flutter doctor \
  && flutter update-packages \
# wasm-pack (Required for both WEB targets) 
# RUN curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh
# binaryen
# To build Credible for WEB using ASM.js you will need binaryen, which allows the conversion of DIDKit WASM to ASM.js. This is necessary when you don't have WASM support and need to run your page in pure Javascript. More detailed instructions on how to build binaryen can be found here.
# If you are in a UNIX-like distribution you just have to clone the repo and build, we recommend cloning into your ${HOME}, to avoid having to specify the ${BINARYEN_ROOT} variable:
# $ git clone https://github.com/WebAssembly/binaryen ~/binaryen
# $ cd ~/binaryen
# $ cmake . && make
&& cargo install cargo-ndk \
# Authorize SSH Host
# RUN mkdir -p /root/.ssh && \
#     chmod 0700 /root/.ssh
# # See: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
# # Add the keys and set permissions
# RUN echo "$ssh_prv_key"
# RUN echo "$ssh_prv_key" > /root/.ssh/github && \
#     echo "$ssh_pub_key" > /root/.ssh/github.pub && \
#     chmod 600 /root/.ssh/github && \
#     chmod 600 /root/.ssh/github.pub
# adding ssh key to ssh agent
&& apt-get update && yes "y" | apt-get install android-tools-adb \
&& eval "$(ssh-agent -s)" \
  && ssh-add /root/.ssh/github \
  && cd /volume \
  && git clone git@github.com:spruceid/wallet.git \
  && cd wallet \
  && git submodule update --init --recursive \
  && cd deps/didkit \
  && cargo build \
  && cd lib \
  && rustup target install i686-linux-android \
  && rustup target install armv7-linux-androideabi \
  && rustup target install aarch64-linux-android \
  && rustup target install x86_64-linux-android \
  && make ../target/test/android.stamp \
  && cd .. \
  && cargo build \
  && cd ../../.. \
  && git clone git@github.com:TalaoDAO/AltMe.git \
  && mv /volume/altme_files/env /volume/AltMe/.env \
  && mv /volume/altme_files/key.properties /volume/AltMe/android/ \
  && mv /volume/altme_files/key.jks /volume/ \
  && mv /volume/altme_files/Appfile_altme_ios /volume/AltMe/ios/fastlane/Appfilegit \
  && ln -s /volume/wallet/deps/didkit /volume/didkit
  # && cd AltMe \
  # && flutter pub get \
# copier les fichiers
# mettre le bon chemin pour libdidkit.so et 
# CMD eval "$(ssh-agent -s)" \
# && ssh-add /root/.ssh/github  


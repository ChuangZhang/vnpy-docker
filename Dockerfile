FROM rahulvbrahmal/python-with-talib
# FROM ubuntu:18.04 
# RUN rm /bin/sh && ln -s /bin/bash /bin/sh
ENV DEBIAN_FRONTEND noninteractive

ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ARG USERNAME
ENV USERNAME ${USERNAME}
ENV WORKSPACE /home/$USERNAME/workspace

# base
COPY ./files/etc/apt/sources.list /etc/apt/sources.list
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3B4FE6ACC0B21F32
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 871920D1991BC93C
RUN apt-get update && apt-get install -y build-essential \
    wget curl vim git libtool automake \
    sudo openssh-server libpq-dev \

#---------------------------------------------------------------------------
# lang
#---------------------------------------------------------------------------

ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

#---------------------------------------------------------------------------
# ssh
#---------------------------------------------------------------------------
RUN /usr/bin/ssh-keygen -A
RUN mkdir /var/run/sshd
ADD ./files/sshd_config /etc/ssh/sshd_config

RUN echo "AcceptEnv LANG LC_*" >> /etc/ssh/sshd_config
RUN echo "AllowUsers $USERNAME" >> /etc/ssh/sshd_config

# still need to run with -p to export ports
EXPOSE 222
# RUN service ssh restart
RUN echo 'root:root' | chpasswd
RUN echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# add user
RUN useradd -rm -d /home/${USERNAME} -s /bin/bash -g root -G sudo -u 1001 ${USERNAME}
RUN echo "${USERNAME}:${USERNAME}" | chpasswd
RUN usermod -aG sudo ${USERNAME}

# vscode
# https://code.visualstudio.com/docs/remote/containers-advanced#_avoiding-extension-reinstalls-on-container-rebuild

USER ${USERNAME}
WORKDIR /home/${USERNAME}

# fonts
ADD ./files/fontconfig /home/$USERNAME/.config/fontconfig

RUN mkdir -p /home/$USERNAME/.vscode-server/extensions \
        /home/$USERNAME/.vscode-server-insiders/extensions \
    && chown -R $USERNAME \
        /home/$USERNAME/.vscode-server \
        /home/$USERNAME/.vscode-server-insiders

#---------------------------------------------------------------------------
# vnpy
#---------------------------------------------------------------------------
# ta-lib underlying lib (must have before pip install)
# RUN mkdir -p /tmp && cd /tmp && wget https://artiya4u.keybase.pub/TA-lib/ta-lib-0.4.0-src.tar.gz
# RUN cd /tmp && tar -xvf /tmp/ta-lib-0.4.0-src.tar.gz
# RUN cd /tmp/ta-lib && ./configure --prefix=/usr && make && sudo make install
RUN ta-lib-config --libs

# python
RUN mkdir -p $WORKSPACE
RUN cd $WORKSPACE && python3 -m venv venv
RUN $WORKSPACE/venv/bin/pip install pip --upgrade && \
    $WORKSPACE/venv/bin/pip install wheel

# clone vnpy (commit: b4e8a079be2123e72bfa9a8cccebc784aaee3789)
# RUN cd $WORKSPACE && git clone https://github.com/vnpy/vnpy.git
# RUN cd $WORKSPACE/vnpy && git checkout b4e8a079be2123e72bfa9a8cccebc784aaee3789
RUN cd $WORKSPACE && \
    git clone https://github.com/ChuangZhang/vnpy.git $WORKSPACE/vnpy && \
    cd $WORKSPACE/vnpy && \
    bash install.sh $WORKSPACE/venv/bin/python3 https://pypi.tuna.tsinghua.edu.cn/simple
ADD ./vnpy-files/patches $WORKSPACE/patches
RUN cd $WORKSPACE/vnpy && git apply $WORKSPACE/patches/*.patch

# RUN chmod +x ./vnpy/install.sh
# RUN cd $WORKSPACE/vnpy && source $WORKSPACE/venv/bin/activate && ./install.sh 
RUN $WORKSPACE/venv/bin/pip install psycopg2-binary -i https://pypi.tuna.tsinghua.edu.cn/simple
RUN $WORKSPACE/venv/bin/pip install https://pip.vnpy.com/colletion/ibapi-9.76.1.tar.gz

# quickfix
# RUN cd $WORKSPACE/vnpy && sed -i.bak '/quickfix/d' requirements.txt
RUN $WORKSPACE/venv/bin/pip install -r $WORKSPACE/vnpy/requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

# upgrade numpy
RUN $WORKSPACE/venv/bin/pip install numpy --upgrade -i https://pypi.tuna.tsinghua.edu.cn/simple

# build wheel (skip)
RUN cd $WORKSPACE/vnpy && $WORKSPACE/venv/bin/python setup.py build
RUN cd $WORKSPACE/vnpy && $WORKSPACE/venv/bin/python -m pip install .

# workaround extensions .so
ADD ./vnpy-files/copy-so.sh $WORKSPACE
# RUN cd $WORKSPACE && chmod +x ./copy-so.sh && ./copy-so.sh
RUN cd $WORKSPACE && sudo chmod +x ./copy-so.sh && ./copy-so.sh

#---------------------------------------------------------------------------
# environment
#---------------------------------------------------------------------------

# python additional package path
RUN echo "export WORKSPACE=$WORKSPACE" >> ~/.bashrc
RUN echo "export LD_LIBRARY_PATH=$WORKSPACE/vnpy/vnpy/api/xtp/libs" >> ~/.bashrc
RUN echo "export PYTHONPATH=$PYTHONPATH:$WORKSPACE/vnpy" >> ~/.bashrc
RUN echo "source ~/workspace/venv/bin/activate" >> ~/.bashrc

# timezone
RUN echo "export TZ=Asia/Shanghai" >> ~/.profile
RUN echo "export LC_CTYPE=en_US.utf-8" >> ~/.profile
RUN echo "export LANG=en_US.UTF-8" >> ~/.profile
# supress libGL error: No matching fbConfigs or visuals found
RUN echo "export LIBGL_ALWAYS_INDIRECT=1" >> ~/.profile

#---------------------------------------------------------------------------
# run
#---------------------------------------------------------------------------

# cleanup
RUN sudo rm -rf /var/lib/apt/lists/*
RUN sudo apt-get -qyy clean
RUN sudo rm -rf /tmp/ta-lib*
RUN sudo rm -rf /tmp/quickfix

ENTRYPOINT sudo service ssh restart && bash




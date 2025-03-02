FROM rahulvbrahmal/python-with-talib
# FROM ubuntu:18.04 
# RUN rm /bin/sh && ln -s /bin/bash /bin/sh
ENV DEBIAN_FRONTEND noninteractive

ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ARG USERNAME=zchuang
ENV USERNAME ${USERNAME}
ENV WORKSPACE /home/$USERNAME/workspace

#---------------------------------------------------------------------------
# lang
#---------------------------------------------------------------------------

ENV LANG en_US.UTF-8 
ENV LC_ALL C 
 
# base
COPY ./files/etc/apt/sources.list /etc/apt/sources.list
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3B4FE6ACC0B21F32
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 871920D1991BC93C
RUN apt-get update && apt-get install -y build-essential \
    wget curl vim git libtool automake python3.8 python3.8-venv python3-dev \
    sudo openssh-server libpq-dev locales
RUN sed -i 's/# zh_CN/zh_CN/p' /etc/locale.gen && sed -i 's/# en_US/en_US/p' /etc/locale.gen && locale-gen

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
COPY ./files/home/bash/.bash_aliases /home/$USERNAME

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
ENV INDEX https://pypi.tuna.tsinghua.edu.cn/simple
RUN ta-lib-config --libs

# python
RUN mkdir -p $WORKSPACE
RUN cd $WORKSPACE && python3.8 -m venv --copies --system-site-packages venv && \
    $WORKSPACE/venv/bin/pip install pip --upgrade -i ${INDEX} && \
    $WORKSPACE/venv/bin/pip install wheel --upgrade -i ${INDEX}

# clone vnpy (commit: b4e8a079be2123e72bfa9a8cccebc784aaee3789)
# RUN cd $WORKSPACE && git clone https://github.com/vnpy/vnpy.git
# RUN cd $WORKSPACE/vnpy && git checkout b4e8a079be2123e72bfa9a8cccebc784aaee3789
ENV prefix /usr/bin
# upgrade numpy
RUN $WORKSPACE/venv/bin/pip install numpy --upgrade -i ${INDEX}
COPY --chown=$USERNAME:root ./vnpy $WORKSPACE/vnpy
RUN cd $WORKSPACE/vnpy && \
    bash install.sh $WORKSPACE/venv/bin/python3 https://pypi.tuna.tsinghua.edu.cn/simple
COPY --chown=$USERNAME:root ./vnpy_rpcservice $WORKSPACE/vnpy_rpcservice
RUN cd $WORKSPACE/vnpy_rpcservice && \
    $WORKSPACE/venv/bin/pip install .

# RUN chmod +x ./vnpy/install.sh
# RUN cd $WORKSPACE/vnpy && source $WORKSPACE/venv/bin/activate && ./install.sh 
RUN $WORKSPACE/venv/bin/pip install psycopg2-binary -i ${INDEX}
RUN $WORKSPACE/venv/bin/pip install https://pip.vnpy.com/colletion/ibapi-9.76.1.tar.gz

# quickfix
# RUN cd $WORKSPACE/vnpy && sed -i.bak '/quickfix/d' requirements.txt
RUN $WORKSPACE/venv/bin/pip install -r $WORKSPACE/vnpy/requirements.txt -i ${INDEX}

# workaround extensions .so
# ADD ./vnpy-files/copy-so.sh $WORKSPACE
# RUN cd $WORKSPACE && chmod +x ./copy-so.sh && ./copy-so.sh
# RUN cd $WORKSPACE && sudo chmod +x ./copy-so.sh && ./copy-so.sh

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
RUN echo "export LC_CTYPE=en_US.UTF-8" >> ~/.profile
RUN echo "export LANG=en_US.UTF-8" >> ~/.profile
RUN echo "export LC_ALL=C" >> ~/.profile
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

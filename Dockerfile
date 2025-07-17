FROM geonode/geonode-base:latest-ubuntu-22.04
LABEL GeoNode development team

RUN mkdir -p /usr/src/{{project_name}}

# Instala pacotes básicos e também as dependências para compilar o PROJ
RUN apt-get update -y && apt-get install -y \
    curl wget unzip gnupg2 locales build-essential cmake sqlite3 libsqlite3-dev

RUN sed -i -e 's/# C.UTF-8 UTF-8/C.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LC_ALL C.UTF-8
ENV LANG C.UTF-8

# add bower and grunt command
COPY src /usr/src/{{project_name}}/
WORKDIR /usr/src/{{project_name}}

# --- Atualização do PROJ para 9.5.0 ---
# Cria uma pasta temporária, baixa, compila e instala o PROJ no /usr/local
# --- Atualização do PROJ para 9.5.0 ---
    RUN mkdir -p /tmp/proj_build && cd /tmp/proj_build && \
    wget https://download.osgeo.org/proj/proj-9.5.0.tar.gz && \
    tar -xzf proj-9.5.0.tar.gz && cd proj-9.5.0 && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local && \
    make -j"$(nproc)" && \
    make install && \
    ldconfig && \
    rm -rf /tmp/proj_build

# Define o caminho dos dados do PROJ para que o pyproj os encontre
ENV PROJ_LIB=/usr/local/share/proj

#COPY src/monitoring-cron /etc/cron.d/monitoring-cron
#RUN chmod 0644 /etc/cron.d/monitoring-cron
#RUN crontab /etc/cron.d/monitoring-cron
#RUN touch /var/log/cron.log
#RUN service cron start

COPY src/wait-for-databases.sh /usr/bin/wait-for-databases
RUN chmod +x /usr/bin/wait-for-databases
RUN chmod +x /usr/src/{{project_name}}/tasks.py \
    && chmod +x /usr/src/{{project_name}}/entrypoint.sh

COPY src/celery.sh /usr/bin/celery-commands
RUN chmod +x /usr/bin/celery-commands

COPY src/celery-cmd /usr/bin/celery-cmd
RUN chmod +x /usr/bin/celery-cmd

# Install "geonode-contribs" apps
# RUN cd /usr/src; git clone https://github.com/GeoNode/geonode-contribs.git -b master
# Install logstash and centralized dashboard dependencies
# RUN cd /usr/src/geonode-contribs/geonode-logstash; pip install --upgrade  -e . \
#     cd /usr/src/geonode-contribs/ldap; pip install --upgrade  -e .

RUN yes w | pip install --src /usr/src -r requirements.txt &&\
    yes w | pip install -e .

# --- Força a reinstalação do pyproj para a versão 3.7.0 ---
# Mesmo que os arquivos de requisitos imponham outra versão, esse comando força o pip
# a compilar o pyproj (usando a versão do PROJ instalada) a partir do código-fonte.
RUN pip uninstall -y pyproj || true && \
    pip install --force-reinstall --no-binary :all: "pyproj<3.7.0"

# Cleanup apt update lists
RUN apt-get autoremove --purge &&\
    apt-get clean &&\
    rm -rf /var/lib/apt/lists/*

# Export ports
EXPOSE 8000

# We provide no command or entrypoint as this image can be used to serve the django project or run celery tasks
# ENTRYPOINT /usr/src/{{project_name}}/entrypoint.sh

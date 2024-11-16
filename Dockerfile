FROM alpine:latest

# Installa gli strumenti necessari
RUN apk update
# RUN apk add --no-cache openssh bash findutils poppler-utils zip

# Installazione delle dipendenze per PDF e immagini
RUN apk add --no-cache poppler-utils findutils imagemagick jpegoptim zip bash openssh

# Configura SSH
RUN mkdir /var/run/sshd && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "root:root" | chpasswd

# Copia lo script nel container
COPY convert.sh /usr/local/bin/convert.sh

# Rendi lo script eseguibile
RUN chmod +x /usr/local/bin/convert.sh

# Definisci la directory di lavoro
WORKDIR /takeaway

# Imposta lo script come comando predefinito
CMD ["bash", "/usr/local/bin/convert.sh"]



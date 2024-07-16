FROM --platform=linux/amd64 amazonlinux:2023

# Set up working directories
RUN mkdir -p /opt/app
RUN mkdir -p /opt/app/build
RUN mkdir -p /opt/app/bin/

# Copy in the lambda source
WORKDIR /opt/app
COPY ./*.py /opt/app/
COPY requirements.txt /opt/app/requirements.txt

# Install packages
RUN dnf update -y
RUN dnf install -y cpio 'dnf-command(download)' zip unzip less
# Don't love this but python 3.12 is not in AL2023 yet
RUN dnf install -y https://repo.almalinux.org/almalinux/9/AppStream/x86_64/os/Packages/python3.12-3.12.1-4.el9.x86_64.rpm https://repo.almalinux.org/almalinux/9/AppStream/x86_64/os/Packages/python3.12-libs-3.12.1-4.el9.x86_64.rpm        https://repo.almalinux.org/almalinux/9/AppStream/x86_64/os/Packages/python3.12-pip-wheel-23.2.1-4.el9.noarch.rpm https://repo.almalinux.org/almalinux/9/AppStream/x86_64/os/Packages/libnsl2-2.0.0-1.el9.x86_64.rpm https://repo.almalinux.org/almalinux/9/AppStream/x86_64/os/Packages/python3.12-pip-23.2.1-4.el9.noarch.rpm

# This had --no-cache-dir, tracing through multiple tickets led to a problem in wheel
RUN pip3.12 install -r requirements.txt
RUN rm -rf /root/.cache/pip

# Download libraries we need to run in lambda
WORKDIR /tmp
RUN dnf download clamav clamav-lib clamav-update json-c pcre2 libtool-ltdl
RUN rpm2cpio clamav-0*.rpm | cpio -idmv
RUN rpm2cpio clamav-lib*.rpm | cpio -idmv
RUN rpm2cpio clamav-update*.rpm | cpio -idmv
RUN rpm2cpio json-c*.rpm | cpio -idmv
RUN rpm2cpio pcre*.rpm | cpio -idmv
RUN rpm2cpio libtool-ltdl*.rpm | cpio -idmv

# Copy over the binaries and libraries
RUN cp /tmp/usr/bin/clamscan /tmp/usr/bin/freshclam /tmp/usr/lib64/* /opt/app/bin/

# Fix the freshclam.conf settings
RUN echo "DatabaseMirror database.clamav.net" > /opt/app/bin/freshclam.conf
RUN echo "CompressLocalDatabase yes" >> /opt/app/bin/freshclam.conf

# Create the zip file
WORKDIR /opt/app
RUN zip -r9 --exclude="*test*" /opt/app/build/lambda.zip *.py bin

WORKDIR /usr/local/lib/python3.12/site-packages
RUN zip -r9 /opt/app/build/lambda.zip *

WORKDIR /opt/app

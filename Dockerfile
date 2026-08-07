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
RUN dnf install -y python3.12 python3.12-pip

# This had --no-cache-dir, tracing through multiple tickets led to a problem in wheel
RUN pip3.12 install -r requirements.txt
RUN rm -rf /root/.cache/pip

# Download libraries we need to run in lambda
WORKDIR /tmp
RUN dnf download clamav1.4 clamav1.4-lib clamav1.4-freshclam json-c pcre2 libtool-ltdl
RUN rpm2cpio clamav1.4-1.*.rpm | cpio -idmv
RUN rpm2cpio clamav1.4-lib*.rpm | cpio -idmv
RUN rpm2cpio clamav1.4-freshclam*.rpm | cpio -idmv
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

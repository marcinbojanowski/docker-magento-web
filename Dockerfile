FROM php:5.6-fpm-alpine3.8

# Add s6-overlay
ENV S6_OVERLAY_VERSION=v1.19.1.1 \
    NGINX_VERSION=nginx-1.13.3 \
    S6_FIX_ATTRS_HIDDEN=1 \
    COMPOSER_ALLOW_SUPERUSER=1 \
    TZ="America/Chicago"

RUN set -xe \

    # add magento user and group
    && addgroup -g 1000 -S magento \
    && adduser  -u 104  -D -S -G magento magento \

    # Install all build dependencies
    && apk add --no-cache --virtual .build-deps \
        icu-dev \
        libpng-dev \
        libjpeg-turbo-dev \
        freetype-dev \
        libxslt-dev \
        libmcrypt-dev \
        curl-dev \
        bzip2-dev \
        readline-dev \
        libedit-dev \
        recode-dev \
        imagemagick-dev  \
        geoip-dev \
        # libxml2-dev \
        #  pcre-dev
        $PHPIZE_DEPS \

    # Install libraries needed for extra PHP modules
    && apk add --no-cache \
        libpng \
        libjpeg \
        freetype \
        icu-libs \
        libmcrypt \
        libxslt \
        libbz2 \
        imagemagick \
        geoip \
        readline \
        libtool \
        recode \

    # set timezone to America/Chicago
    && apk add --no-cache tzdata \
    && cp /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo "$TZ" >  /etc/timezone \
    && apk del tzdata \

    # Extra PHP extensions (no extra configuration)
    && docker-php-ext-install \
        bcmath \
        bz2 \
        curl \
        intl \
        iconv \
        json \
        mbstring \
        mcrypt \
        pdo \
        pdo_mysql \
        mysqli \
        readline \
        recode \
        simplexml \
        soap \
        xmlrpc \
        xsl \
        zip \
        exif \

    # install imagick via pecl
    && pecl install imagick-3.4.3 \
    && docker-php-ext-enable imagick \

    # install redis via pecl (newest 3.1.3 not working with magento :( )
    && pecl install -o -f redis-3.1.2 \
    &&  docker-php-ext-enable redis \

    # install geoip via pecl
    && pecl install -o -f geoip-1.1.1 \
    &&  docker-php-ext-enable geoip \

    # install geoip via pecl
    && pecl install -o -f igbinary \
    && docker-php-ext-enable geoip \

    # GD extension
    && docker-php-ext-configure gd \
        --with-freetype-dir=/usr/include/ \
        --with-jpeg-dir=/usr/include \
    && docker-php-ext-install gd \

    # opcache config
    && docker-php-ext-configure opcache --enable-opcache \
    && docker-php-ext-install opcache \
    && cd /usr/local/etc/php/conf.d \
    && echo "opcache.enable=1" >> docker-php-ext-opcache.ini \
    && echo "opcache.enable_cli=1" >> docker-php-ext-opcache.ini \
    && echo "opcache.memory_consumption=512" >> docker-php-ext-opcache.ini \
    && echo "opcache.interned_strings_buffer=12" >> docker-php-ext-opcache.ini \
    && echo "opcache.fast_shutdown=1" >> docker-php-ext-opcache.ini \
    && echo "opcache.revalidate_freq=0" >> docker-php-ext-opcache.ini \
    && echo "opcache.max_accelerated_files=65406" >> docker-php-ext-opcache.ini \

    # install nginx
    && apk --update add openssl-dev pcre-dev zlib-dev build-base \
    && mkdir -p /tmp/src \
    && cd /tmp/src \
    && curl http://nginx.org/download/${NGINX_VERSION}.tar.gz > ${NGINX_VERSION}.tar.gz \
    && tar -zxvf ${NGINX_VERSION}.tar.gz \
    && cd /tmp/src/${NGINX_VERSION} \
    && ./configure \
        --with-http_ssl_module \
        --with-http_realip_module \
        --with-http_geoip_module \
        --with-http_gzip_static_module \
        --prefix=/etc/nginx \
        --http-log-path=/var/log/nginx/access.log \
        --error-log-path=/var/log/nginx/error.log \
        --sbin-path=/usr/local/sbin/nginx \
    && make \
    && make install \
    && apk del build-base \
    && rm -rf /tmp/src \

    # install other stuff
    &&  apk add --no-cache \
        vim  \
        nginx \
        ssmtp \
        dcron \
        curl \
        sudo \
        git \
        jq \

    # install s6
    && curl -sSL https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-amd64.tar.gz \
           | tar xfz - -C / \

    # install composer
    && curl -sS https://getcomposer.org/installer | php -- --filename=composer --install-dir=/usr/local/bin \

    # install n98-magerun
    && curl -fSL -o /usr/local/bin/n98-magerun \
    --url https://files.magerun.net/n98-magerun.phar \
    && chmod +x /usr/local/bin/n98-magerun \


    # Delete build dependencies to save space
    && apk del .build-deps \

    # remove pear cache
    && rm -rf /tmp/pear \

    # Remove apk cache
    && rm -rf /var/cache/apk/*


# root filesystem
COPY rootfs /

HEALTHCHECK --interval=30s --timeout=3s \
    CMD curl -f http://localhost/ || exit 1

EXPOSE 80
WORKDIR /var/www/magento
ENTRYPOINT ["/init"]
CMD []

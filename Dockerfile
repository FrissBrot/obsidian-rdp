FROM debian:12

ARG OBSIDIAN_VERSION=1.12.4

ENV DEBIAN_FRONTEND=noninteractive \
    APP_MODE=restart \
    USER_NAME=user \
    USER_PASSWORD=asdf \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    LANGUAGE=C.UTF-8 \
    OBSIDIAN_VERSION=${OBSIDIAN_VERSION}

RUN apt-get update && apt-get install -y --no-install-recommends \
    xrdp \
    xorgxrdp \
    openbox \
    dbus \
    dbus-x11 \
    xterm \
    wget \
    ca-certificates \
    xdg-utils \
    python3-xdg \
    wmctrl \
    procps \
    fontconfig \
    fonts-noto-color-emoji \
    fonts-dejavu \
    fonts-liberation \
    libnss3 \
    libasound2 \
    libgbm1 \
    libgtk-3-0 \
    libxss1 \
    libxtst6 \
    libnotify4 \
    libdrm2 \
    libxdamage1 \
    libxrandr2 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libxkbcommon0 \
    libglib2.0-0 \
    libpango-1.0-0 \
    libcairo2 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxi6 \
    libxext6 \
    libxfixes3 \
    libxrender1 \
    libfontconfig1 \
    libfreetype6 \
    libjpeg62-turbo \
    libpng16-16 \
    libwebp7 \
    libtiff6 \
    libgdk-pixbuf-2.0-0 \
    gdk-pixbuf2.0-bin \
    shared-mime-info \
    xdg-desktop-portal \
    gvfs \
    file \
    x11-utils \
    imagemagick \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/fonts/conf.d \
    && cat > /etc/fonts/conf.d/99-emoji.conf <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <alias binding="strong">
    <family>sans-serif</family>
    <prefer>
      <family>Noto Color Emoji</family>
    </prefer>
  </alias>
</fontconfig>
EOF

RUN update-mime-database /usr/share/mime || true

RUN fc-cache -f -v

RUN printf 'LANG=C.UTF-8\nLC_ALL=C.UTF-8\nLANGUAGE=C.UTF-8\n' > /etc/default/locale

RUN useradd -m -s /bin/bash "${USER_NAME}" \
    && touch "/home/${USER_NAME}/.Xauthority" \
    && mkdir -p "/home/${USER_NAME}/Obsidian Vault" \
    && mkdir -p "/home/${USER_NAME}/.config/obsidian" \
    && mkdir -p "/home/${USER_NAME}/.local/share/obsidian" \
    && mkdir -p "/home/${USER_NAME}/.cache" \
    && mkdir -p "/home/${USER_NAME}/.config/openbox" \
    && chown -R "${USER_NAME}:${USER_NAME}" "/home/${USER_NAME}"

RUN sed -i 's/^LogLevel=.*/LogLevel=ERROR/' /etc/xrdp/xrdp.ini \
    && sed -i 's/^EnableSyslog=.*/EnableSyslog=false/' /etc/xrdp/xrdp.ini \
    && sed -i 's/^LogLevel=.*/LogLevel=ERROR/' /etc/xrdp/sesman.ini \
    && sed -i 's/^EnableSyslog=.*/EnableSyslog=false/' /etc/xrdp/sesman.ini \
    && grep -q '^\[Chansrv\]' /etc/xrdp/sesman.ini || printf '\n[Chansrv]\n' >> /etc/xrdp/sesman.ini \
    && if grep -q '^EnableFuseMount=' /etc/xrdp/sesman.ini; then \
           sed -i 's/^EnableFuseMount=.*/EnableFuseMount=false/' /etc/xrdp/sesman.ini; \
       else \
           sed -i '/^\[Chansrv\]/a EnableFuseMount=false' /etc/xrdp/sesman.ini; \
       fi

RUN wget -O /tmp/Obsidian.AppImage \
        "https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBSIDIAN_VERSION}/Obsidian-${OBSIDIAN_VERSION}.AppImage" \
    && chmod +x /tmp/Obsidian.AppImage \
    && cd /tmp \
    && ./Obsidian.AppImage --appimage-extract \
    && mv /tmp/squashfs-root /opt/obsidian \
    && chmod 755 /opt \
    && chown -R root:root /opt/obsidian \
    && find /opt/obsidian -type d -exec chmod 755 {} \; \
    && find /opt/obsidian -type f -exec chmod 644 {} \; \
    && chmod 755 /opt/obsidian/AppRun \
    && chmod 755 /opt/obsidian/obsidian \
    && if [ -f /opt/obsidian/chrome-sandbox ]; then chmod 755 /opt/obsidian/chrome-sandbox; fi \
    && rm -f /tmp/Obsidian.AppImage

COPY skript/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY skript/start-obsidian.sh /usr/local/bin/start-obsidian.sh
COPY skript/obsidian-session.sh /usr/local/bin/obsidian-session.sh
COPY container-config/openbox-rc.xml /etc/skel/.config/openbox/rc.xml
COPY skript/openbox-autostart /etc/skel/.config/openbox/autostart
COPY skript/xsession /etc/skel/.xsession

RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
    && chmod +x /usr/local/bin/start-obsidian.sh \
    && chmod +x /usr/local/bin/obsidian-session.sh \
    && chmod +x /etc/skel/.config/openbox/autostart \
    && chmod +x /etc/skel/.xsession \
    && cp -a /etc/skel/. "/home/${USER_NAME}/" \
    && chown -R "${USER_NAME}:${USER_NAME}" "/home/${USER_NAME}"

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD pgrep -x xrdp >/dev/null && pgrep -f xrdp-sesman >/dev/null || exit 1

EXPOSE 3389

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

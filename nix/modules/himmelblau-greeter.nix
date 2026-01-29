{ lib, config, pkgs, ... }:

let
  cfg = config.services.himmelblau;
in
{
  config = lib.mkIf cfg.greeter.enable {
    systemd.tmpfiles.rules = [
      "d /var/log/himmelblau-greeter 0755 greeter greeter -"
      "d /var/lib/himmelblau-greeter 0755 greeter greeter -"
      "d /run/greeter 0700 greeter greeter -"
      "d /var/lib/himmelblau-greeter/.config 0755 greeter greeter -"
      "d /var/lib/himmelblau-greeter/.config/xdg-desktop-portal 0755 greeter greeter -"
    ];

    environment.etc."himmelblau-greeter/xdg-desktop-portal/portals.conf".text = ''
      [preferred]
      default=none
      org.freedesktop.impl.portal.FileChooser=none
      org.freedesktop.impl.portal.Settings=none
      org.freedesktop.impl.portal.Notification=none
      org.freedesktop.impl.portal.Screenshot=none
      org.freedesktop.impl.portal.AppChooser=none
      org.freedesktop.impl.portal.Access=none
      org.freedesktop.impl.portal.Inhibit=none
      org.freedesktop.impl.portal.Secret=none
    '';

    systemd.services.himmelblau-greeter-xdg = {
      description = "Prepare XDG config for himmelblau greeter";
      wantedBy = [ "multi-user.target" ];
      before = [ "greetd.service" ];
      serviceConfig = {
        Type = "oneshot";
      };
      script = ''
        ln -sf /etc/himmelblau-greeter/xdg-desktop-portal \
          /var/lib/himmelblau-greeter/.config/xdg-desktop-portal
        chown -R greeter:greeter /var/lib/himmelblau-greeter/.config
      '';
    };

    services.greetd = {
      enable = true;

      settings = {
        terminal.vt = 1;

        default_session = {
          user = "greeter";
          command =
            let
              renderer =
                lib.optionalString cfg.greeter.usePixman "WLR_RENDERER=pixman";
            in
            ''
              env \
                XDG_RUNTIME_DIR=/run/greeter \
                XDG_CONFIG_HOME=/var/lib/himmelblau-greeter/.config \
                XDG_CURRENT_DESKTOP=none \
                GTK_USE_PORTAL=0 \
                GDK_DEBUG=no-portals \
                GTK_A11Y=none \
                NO_AT_BRIDGE=1 \
                ${renderer} \
                WEBKIT_DISABLE_DMABUF_RENDERER=1 \
                WEBKIT_DISABLE_COMPOSITING_MODE=1 \
                WEBKIT_USE_PORTAL=0 \
                ${pkgs.cage}/bin/cage -s -- \
                ${cfg.greeter.greeterPackage}/bin/himmelblau-greeter
            '';
        };
      };
    };

    #### Make greetd the active display manager
    services.displayManager.enable = false;
  };
}

self: { config, lib, pkgs, ...}:

with lib;

let
  cfg = config.services.meshtastic;

  settingsFormat = pkgs.formats.yaml {};
  configFile = settingsFormat.generate "meshtasticd-config.yaml" cfg.settings;

  defaultUser = "meshtastic";
in {

  options.services.meshtastic = {
    enable = mkEnableOption "Meshtastic native daemon";

    package = mkPackageOption self.packages.${pkgs.system} "meshtasticd" {};

    user = mkOption {
      type = types.str;
      default = defaultUser;
      description = ''
        User account under which Meshtasticd runs.
      '';
    };

    group = mkOption {
      type = types.str;
      default = defaultUser;
      description = ''
        Group under which Meshtasticd runs.
      '';
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/meshtastic";
      description = ''
        The state directory for meshtasticd.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Open ports in the firewall for builtin API and Web servers.
      '';
    };

    apiPort = lib.mkOption {
      type = lib.types.port;
      default = 4403;
      description = ''
        Which port API server should listen on.
      '';
    };

    settings = mkOption {
      type = types.submodule {
        freeformType = settingsFormat.type;
      };
      default = {};
      example = literalExpression ''
        {
          Lora = {
            Module = "sx1262";  # Waveshare SX126X XXXM LoRaWAN/GNSS HAT
            DIO2_AS_RF_SWITCH = true;
            CS = 21;
            IRQ = 16;
            Busy = 20;
            Reset = 18;
            gpiochip = 4; # RPi5 has GPIO header on gpiochip4
          };
          GPS = {
            SerialPath = "/dev/ttyS0";
          };
          Webserver = {
            Port = 1443;
          };
        }
      '';
      description = ''
        Configuration for Meshtastic native daemon (meshtasticd), see
        <https://meshtastic.org/docs/hardware/devices/linux-native-hardware/#configuration> 
        and <https://github.com/meshtastic/firmware/blob/master/bin/config-dist.yaml> 
        for details.

        The Nix value declared here will be translated directly to the YAML 
        format meshtasticd expects.

        See <https://github.com/NixOS/rfcs/blob/master/rfcs/0042-config-option.md>
      '';
    };

    extraFlags = mkOption {
      default = [ ];
      example = [ "--hwid=1" ];
      type = types.listOf types.str;
      description = ''
        Extra arguments to use for starting meshtasticd.
      '';
    };
  };


  config = mkIf cfg.enable {

    # some base default settings
    services.meshtastic.settings = {
      Lora = {
        # omitting this section suspiciously changes order of logs, keep it 
        # to be on the safe side
      };
      Logging = {
        LogLevel = lib.mkDefault "info";  # debug, info, warn, error
      };
      Webserver = {
        # must be present even if webserver is to be disabled, daemon logs the 
        # error: 'Error starting Web Server framework, error number: 4'
        # webserver is not enabled unless port number is specified with 'Port'
        RootPath = lib.mkDefault "${cfg.package}/share/doc/meshtasticd/web";
      };
      General = {
        MaxNodes = lib.mkDefault 200;
        MaxMessageQueue = lib.mkDefault 100;
      };
    };

    systemd = {
      tmpfiles.settings.meshtasticd = {
        "${cfg.dataDir}"."d" = {
          mode = "700";
          inherit (cfg) user group;
        };
      };

      # following https://github.com/meshtastic/firmware/blob/master/bin/meshtasticd.service
      services.meshtastic = {
        description = "Meshtastic native daemon (meshtasticd)";
        wantedBy = [ "multi-user.target" ];
        # warning: meshtastic.service is ordered after 'network-online.target' but doesn't depend on it
        # after = [ "network-online.target" ];

        startLimitIntervalSec = "200";
        startLimitBurst = "5";

        serviceConfig = {
          User = cfg.user;
          Group = cfg.group;
          UMask = "0077";
          ExecStart = lib.concatStringsSep " " [
            "${cfg.package}/bin/meshtasticd"
            "--config=${configFile}"
            "--fsdir=${cfg.dataDir}"
            "--port=${toString cfg.apiPort}"
            (escapeShellArgs cfg.extraFlags)
          ];
          Restart = "always";
          RestartSec = "3";

          StandardOutput = "journal";
          StandardError = "journal";
        };
      };
    };

    users.users = mkIf (cfg.user == defaultUser) {
      ${defaultUser} = {
        description = "Meshtasticd daemon user";
        isSystemUser = true;
        inherit (cfg) group;
        extraGroups = with config.users.groups; [ spi.name gpio.name ];
      };
    };

    users.groups = mkIf (cfg.group == defaultUser) {
      ${defaultUser} = {};
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall ([
      cfg.apiPort
    ] ++ lib.optional (cfg.config.Webserver ? Port) cfg.config.Webserver.Port);

  };

  meta.maintainers = with maintainers; [ kazenyuk ];
}

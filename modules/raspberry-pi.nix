{ config, lib, pkgs, ...}:

with lib;

let
  cfg = config.services.meshtastic;
  st = cfg.settings;
in {

  config = mkIf cfg.enable {

    hardware.raspberry-pi.config.all.base-dt-params = let
      needsSpi = st.Lora ? spidev
              || st ? Display.spidev
              || st ? Touchscreen.spidev;
      needsI2C = st ? I2C.I2CDevice
              || st ? Touchscreen.I2CAddr;
    in {
      spi = {
        enable = lib.mkDefault needsSpi;
        value = "on";
      };
      i2c = {
        enable = lib.mkDefault needsI2C;
        value = "on";
      };
    };          

  };

  meta.maintainers = with maintainers; [ kazenyuk ];
}
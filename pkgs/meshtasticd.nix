{ lib, stdenv
, fetchurl
, autoPatchelfHook
, dpkg
, libgpiod_1
, libyaml-cpp
, ulfius
, orcania
, openssl
}:

let
  unsupported = throw "unsupported system ${stdenv.hostPlatform.system}";

  srcVariant = {
    x86_64-linux = {
      arch = "amd64";
      hash = "sha256-9s63FdXa+opXm82qsLX9t4JEFmbQ65YShXCrrxLdqG0=";
    };
    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-vuW+yjOtQrqX9UWPMtWtJaAwUwB/2z/lbQPp3HGnwm4=";
    };
    armv7l-linux = {
      arch = "armhf";
      hash = "sha256-6HaFGMXsevAi/hmmxhTAqNMWF4r7S6dIn09sr9D0adg=";
    };
  }.${stdenv.hostPlatform.system} or unsupported;
in stdenv.mkDerivation (finalAttrs: {
  pname = "meshtasticd";
  version = "2.5.15.79da236";

  src = let
    baseUrl = "https://github.com/meshtastic/firmware/releases/download";
    fileName = "${finalAttrs.pname}_${finalAttrs.version}_${srcVariant.arch}.deb";
  in fetchurl {
    url = "${baseUrl}/v${finalAttrs.version}/${fileName}";
    inherit (srcVariant) hash;
  };

  nativeBuildInputs = [ autoPatchelfHook dpkg ];

  unpackCmd = "dpkg-deb -x $curSrc source";

  # meshtasticd is compiled on debian bookworm
  # https://github.com/meshtastic/firmware/blob/master/Dockerfile
  # https://packages.debian.org/search?suite=bookworm&keywords=keywords
  buildInputs = [
    libgpiod_1  # nixpkgs: 1.6.4, debian: 1.6.3
    libyaml-cpp # nixpkgs: -, debian: 0.7.0
    ulfius      # nixpkgs: -, debian: 2.7.13
    orcania     # nixpkgs: 2.3.3, debian: 2.3.2
    openssl     # nixpkgs: 3.0.14, debian: 3.0.13
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp -r usr/sbin/meshtasticd $out/bin
    cp -r usr/share $out/share

    cp -r etc $out/share
    cp -r usr/lib $out/share

    runHook postInstall
  '';

  meta = with lib; {
    description = "Meshtastic device firmware for Linux-native devices (meshtasticd)";
    longDescription = ''
      meshtasticd is a Meshtastic daemon for Linux-native devices, utilizing
      portduino to run the firmware under Linux.
      https://meshtastic.org/docs/hardware/devices/linux-native-hardware/
    '';
    homepage = "https://github.com/meshtastic/firmware";
    changelog = "https://github.com/meshtastic/firmware/releases/tag/v${finalAttrs.version}";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    mainProgram = "meshtasticd";
    license = licenses.gpl3Only;
    platforms = [ "x86_64-linux" "aarch64-linux" "armv7l-linux" ];
    maintainers = with maintainers; [ kazenyuk ];
  };
})
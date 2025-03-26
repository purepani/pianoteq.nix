# Author: phga <phga@posteo.de>
{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self
    , nixpkgs
    ,
    } @ inputs:
    let
      pianoteq9 = with import nixpkgs { system = "x86_64-linux"; };
        stdenv.mkDerivation rec {
          pname = "pianoteq";
          version = "8.4.1";

          icon = fetchurl
            {
              name = "pianoteq_icon_128";
              url = "https://www.pianoteq.com/images/logo/pianoteq_icon_128.png";
              sha256 = "sha256-lO5kz2aIpJ108L9w2BHnRmq6wQP+6rF0lqifgor8xtM=";
            };

          # IMPORTANT: Use the following command to retrive the correct hash.
          # Otherwise the file is not found in the nix store (Add it first ofc)
          # nix hash to-sri --type sha256 `sha256sum pianoteq_linux_v754.7z`
          src = requireFile {
            name = "pianoteq_setup_v901.tar.xz";
            message = "Download the file from: https://www.modartt.com/download?file=pianoteq_linux_v901.tar.xz and add it to the nix store manually: nix-store --add-fixed sha256 ./pianoteq_linux_v901.tar.xz";
            #sha256 = "sha256-vWvo+ctJ0yN6XeJZZVhA3Ul9eWJWAh7Qo54w0TpOiVw=";
            sha256 = "sha256-ZreN9kG6D7lbnUCQUWziaBqJAFdjc2u2HmDkyvTan3A=";
          };
          # Alternative: Downloaded manually and place in this directory
          # src = ./pianoteq_linux_v754.7z;

          desktopItems = [
            (makeDesktopItem {
              name = "pianoteq9";
              desktopName = "Pianoteq 9";
              exec = "pianoteq9";
              icon = "pianoteq_icon_128";
            })
          ];

          nativeBuildInputs = [
            p7zip
            copyDesktopItems
          ];

          libPath = lib.makeLibraryPath [
            alsa-lib
            freetype
            xorg.libX11
            xorg.libXext
            stdenv.cc.cc.lib
            libjack2
            libglvnd
            lv2
          ];

          #unpackCmd = "7z x ${src}";

          # `runHook postInstall` is mandatory otherwise postInstall won't run
          installPhase = ''
            install -Dm 755 x86-64bit/Pianoteq\ 9 $out/bin/pianoteq9
            install -Dm 755 x86-64bit/Pianoteq\ 9.lv2/Pianoteq_9.so \
                            $out/lib/lv2/Pianoteq\ 9.lv2/Pianoteq_9.so
            patchelf --set-interpreter "$(< $NIX_CC/nix-support/dynamic-linker)" \
                     --set-rpath $libPath "$out/bin/pianoteq9"
            cd x86-64bit/Pianoteq\ 9.lv2/
            for i in *.ttl; do
                install -D "$i" "$out/lib/lv2/Pianoteq 9.lv2/$i"
            done
            runHook postInstall
          '';

          # This also works instead of the following
          # makeWrapper $out/bin/pianoteq7 $out/bin/pianoteq7_wrapped --prefix LD_LIBRARY_PATH : "$libPath"
          fixupPhase = '':'';

          # Runs copyDesktopItems hook.
          # Alternatively call copyDesktopItems manually in installPhase/fixupPhase
          postInstall = ''
            install -Dm 444 ${icon} $out/share/icons/hicolor/128x128/apps/pianoteq_icon_128.png
          '';

          meta = {
            homepage = "https://www.modartt.com/";
            description = "Pianoteq is a virtual instrument which in contrast to other virtual instruments is physically modelled and thus can simulate the playability and complex behaviour of real acoustic instruments. Because there are no samples, the file size is just a tiny fraction of that required by other virtual instruments.";
            platforms = lib.platforms.linux;
          };
        };
    in
    {
      inherit pianoteq9;
      packages.x86_64-linux.default = pianoteq9;
    };
}

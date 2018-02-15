{ nixpkgs
, filterGitSource
}:
let injectConfig = config: assets: nixpkgs.runCommand "inject-config" {} ''
      set -x
      cp -a "${assets}" $out
      chmod +w "$out"
      if ! mkdir $out/config; then
        2>&1 echo config directory already exists or could not be created
        exit 1
      fi
      cp -a "${config}"/* "$out/config"
    '';
in with nixpkgs.haskell.lib; {
  haskellPackage = self:
    self.callCabal2nix "obelisk-executable-config" (filterGitSource ./lookup) {};
  platforms = {
    android = {
      # Inject the given config directory into an android assets folder
      inject = injectConfig;
    };
    ios = {
      # Inject the given config directory into an iOS app
      inject = injectConfig;
    };
  };
}

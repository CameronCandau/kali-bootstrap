{ self, inputs, ... }:
{
  flake.homeConfigurations.kali =
    let
      system = "x86_64-linux";
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = {
        inherit inputs self;
      };
      modules = [
        self.homeModules.kaliHome
      ];
    };
}

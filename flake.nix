{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";

    nixcord.url = "github:FlameFlag/nixcord";

    home-manager.url = "github:nix-community/home-manager";

    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    vscode-server.url = "github:nix-community/nixos-vscode-server";
    vgpu4nixos.url = "github:mrzenc/vgpu4nixos";

    nix-gaming.url = "github:fufexan/nix-gaming";

    hyprcursor-phinger.url = "github:jappie3/hyprcursor-phinger";

    zen-browser.url = "github:0xc000022070/zen-browser-flake"; # broken :)))))

    spicetify-nix.url = "github:Gerg-L/spicetify-nix";

    turzx-player.url = "git+ssh://git@git.skver.space/skver/turzx-player.git";
  };

  outputs = inputs@{ self, nixpkgs, nixpkgs-stable, home-manager, sops-nix, vscode-server, vgpu4nixos, nix-gaming, ... }: {
    nixosConfigurations = {

      yoi = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/yoi/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.skver = import ./hosts/yoi/home.nix;
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
        ];
        specialArgs = { inherit inputs; };
      };

      yelena = nixpkgs-stable.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/yelena/configuration.nix
          vscode-server.nixosModules.default
          vgpu4nixos.nixosModules.host
        ];
        specialArgs = { inherit inputs; };
      };
    };
  };
}

# Base NixOS configuration for Magento 2 Docker servers
# Applied to both staging and production via nixos-rebuild --target-host
{ config, pkgs, lib, ... }:

let
  serverRole = builtins.getEnv "SERVER_ROLE"; # "staging" or "production"
  isStaging = serverRole == "staging";
in
{
  imports = [
  ];

  # System
  system.stateVersion = "24.11";
  time.timeZone = "Europe/Berlin";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Networking & Firewall
  networking = {
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 ];
    };
  };

  # SSH hardening
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
      KbdInteractiveAuthentication = false;
    };
  };

  # Docker
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" "--volumes" ];
    };
  };

  # Packages
  environment.systemPackages = with pkgs; [
    docker-compose
    git
    htop
    curl
    jq
    vim
  ];

  # Deploy user
  users.users.deploy = {
    isNormalUser = true;
    extraGroups = [ "docker" ];
    openssh.authorizedKeys.keys = [
      # Will be populated by the infra workflow
    ];
  };

  # Swap (useful for Magento's memory-hungry processes)
  swapDevices = [{
    device = "/swapfile";
    size = 4096; # 4 GB
  }];

  # Kernel tuning for OpenSearch
  boot.kernel.sysctl = {
    "vm.max_map_count" = 262144;
    "vm.swappiness" = 10;
  };

  # Automatic security updates
  system.autoUpgrade = {
    enable = true;
    allowReboot = false; # Don't reboot automatically on production
    dates = "04:00";
  };
}

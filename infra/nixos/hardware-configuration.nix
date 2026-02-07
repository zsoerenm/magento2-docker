# Hardware configuration for Hetzner Cloud VPS
# This is a placeholder — nixos-infect generates the real one.
# It will be replaced during server provisioning.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };
}

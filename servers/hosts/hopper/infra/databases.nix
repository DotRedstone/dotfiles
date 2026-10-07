# ---
# Module: Hopper Databases
# Description: Host-level database engines for Hopper native services
# Scope: Host
# ---

{ ... }: {
  dot.services = {
    mongodb.enable = true;
    mysql.enable = true;
    postgresql.enable = true;
    redis.enable = true;
  };
}

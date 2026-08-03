{ ... }:

{
  services.anubis.instances = {
    forgejo = {
      settings = {
        BIND = "0.0.0.0:9301";
        BIND_NETWORK = "tcp";
        TARGET = "http://127.0.0.1:3001";
      };
    };

    skverspace = {
      settings = {
        BIND = "0.0.0.0:9007";
        BIND_NETWORK = "tcp";
        TARGET = "http://127.0.0.1:8007";
      };
    };
  };
}

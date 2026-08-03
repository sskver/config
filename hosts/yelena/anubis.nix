{ ... }:

{
  # Only overrides `thresholds` (and re-states the other top-level policy
  # sections explicitly, matching Anubis's own shipped defaults) on top of the
  # module's default bot rules (policy.useDefaultBotRules, left at its default
  # of true - pulls in (data)/meta/default-config.yaml). The sole deliberate
  # change: moderate-suspicion's difficulty raised 2 -> 4. Kept in sync with
  # the equivalent botPolicy.yaml on offsite's mail stack.
  services.anubis.defaultOptions.policy.settings = {
    dnsbl = false;

    honeypot = {
      enabled = true;
      implementation = "naive";
    };

    openGraph = {
      enabled = false;
      considerHost = false;
      ttl = "24h";
    };

    status_codes = {
      CHALLENGE = 200;
      DENY = 200;
    };

    store = {
      backend = "memory";
      parameters = { };
    };

    thresholds = [
      {
        name = "minimal-suspicion";
        expression = "weight <= 0";
        action = "ALLOW";
      }
      {
        name = "mild-suspicion";
        expression.all = [
          "weight > 0"
          "weight < 10"
        ];
        action = "CHALLENGE";
        challenge = {
          algorithm = "metarefresh";
          difficulty = 1;
        };
      }
      {
        name = "moderate-suspicion";
        expression.all = [
          "weight >= 10"
          "weight < 20"
        ];
        action = "CHALLENGE";
        challenge = {
          algorithm = "fast";
          difficulty = 4; # bumped from stock 2
        };
      }
      {
        name = "mild-proof-of-work";
        expression.all = [
          "weight >= 20"
          "weight < 30"
        ];
        action = "CHALLENGE";
        challenge = {
          algorithm = "fast";
          difficulty = 4;
        };
      }
      {
        name = "extreme-suspicion";
        expression = "weight >= 30";
        action = "CHALLENGE";
        challenge = {
          algorithm = "fast";
          difficulty = 6;
        };
      }
    ];
  };

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

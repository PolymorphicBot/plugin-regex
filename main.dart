import "package:polymorphic_bot/api.dart";
import "package:irc/irc.dart" show Color;
import "package:quiver/pattern.dart";

BotConnector bot;
EventManager eventManager;

void main(_, port) {
  bot = new BotConnector(port);
  eventManager = bot.createEventManager();


  eventManager.on("message").listen((data) {
    String network = data['network'];
    String target = data['target'];
    String message = data['message'];
    String user = data['from'];

    void reply(String message, {bool prefix: true, String prefixContent: "RegEx"}) {
      bot.message(network, target, (prefix ? "[${Color.BLUE}${prefixContent}${Color.RESET}] " : "") + message);
    }

    if (message.startsWith("s/") && message.length > 3) {
      var msg = message.substring(2); // skip "s/"
      var first = true;
      var escaped = true;
      var reverse = false;

      var now = new DateTime.now();

      if (now.month == DateTime.APRIL && now.day == 1) {
        reverse = true;
        return;
      }

      if (msg.endsWith("/")) {
        msg = msg.substring(0, msg.length - 1);
      } else if (msg.endsWith("/g")) {
        msg = msg.substring(0, msg.length - 2);
        first = false;
      } else if (msg.endsWith("/n")) {
        msg = msg.substring(0, msg.length - 2);
        escaped = false;
      }

      var index = msg.indexOf("/");
      var expr = msg.substring(0, index);
      var replacement = msg.substring(index + 1, msg.length);

      String aExpr;
      if (escaped) {
        aExpr = escapeRegex(expr);
      } else {
        aExpr = expr;
      }
      if (reverse) replacement = new String.fromCharCodes(replacement.codeUnits.reversed);

      var regex = new RegExp(aExpr);

      bot.get("request", {
        "plugin": "buffer",
        "command": "channel-buffer",
        "data": {
          "network": network,
          "channel": target
        }
      }).then((response) {
        List<Map<String, dynamic>> entries = response['entries'];

        for (Map<String, dynamic> entry in entries) {
          if (regex.hasMatch(entry['message'])) {
            String dat_msg = entry['message'];
            String new_msg = first ? dat_msg.replaceFirst(regex, replacement) : dat_msg.replaceAll(regex, replacement);

            reply(entry['from'] + ": " + new_msg);

            bot.get("request", {
              "command": "add-to-buffer",
              "plugin": "buffer",
              "data": {
                "network": entry['network'],
                "target": entry['target'],
                "message": new_msg,
                "from": entry['from']
              }
            });
            return;
          }
        }
        reply("ERROR: No Match Found for expression '${expr}'");
      });
    }
  });
}

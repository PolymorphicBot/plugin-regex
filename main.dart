import "package:polymorphic_bot/api.dart";
import "package:irc/client.dart" show Color;
import "package:quiver/pattern.dart";

Plugin plugin;
BotConnector bot;

void main(args, port) {
  plugin = polymorphic(args, port);
  
  bot = plugin.getBot();

  plugin.on("message").listen((data) {
    String network = data['network'];
    String target = data['target'];
    String message = data['message'];
    String user = data['from'];

    void reply(String message, {bool prefix: true, String prefixContent: "RegEx"}) {
      bot.sendMessage(network, target, (prefix ? "[${Color.BLUE}${prefixContent}${Color.RESET}] " : "") + message);
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

      RegExp regex;
      
      try {
        regex = new RegExp(aExpr);
      } on FormatException catch (e) {
        reply("ERROR: Invalid Regular Expression: ${e.message}");
        return;
      }
      
      plugin.callRemoteMethod("buffer", "getChannelBuffer", {
        "network": network,
        "channel": target
      }).then((List<Map<String, dynamic>> entries) {
        for (Map<String, dynamic> entry in entries) {
          if (regex.hasMatch(entry['message'])) {
            String datMsg = entry['message'];
            String newMsg = first ? datMsg.replaceFirst(regex, replacement) : datMsg.replaceAll(regex, replacement);

            reply(entry['from'] + ": " + newMsg);

            plugin.callRemoteMethod("buffer", "addToBuffer", {
              "network": entry['network'],
              "target": entry['target'],
              "message": newMsg,
              "from": entry['from']
            });
            return;
          }
        }
        reply("ERROR: No Match Found for expression '${expr}'");
      });
    }
  });
}



import 'dart:io';

import '../../enums/socks_connection_type.dart';
import '../shared/proxy_settings.dart';
import 'socket_connection_task.dart';
import 'socks_client.dart';

class SocksTCPClient extends SocksSocket {
  SocksTCPClient._internal(Socket socket) : super.protected(socket, SocksConnectionType.connect);

  /// Assign http client connection factory to proxy connection.
  static void assignToHttpClient(
    HttpClient httpClient,
    List<ProxySettings> proxies,
  ) => assignToHttpClientWithSecureOptions(httpClient, proxies);

  /// Assign http client connection factory to proxy connection.
  /// 
  /// Applies [host], [context], [onBadCertificate],
  /// [keyLog] and [supportedProtocols] to [SecureSocket] if 
  /// connection is tls-over-http
  static void assignToHttpClientWithSecureOptions(
    HttpClient httpClient,
    List<ProxySettings> proxies,
    {
      dynamic host,
      SecurityContext? context,
      bool Function(X509Certificate certificate)? onBadCertificate,
      void Function(String line)? keyLog,
      List<String>? supportedProtocols,
    }
  ) {
    httpClient.connectionFactory =
      (uri, proxyHost, proxyPort) async {
        // Returns instance of SocksSocket which implements Socket
        final client = SocksTCPClient.connect(
          proxies,
          InternetAddress(uri.host, type: InternetAddressType.unix),
          uri.port,
        );
        
        // Secure connection after establishing Socks connection
        if(uri.scheme == 'https')
          return SocketConnectionTask((await client).secure(uri.host, 
            context: context,
            onBadCertificate: onBadCertificate,
            keyLog: keyLog,
            supportedProtocols: supportedProtocols,
          ),);

        // SocketConnectionTask implements ConnectionTask<Socket>
        return SocketConnectionTask(client);
      };
  }

  /// Connects proxy client to given [proxies] with exit point of [host]\:[port].
  static Future<SocksSocket> connect(
    List<ProxySettings> proxies,
    InternetAddress host,
    int port,
  ) async {
    final InternetAddress address;
    if (host.type == InternetAddressType.unix) {
      // When the proxy transport is a Unix socket, keep the target as a
      // domain-type address (ATYP=0x03) so the proxy server resolves DNS.
      // Otherwise resolve locally and send an IP (ATYP=0x01/0x04).
      final proxyIsUnix = proxies.isNotEmpty &&
          proxies.first.host is InternetAddress &&
          (proxies.first.host as InternetAddress).type ==
              InternetAddressType.unix;
      address = proxyIsUnix
          ? host // stays unix-type → _handleCommand sends ATYP=0x03
          : (await InternetAddress.lookup(host.address))[0];
    } else {
      address = host;
    }

    final client = await SocksSocket.initialize(proxies, address, port, SocksConnectionType.connect);
    return client.socket;
  }
}

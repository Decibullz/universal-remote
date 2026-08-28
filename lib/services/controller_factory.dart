import 'package:universal_tv_remote/controllers/lg_webos_controller.dart';
import 'package:universal_tv_remote/controllers/roku_controller.dart';
import 'package:universal_tv_remote/controllers/tv_remote_controller.dart';
import 'package:universal_tv_remote/controllers/vizio_controller.dart';
import 'package:universal_tv_remote/models/tv_brand.dart';
import 'package:universal_tv_remote/models/tv_device.dart';
import 'package:universal_tv_remote/services/credential_store.dart';

class ControllerFactory {
  const ControllerFactory._();

  static TvRemoteController create(TvDevice device) {
    return switch (device.brand) {
      TvBrand.lgWebOs =>
        LgWebOsController(device, CredentialStore.instance),
      TvBrand.roku => RokuController(device),
      TvBrand.vizio =>
        VizioController(device, CredentialStore.instance),
    };
  }
}

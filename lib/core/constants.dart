class Constants {
  static const String deviceName = "HC-08";
  static const List<String> supportedDeviceName = ["HC-08", "KN-08"];
  static const String deviceServiceId = "0000ffe0-0000-1000-8000-00805f9b34fb";
  static const String deviceCharacteristicId = "0000ffe1-0000-1000-8000-00805f9b34fb";
}

class Commands {
  static const String getInfo = "#1@";
  static const String keyUp = "#5K1@";
  static const String keyDown = "#5K1@";
  static const String keyRight = "#5K3@";
  static const String keyLeft = "#5K4@";
  static const String keyOk = "#5K5@";
  static const String keyReturn = "#5K6@";
  static const String keyStart = "#4K7@";
  static const String keySet = "#5K8@";
  static const String keyFanzhuan = "#5K9@";
  static const String keyPower = "#5K0@";
  static const String dose1 = "#2C1T1000@";
  static const String query = "#3@";
  static String dose(int time) {
    if (time > 1800) throw Exception("Invalid time range");

    return "#2C1T$time@";
  }

  static const String queryStatus = "#3@";
  static const String endTreatment = "#4J1@";
  static const String pauseTreatment = "#4J0@";
  static const String verifyComm = "#9Y1@";
}

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';

class NfcReadCubit extends Cubit<String>{
  bool isStartSession = false;
  NfcReadCubit() : super("");

  init() async {
    final nfcIsAvailable = await NfcManager.instance.isAvailable();
    if (nfcIsAvailable) {
      // Start Session
      if(isStartSession){
        NfcManager.instance.stopSession();
      }
      isStartSession = true;
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          String data = "tag.data";
          data = data + "\n";
          try {
            tag.data.forEach((key, value) {
              data = data + key + "  " + value.toString();
              data = data + "\n";
            });
          } catch (e) {}

          try {
            Ndef? ndef = Ndef.from(tag);
            if (ndef != null) {
              data = data +"ndef.additionalData";
              data = data + "\n";
              ndef.additionalData.forEach((key, value) {
                data = data + key + "  " + value.toString();
                data = data + "\n";
              });

              data = data +"ndefMessage.records";
              data = data + "\n";
              NdefMessage ndefMessage = await ndef.read();
              ndefMessage.records.forEach((element) {
                String s = String.fromCharCodes(element.payload);
                data = data + s;
                data = data + "\n";
              });
            }
          } catch (e) {}

          if(Platform.isAndroid) {
            try {
              NfcV? nfcV = NfcV.from(tag);
              if (nfcV != null) {
                data = data + "nfcV.identifier";
                data = data + "\n";
                data = data + String.fromCharCodes(nfcV.identifier);
                data = data + "\n";
              }
            } catch (e) {}
          }

          if(Platform.isIOS) {
            try {
              Iso15693? iso15693 = Iso15693.from(tag);
              if (iso15693 != null) {
                data = data + "iso15693.identifier";
                data = data + "\n";
                data = data + String.fromCharCodes(iso15693.identifier);
                data = data + "\n";
              }
            } catch (e) {}
          }

          if(Platform.isAndroid) {
            _nfcV(data, tag);
          }

          if(Platform.isIOS) {
            _iso15693(data, tag);
          }

          emit(data);

          isStartSession = false;
          NfcManager.instance.stopSession();
        },
      );
    }

    // Stop Session
  }

  @override
  Future<void> close() {
    if (isStartSession) {
      isStartSession = false;
      NfcManager.instance.stopSession();
    }
    return super.close();
  }

  _nfcV(String data, NfcTag tag) async {
    try {
      NfcV? nfcV = NfcV.from(tag);
      if (nfcV != null) {
        data = data + "_nfcV";
        data = data + "\n";
        final tagUid = nfcV.identifier;
        final userdata1 = await nfcV.transceive(
            data: Uint8List.fromList([0x20, 0x20, ...tagUid, 0 & 0x0ff]));
        final userdata2 = await nfcV.transceive(
            data: Uint8List.fromList([0x20, 0x20, ...tagUid, 1 & 0x0ff]));
        final userdata = Uint8List(8);
        List.copyRange(userdata, 0, userdata1, 1, 5);
        List.copyRange(userdata, 4, userdata2, 1, 5);
        data = data +  userdata.toHexString();
        data = data + "\n";
      }
    } catch (e) {
      data = data +  "error " + e.toString();
      data = data + "\n";
    }
  }

  _iso15693(String data, NfcTag tag) async {
    try {
      Iso15693? iso15693 = Iso15693.from(tag);
      if (iso15693 != null) {
        data = data + "_iso15693";
        data = data + "\n";
        final userdata1 = await iso15693.readSingleBlock(requestFlags: {
          Iso15693RequestFlag.address,
          Iso15693RequestFlag.dualSubCarriers,
          Iso15693RequestFlag.highDataRate,
          Iso15693RequestFlag.option,
          Iso15693RequestFlag.protocolExtension,
          Iso15693RequestFlag.select
        }, blockNumber: 0);
        final userdata2 = await iso15693.readSingleBlock(requestFlags: {
          Iso15693RequestFlag.address,
          Iso15693RequestFlag.dualSubCarriers,
          Iso15693RequestFlag.highDataRate,
          Iso15693RequestFlag.option,
          Iso15693RequestFlag.protocolExtension,
          Iso15693RequestFlag.select
        }, blockNumber: 1);
        final userdata = Uint8List(8);
        List.copyRange(userdata, 0, userdata1, 1, 5);
        List.copyRange(userdata, 4, userdata2, 1, 5);
        data = data +  userdata.toHexString();
        data = data + "\n";
      }
    } catch (e) {
      data = data +  "error " + e.toString();
      data = data + "\n";
    }
  }
}


extension IntExtension on int {
  String toHexString() {
    return '0x' + toRadixString(16).padLeft(2, '0').toUpperCase();
  }
}

extension Uint8ListExtension on Uint8List {
  String toHexString({String empty = '-', String separator = ' '}) {
    return isEmpty ? empty : map((e) => e.toHexString()).join(separator);
  }
}

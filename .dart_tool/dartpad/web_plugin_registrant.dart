// Flutter web plugin registrant file.
//
// Generated file. Do not edit.
//

// @dart = 2.13
// ignore_for_file: type=lint

import 'package:audio_session/audio_session_web.dart';
import 'package:cloud_firestore_web/cloud_firestore_web.dart';
import 'package:firebase_auth_web/firebase_auth_web.dart';
import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:flutter_sound_web/flutter_sound_web.dart';
import 'package:flutter_tts/flutter_tts_web.dart';
import 'package:just_audio_web/just_audio_web.dart';
import 'package:mobile_scanner/src/web/mobile_scanner_web.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

void registerPlugins([final Registrar? pluginRegistrar]) {
  final Registrar registrar = pluginRegistrar ?? webPluginRegistrar;
  AudioSessionWeb.registerWith(registrar);
  FirebaseFirestoreWeb.registerWith(registrar);
  FirebaseAuthWeb.registerWith(registrar);
  FirebaseCoreWeb.registerWith(registrar);
  FlutterSoundPlugin.registerWith(registrar);
  FlutterTtsPlugin.registerWith(registrar);
  JustAudioPlugin.registerWith(registrar);
  MobileScannerWeb.registerWith(registrar);
  registrar.registerMessageHandler();
}

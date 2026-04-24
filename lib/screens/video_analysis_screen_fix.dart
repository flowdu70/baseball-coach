import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/video_analysis_service.dart';
import '../services/camera_capability_service.dart';
import '../services/video_importer_service.dart';
import '../services/physics_service.dart';
import '../models/throw_record.dart';
import '../providers/throw_provider.dart';
import '../providers/player_provider.dart';

// rest of file stays same

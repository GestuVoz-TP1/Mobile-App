import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'application/auth_service.dart';
import 'application/communication_service.dart';
import 'application/gesture_service.dart';
import 'application/interaction_service.dart';
import 'application/privacy_service.dart';
import 'application/profile_service.dart';
import 'application/reporting_service.dart';
import 'application/settings_service.dart';
import 'domain/ml.dart';
import 'infrastructure/camera/camera_service.dart';
import 'infrastructure/ml/test_mode_gesture_recognition_service.dart';
import 'infrastructure/persistence/csv_report_exporter.dart';
import 'infrastructure/persistence/database.dart';
import 'infrastructure/persistence/legacy_cleanup.dart';
import 'infrastructure/persistence/repositories.dart';
import 'infrastructure/remote/api_client.dart';
import 'infrastructure/remote/firebase_auth_gateway.dart';
import 'infrastructure/sync/sync_service.dart';
import 'infrastructure/security/secret_hasher_impl.dart';
import 'infrastructure/tts/tts_service.dart';
import 'presentation/controllers/capture_controller.dart';
import 'presentation/controllers/communication_controller.dart';
import 'presentation/controllers/reporting_controller.dart';
import 'presentation/controllers/session_controller.dart';

/// Composition root (raiz de composicion). Cablea infraestructura ->
/// aplicacion -> presentacion. Es el UNICO lugar que conoce las
/// implementaciones concretas.
class Di {
  Di._(this._providers);
  final List<SingleChildWidget> _providers;
  List<SingleChildWidget> get providers => _providers;

  static Future<Di> build() async {
    // Fotos del antiguo modulo de expresion facial.
    await removeLegacyTrainingImages();

    final db = await GestuVozDatabase.open();

    // --- Repositorios SQLite ---
    final authRepo = SqliteAuthRepository(db);
    final profileRepo = SqliteChildProfileRepository(db);
    final pictoRepo = SqlitePictogramRepository(db);
    final gestureRepo = SqliteGestureRepository(db);
    final interactionRepo = SqliteInteractionRepository(db);
    final voiceRepo = SqliteVoiceConfigurationRepository(db);
    final consentRepo = SqliteConsentRepository(db);

    // Reconocimiento de gestos: reconocedor de prueba mientras no exista el
    // modelo entrenado. Para el modelo real:
    // TensorFlowLiteGestureRecognitionService().
    final GestureRecognitionService recognizer =
        TestModeGestureRecognitionService();

    final tts = TtsService();
    final camera = CameraService();

    // --- Servicios de aplicacion ---
    // Acceso con Firebase Authentication (OB2 RT-04) y sincronizacion con el
    // backend Django por HTTPS/REST (OB2 RF-11).
    final firebaseAuth = FirebaseAuthGateway();
    final auth = AuthService(authRepo, Sha256SecretHasher(), firebaseAuth);
    final sync = SyncService(
      db,
      ApiClient(token: firebaseAuth.idToken),
      connectivity: Connectivity(),
    );
    final profiles = ProfileService(profileRepo, gestureRepo);
    final privacy = PrivacyService(consentRepo);
    final settings = SettingsService(voiceRepo);
    final communication = CommunicationService(pictoRepo);
    final interactions = InteractionService(interactionRepo, consentRepo);
    final gestures = GestureService(recognizer, gestureRepo, pictoRepo);
    final reporting = ReportingService(interactionRepo, CsvReportExporter());

    // --- Controladores de presentacion ---
    final session = SessionController(
      auth: auth,
      profiles: profiles,
      privacy: privacy,
      settings: settings,
      tts: tts,
    )
      ..afterSignIn = (account) async {
        try {
          // Nuevo telefono o reinstalacion: recupera los datos del tutor.
          await sync.pullAll(account.id!);
        } finally {
          sync.start(account.id!);
        }
      }
      ..afterSignOut = sync.stop;
    await session.bootstrap();

    final communicationCtrl = CommunicationController(
      communication: communication,
      interactions: interactions,
      session: session,
      tts: tts,
    );
    final captureCtrl = CaptureController(
      camera: camera,
      gestures: gestures,
      interactions: interactions,
      session: session,
      tts: tts,
    );
    final reportingCtrl = ReportingController(reporting, session);

    return Di._([
      Provider<CommunicationService>.value(value: communication),
      Provider<GestureService>.value(value: gestures),
      Provider<ReportingService>.value(value: reporting),
      Provider<CameraService>.value(value: camera),
      Provider<SyncService>.value(value: sync),
      ChangeNotifierProvider<SessionController>.value(value: session),
      ChangeNotifierProvider<CommunicationController>.value(
          value: communicationCtrl),
      ChangeNotifierProvider<CaptureController>.value(value: captureCtrl),
      ChangeNotifierProvider<ReportingController>.value(value: reportingCtrl),
    ]);
  }
}

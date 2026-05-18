import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'firebase_options.dart';

// creamos el canal de notificaciones para android con prioridad maxima
final AndroidNotificationChannel channel = AndroidNotificationChannel(
  'radio_notifications',
  'Notificaciones de Radio',
  description: 'Avisos de nuevos programas',
  importance: Importance.max,
);

// iniciamos el plugin para las notificaciones locales del dispositivo
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  // obligatorio en flutter al usar async antes del runapp
  WidgetsFlutterBinding.ensureInitialized();

  // inicializamos firebase con las opciones de nuestro proyecto
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // configuramos el reproductor de audio para que funcione en segundo plano
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Reproducción de Audio',
    androidNotificationOngoing: true,
  );

  // creamos de forma fisica el canal de notificaciones en el sistema android
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  // configuramos para que salgan los avisos visuales y sonido si la app esta abierta
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // escuchamos los mensajes que llegan de firebase cloud messaging
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    // si nos llega una notificacion valida, la mostramos en el movil
    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        id: notification.hashCode,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: '@mipmap/launcher_icon',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    }
  });

  runApp(OndaUrbanitaApp());
}

// clase principal que monta el menu de rutas y el estilo visual de la app
class OndaUrbanitaApp extends StatelessWidget {
  const OndaUrbanitaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Onda Urbanita",
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: Colors.white,
      ),
      // definimos la pantalla de inicio por defecto
      routes: {'/': (context) => HomeScreen()},
      initialRoute: '/',
    );
  }
}

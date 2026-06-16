import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'database/database_helper.dart';
import 'firebase_options.dart';
import 'repositories/module_repository.dart';
import 'repositories/planner_event_repository.dart';
import 'repositories/session_repository.dart';
import 'repositories/task_repository.dart';
import 'screens/home_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/login_screen.dart';
import 'screens/modules_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/timetable_screen.dart';
import 'services/notification_service.dart';
import 'services/planner_service.dart';
import 'state/app_state.dart';
import 'state/auth_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService.instance.init();

  final dbHelper = DatabaseHelper.instance;

  final moduleRepository = ModuleRepository(dbHelper: dbHelper);
  final taskRepository = TaskRepository(dbHelper: dbHelper);
  final sessionRepository = SessionRepository(dbHelper: dbHelper);
  final plannerEventRepository = PlannerEventRepository(dbHelper: dbHelper);

  final plannerService = PlannerService(
    taskRepository: taskRepository,
    sessionRepository: sessionRepository,
    plannerEventRepository: plannerEventRepository,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppState(
            moduleRepository: moduleRepository,
            taskRepository: taskRepository,
            sessionRepository: sessionRepository,
            plannerEventRepository: plannerEventRepository,
            plannerService: plannerService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthState(
            dbHelper: dbHelper,
            notificationService: NotificationService.instance,
          )..init(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Task & Timetable Planner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const _AppEntryPoint(),
    );
  }
}

class _AppEntryPoint extends StatefulWidget {
  const _AppEntryPoint();

  @override
  State<_AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<_AppEntryPoint> {
  int? _lastSyncedUserId;
  bool _hasStartedSync = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncUserContextIfNeeded();
  }

  Future<void> _syncUserContextIfNeeded() async {
    final authState = context.read<AuthState>();
    final appState = context.read<AppState>();
    final authUserId = authState.currentUserId;

    if (_hasStartedSync && _lastSyncedUserId == authUserId) {
      return;
    }

    _hasStartedSync = true;
    _lastSyncedUserId = authUserId;

    await appState.setCurrentUserContext(authUserId);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();

    if (authState.isInitialising) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncUserContextIfNeeded();
      }
    });

    if (!authState.isLoggedIn) {
      return const LoginScreen();
    }

    return const MainNavigationScreen();
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  static const List<String> _titles = [
    'Dashboard',
    'Tasks',
    'Timetable',
    'Insights',
    'Modules',
  ];

  static const List<Widget> _screenWidgets = [
    HomeScreen(),
    TasksScreen(),
    TimetableScreen(),
    InsightsScreen(),
    ModulesScreen(),
  ];

  Future<void> _handleLogout(BuildContext context) async {
    await context.read<AuthState>().logout();
    await context.read<AppState>().setCurrentUserContext(null);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Logged out successfully.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await _handleLogout(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                value: 'account',
                child: Text(
                  authState.currentUserEmail ?? 'Signed in',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _screenWidgets[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Timetable',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'Modules',
          ),
        ],
      ),
    );
  }
}
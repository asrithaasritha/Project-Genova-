import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'models/memory.dart';
import 'services/pdf_service.dart';
import 'services/summary_service.dart';
import 'screens/export_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/memory_list_screen.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Set preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    runApp(const MyApp());
  }, (error, stack) {
    print('Error in main: $error');
    print('Stack trace: $stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memory Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MemoryAssistantScreen(),
    );
  }
}


class MemoryAssistantScreen extends StatefulWidget {
  const MemoryAssistantScreen({super.key});

  @override
  State<MemoryAssistantScreen> createState() => _MemoryAssistantScreenState();
}

class _MemoryAssistantScreenState extends State<MemoryAssistantScreen>
    with TickerProviderStateMixin {
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  String _text = '';
  String _status = 'Initializing...';
  List<Memory> _memories = [];
  String _currentCategory = 'Personal';
  bool _isInitialized = false;
  String _errorMessage = '';
  bool _isLoading = true;
  String _lastMemoryText = '';
  bool _isProcessing = false;
  
  final List<String> _categories = [
    'Personal',
    'Work',
    'Health',
    'Shopping',
    'Ideas',
    'Important',
    'General'
  ];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      print('Starting app initialization...');
      
      // Initialize animations first
      _pulseController = AnimationController(
        duration: const Duration(seconds: 1),
        vsync: this,
      );
      _pulseAnimation = Tween<double>(
        begin: 1.0,
        end: 1.2,
      ).animate(CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ));

      _waveController = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      );
      _waveAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _waveController,
        curve: Curves.easeInOut,
      ));
      print('Animations initialized');

      // Initialize speech and TTS
      _speech = stt.SpeechToText();
      _flutterTts = FlutterTts();
      print('Speech and TTS initialized');

      // Initialize TTS
      await _initializeTts();
      print('TTS initialized');
      
      // Load memories
      await _loadMemories();
      print('Memories loaded');
      
      // Request permissions
      await _requestPermissions();
      print('Permissions requested');
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
          _status = 'Ready to listen';
        });
      }
      print('Initialization complete');
    } catch (e, stackTrace) {
      print('Initialization error: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'Initialization error: $e';
          _isInitialized = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _speech.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initializeTts() async {
    try {
      print('Starting TTS initialization...');
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      print('TTS initialization successful');
    } catch (e, stackTrace) {
      print('TTS initialization error: $e');
      print('TTS stack trace: $stackTrace');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      print('Requesting microphone permission...');
      final status = await Permission.microphone.request();
      print('Microphone permission status: $status');
      if (status.isDenied) {
        print('Microphone permission denied');
        _showPermissionDialog();
      }
    } catch (e, stackTrace) {
      print('Permission request error: $e');
      print('Permission stack trace: $stackTrace');
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Permission'),
        content: const Text('This app needs microphone permission to record your voice commands.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMemories() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/memories.json');
      
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonData = json.decode(contents);
        setState(() {
          _memories = jsonData.map((item) => Memory.fromJson(item)).toList();
        });
      }
    } catch (e) {
      print('Error loading memories: $e');
    }
  }

  Future<void> _saveMemoriesToFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/memories.json');
      final jsonData = _memories.map((memory) => memory.toJson()).toList();
      await file.writeAsString(json.encode(jsonData));
    } catch (e) {
      print('Error saving memories: $e');
    }
  }

  Future<void> _speak(String text) async {
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      print('TTS error: $e');
    }
  }

  Future<void> _listen() async {
    if (!_isListening) {
      try {
        bool available = await _speech.initialize(
          onStatus: (val) {
            setState(() {
              _status = val;
            });
            if (val == 'done' || val == 'notListening') {
              _stopListening();
            }
          },
          onError: (val) {
            setState(() {
              _status = 'Error: ${val.errorMsg}';
              _isListening = false;
            });
            _stopAnimation();
          },
        );

        if (available) {
          setState(() {
            _isListening = true;
            _status = 'Listening...';
            _text = '';
          });
          _startAnimation();
          
          _speech.listen(
            onResult: (val) {
              setState(() {
                _text = val.recognizedWords;
              });
              
              if (val.finalResult) {
                _lastMemoryText = val.recognizedWords;
                _processCommand(val.recognizedWords);
                _stopListening();
              }
            },
            listenFor: const Duration(seconds: 30),
            pauseFor: const Duration(seconds: 3),
            partialResults: true,
            localeId: "en_US",
            cancelOnError: true,
          );
        } else {
          setState(() {
            _status = 'Speech recognition not available';
          });
        }
      } catch (e) {
        setState(() {
          _status = 'Error starting speech recognition';
          _isListening = false;
        });
        print('Listen error: $e');
      }
    } else {
      _stopListening();
    }
  }

  void _stopListening() {
    if (_isListening) {
      try {
        _speech.stop();
        setState(() {
          _isListening = false;
          _status = 'Processing...';
        });
        _stopAnimation();
      } catch (e) {
        setState(() {
          _isListening = false;
          _status = 'Error stopping speech recognition';
        });
        print('Stop listening error: $e');
      }
    }
  }

  void _startAnimation() {
    try {
      _pulseController.repeat(reverse: true);
      _waveController.repeat();
    } catch (e) {
      print('Animation error: $e');
    }
  }

  void _stopAnimation() {
    try {
      _pulseController.stop();
      _waveController.stop();
      _pulseController.reset();
      _waveController.reset();
    } catch (e) {
      print('Stop animation error: $e');
    }
  }

  // **IMPROVED COMMAND PROCESSING FUNCTION**
  Future<void> _processCommand(String command) async {
    final lowerCommand = command.toLowerCase().trim();
    
    setState(() {
      _isProcessing = true;
      _status = 'Processing command...';
    });

    try {
      // Handle save commands with category
      if (lowerCommand.contains('save this as') || lowerCommand.contains('save as')) {
        await _saveWithCategory(command);
      }
      // Handle show memories commands
      else if (lowerCommand.contains('show memories') || 
               lowerCommand.contains('list memories') ||
               lowerCommand.contains('show memory')) {
        await _handleShowMemories(lowerCommand);
      }
      // Handle category-specific memory requests
      else if (lowerCommand.contains('show my') && lowerCommand.contains('memories')) {
        await _handleCategoryMemories(lowerCommand);
      }
      // Handle delete commands
      else if (lowerCommand.contains('delete last') || lowerCommand.contains('remove last')) {
        await _deleteLastMemory();
      }
      else if (lowerCommand.contains('delete all') || lowerCommand.contains('clear all')) {
        await _deleteAllMemories();
      }
      // Handle today's memories
      else if (lowerCommand.contains('what did i do today') || 
               lowerCommand.contains('today\'s memories') ||
               lowerCommand.contains('daily summary')) {
        await _showTodaysMemories();
      }
      // Handle help
      else if (lowerCommand.contains('help') || lowerCommand.contains('what can you do')) {
        await _provideHelp();
      }
      // Handle category setting
      else if (lowerCommand.contains('set category')) {
        await _setCategory(command);
      }
      // Handle repeat
      else if (lowerCommand.contains('repeat that') || lowerCommand.contains('repeat')) {
        await _repeatLast();
      }
      // Add these cases to your _processCommand method:

      else if (lowerCommand.contains('show analytics') || 
              lowerCommand.contains('show insights') ||
              lowerCommand.contains('show summary')) {
        await _showAnalytics();
      }
      else if (lowerCommand.contains('export to pdf') || 
              lowerCommand.contains('export pdf') ||
              lowerCommand.contains('generate pdf')) {
        await _exportToPdf();
      }
      else if (lowerCommand.contains('export') && lowerCommand.contains('pdf')) {
        // Extract category if specified
        String? category;
        for (String cat in _categories) {
          if (lowerCommand.contains(cat.toLowerCase())) {
            category = cat;
            break;
          }
        }
        await _exportToPdf(category: category);
      }

      // Default: save as current category
      else {
        await _saveMemory(command, _currentCategory);
      }
    } catch (e) {
      setState(() {
        _status = 'Error processing command';
      });
      await _speak("Sorry, I encountered an error processing your command.");
      print('Process command error: $e');
    }

    setState(() {
      _isProcessing = false;
      _status = 'Ready to listen';
      _text = '';
    });
  }

  // **IMPROVED SAVE WITH CATEGORY FUNCTION**
  Future<void> _saveWithCategory(String command) async {
    final lowerCommand = command.toLowerCase();
    String memoryText = command;
    String category = _currentCategory;

    // Extract category first
    for (String cat in _categories) {
      if (lowerCommand.contains(cat.toLowerCase())) {
        category = cat;
        break;
      }
    }

    // Improved text extraction logic
    if (lowerCommand.contains('save this as')) {
      final parts = command.split(RegExp(r'save this as', caseSensitive: false));
      if (parts.isNotEmpty) {
        memoryText = parts[0].trim();
        
        if (parts.length > 1) {
          final categoryPart = parts[1].trim();
          String foundCategory = _categories.firstWhere(
            (c) => c.toLowerCase() == categoryPart.toLowerCase(),
            orElse: () => category,
          );
          category = foundCategory;
        }
      } 

    } else if (lowerCommand.contains('save as')) {
      final parts = command.split(RegExp(r'save as', caseSensitive: false));
      if (parts.isNotEmpty) {
        memoryText = parts[0].trim();
        
        if (parts.length > 1) {
          final categoryPart = parts[1].trim();
          String foundCategory = _categories.firstWhere(
            (c) => c.toLowerCase() == categoryPart.toLowerCase(),
            orElse: () => category,
          );
          category = foundCategory;
        }
      }
    }

    if (memoryText.isEmpty || memoryText == command) {
      memoryText = command
          .replaceAll(RegExp(r'save (this )?as \w+', caseSensitive: false), '')
          .trim();
      
      if (memoryText.isEmpty) {
        await _speak("I couldn't understand what you want to save. Please try again.");
        return;
      }
    }

    await _saveMemory(memoryText, category);
  }

  Future<void> _saveMemory(String text, String category) async {
    try {
      final memory = Memory(
      text: text,
      timestamp: DateTime.now(),
      category: category,
      // The id will be auto-generated by the Memory class
    );


      setState(() {
        _memories.insert(0, memory);
      });

      await _saveMemoriesToFile();
      await _speak("Memory saved in $category category: $text");
      
      HapticFeedback.lightImpact();
      _showSnackBar('Memory saved in $category category', isError: false);
    } catch (e) {
      print('Save memory error: $e');
      await _speak("Error saving memory");
    }
  }

  // **IMPROVED SHOW MEMORIES FUNCTION**
  Future<void> _handleShowMemories(String command) async {
    if (_memories.isEmpty) {
      await _speak("You don't have any memories saved yet.");
      return;
    }

    String response = "You have ${_memories.length} memories. Here are the latest: ";
    for (int i = 0; i < _memories.length && i < 3; i++) {
      response += "${i + 1}. ${_memories[i].text}. ";
    }

    if (_memories.length > 3) {
      response += "And ${_memories.length - 3} more memories.";
    }

    await _speak(response);
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MemoryListScreen(memories: _memories),
        ),
      );
    }
  }

  // **IMPROVED CATEGORY MEMORIES FUNCTION**
  Future<void> _handleCategoryMemories(String command) async {
    String? category;
    
    // Extract category from "show my [category] memories"
    final regex = RegExp(r'show my (.+?) memories', caseSensitive: false);
    final match = regex.firstMatch(command);
    if (match != null) {
      final extractedCategory = match.group(1)?.trim();
      category = _categories.firstWhere(
        (c) => c.toLowerCase() == extractedCategory?.toLowerCase(),
        orElse: () => '',
      );
    }

    if (category == null || category.isEmpty) {
      await _speak("Please specify a valid category: ${_categories.join(', ')}");
      return;
    }

    final categoryMemories = _memories.where((m) => 
        m.category.toLowerCase() == category!.toLowerCase()).toList();
    
    if (categoryMemories.isEmpty) {
      await _speak("No memories found in $category category.");
      return;
    }

    String response = "Here are your $category memories: ";
    for (int i = 0; i < categoryMemories.length && i < 3; i++) {
      response += "${i + 1}. ${categoryMemories[i].text}. ";
    }
    
    if (categoryMemories.length > 3) {
      response += "And ${categoryMemories.length - 3} more memories.";
    }

    await _speak(response);
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MemoryListScreen(
            memories: categoryMemories,
            title: '$category Memories',
          ),
        ),
      );
    }
  }

  Future<void> _deleteLastMemory() async {
    try {
      if (_memories.isEmpty) {
        await _speak("No memories to delete.");
        return;
      }

      final deletedMemory = _memories.removeAt(0);
      await _saveMemoriesToFile();
      await _speak("Deleted memory: ${deletedMemory.text}");
      
      HapticFeedback.lightImpact();
      _showSnackBar('Last memory deleted', isError: false);
    } catch (e) {
      print('Delete memory error: $e');
    }
  }

  Future<void> _deleteAllMemories() async {
    try {
      final confirmed = await _showConfirmationDialog(
        'Delete All Memories',
        'Are you sure you want to delete all memories? This action cannot be undone.',
      );
      
      if (!confirmed) return;

      setState(() {
        _memories.clear();
      });
      
      await _saveMemoriesToFile();
      await _speak("All memories have been deleted.");
      _showSnackBar('All memories deleted', isError: false);
    } catch (e) {
      print('Delete all memories error: $e');
    }
  }

  Future<void> _showTodaysMemories() async {
    try {
      final today = DateTime.now();
      final todaysMemories = _memories.where((memory) {
        return memory.timestamp.year == today.year &&
               memory.timestamp.month == today.month &&
               memory.timestamp.day == today.day;
      }).toList();

      if (todaysMemories.isEmpty) {
        await _speak("You haven't saved any memories today yet.");
        return;
      }

      String response = "Today you saved ${todaysMemories.length} memories: ";
      for (int i = 0; i < todaysMemories.length && i < 3; i++) {
        response += "${i + 1}. ${todaysMemories[i].text}. ";
      }

      await _speak(response);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MemoryListScreen(
              memories: todaysMemories,
              title: "Today's Memories",
            ),
          ),
        );
      }
    } catch (e) {
      print('Show today memories error: $e');
    }
  }

  Future<void> _setCategory(String command) async {
    try {
      final lowerCommand = command.toLowerCase();
      String? newCategory;
      
      for (String category in _categories) {
        if (lowerCommand.contains(category.toLowerCase())) {
          newCategory = category;
          break;
        }
      }
      
      if (newCategory != null) {
        setState(() {
          _currentCategory = newCategory!;
        });
        await _speak("Category set to $newCategory");
      } else {
        await _speak("Please specify a valid category: ${_categories.join(', ')}");
      }
    } catch (e) {
      print('Set category error: $e');
    }
  }

  Future<void> _repeatLast() async {
    if (_lastMemoryText.isNotEmpty) {
      await _speak(_lastMemoryText);
      setState(() {
        _text = _lastMemoryText;
      });
    } else {
      await _speak("There's nothing to repeat.");
    }
  }

  Future<void> _provideHelp() async {
    final helpText = """
  Here's what I can help you with:

  To save memories, just speak naturally or say:
  - "Save this as work" followed by your memory
  - "Remember this as personal"

  To retrieve memories:
  - "Show memories" for all memories
  - "Show my work memories" for specific category
  - "What did I do today?" for today's memories

  Analytics & Export:
  - "Show analytics" to see memory insights
  - "Export to PDF" to generate a PDF report
  - "Export work PDF" for category-specific export

  Other commands:
  - "Delete last" to remove the latest memory
  - "Set category to work" to change default category
  - "Repeat that" to hear the last memory again
  - "Help" for this guide

  Available categories: ${_categories.join(', ')}
    """;
    
    await _speak("I can help you save and retrieve memories, show analytics, and export to PDF using voice commands. Check the help screen for detailed instructions.");
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Voice Commands Help'),
          content: SingleChildScrollView(
            child: Text(helpText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    }
  }


  Future<bool> _showConfirmationDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError 
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  Future<void> _showAnalytics() async {
    final insights = SummaryService.generateInsights(_memories);
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AnalyticsScreen(insights: insights),
        ),
      );
    }
  }

  Future<void> _exportToPdf({String? category}) async {
    try {
      setState(() {
        _isProcessing = true;
        _status = 'Generating PDF...';
      });

      final filePath = await PdfService.generateMemoriesPdf(
        memories: _memories,
        categoryFilter: category,
        title: category != null ? '$category Memories' : 'All Memories',
      );

      await _speak("PDF exported successfully. Would you like to share it?");
      
      if (mounted) {
        final shouldShare = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('PDF Generated'),
            content: Text('Your memories have been exported to PDF.\nLocation: ${filePath.split('/').last}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Share'),
              ),
            ],
          ),
        );

        if (shouldShare == true) {
          await PdfService.shareMemoriesPdf(filePath);
        }
      }

      _showSnackBar('PDF exported successfully', isError: false);
    } catch (e) {
      await _speak("Error exporting PDF");
      _showSnackBar('Error exporting PDF: $e', isError: true);
      print('Export PDF error: $e');
    } finally {
      setState(() {
        _isProcessing = false;
        _status = 'Ready to listen';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Show loading screen while initializing
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.deepPurple.shade100,
                Colors.blue.shade50,
                Colors.purple.shade50,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const CircularProgressIndicator(
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Initializing Memory Assistant...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.deepPurple.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade50,
              Colors.blue.shade50,
              Colors.purple.shade50,
              Colors.indigo.shade50,
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Enhanced App Bar
              SliverAppBar(
                expandedHeight: 120,
                floating: true,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExportScreen(memories: _memories),
                        ),
                      );
                    },
                    tooltip: 'Export Memories',
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.deepPurple.withOpacity(0.8),
                          Colors.blue.withOpacity(0.6),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.psychology,
                                color: Colors.white,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Memory Assistant',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your AI-Powered Memory Companion',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Main Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Category Filter Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Filter Memories',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _currentCategory,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(),
                                ),
                                items: _categories.map((category) {
                                  return DropdownMenuItem(
                                    value: category,
                                    child: Text(category),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _currentCategory = value;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Enhanced Status Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 0,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _isListening 
                                        ? Colors.green.shade100 
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _isListening ? Icons.mic : Icons.mic_none,
                                    color: _isListening 
                                        ? Colors.green.shade700 
                                        : Colors.grey.shade600,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _status,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          color: _isListening 
                                              ? Colors.green.shade700 
                                              : Colors.grey.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Category: $_currentCategory',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (_text.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade50,
                                      Colors.purple.shade50,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _text,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.blue.shade800,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Enhanced Microphone Area
                      Center(
                        child: Column(
                          children: [
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Container(
                                  width: 160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: _isListening
                                        ? LinearGradient(
                                            colors: [
                                              Colors.red.shade400,
                                              Colors.pink.shade400,
                                            ],
                                          )
                                        : LinearGradient(
                                            colors: [
                                              Colors.deepPurple.shade400,
                                              Colors.blue.shade400,
                                            ],
                                          ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_isListening 
                                            ? Colors.red 
                                            : Colors.deepPurple).withOpacity(0.3),
                                        blurRadius: _isListening ? 30 : 20,
                                        spreadRadius: _isListening ? 10 : 5,
                                      ),
                                    ],
                                  ),
                                  child: Transform.scale(
                                    scale: _isListening ? _pulseAnimation.value : 1.0,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(80),
                                        onTap: _listen,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.3),
                                              width: 3,
                                            ),
                                          ),
                                          child: Center(
                                            child: Icon(
                                              _isListening ? Icons.mic : Icons.mic_none,
                                              size: 60,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _isListening ? 'Listening...' : 'Tap to Speak',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.deepPurple.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isListening 
                                  ? 'Say your command or memory'
                                  : 'I\'ll help you remember anything',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Enhanced Voice Commands Guide
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              spreadRadius: 0,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.lightbulb,
                                    color: Colors.amber.shade700,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Quick Commands',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildEnhancedCommandChip(context, 'Show memories', Icons.list),
                                _buildEnhancedCommandChip(context, 'Show analytics', Icons.analytics),
                                _buildEnhancedCommandChip(context, 'Export PDF', Icons.picture_as_pdf),
                                _buildEnhancedCommandChip(context, 'Save as work', Icons.work),
                                _buildEnhancedCommandChip(context, 'What did I do today?', Icons.today),
                                _buildEnhancedCommandChip(context, 'Help', Icons.help),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Enhanced Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              context,
                              'Memories (${_memories.length})',
                              Icons.memory,
                              Colors.deepPurple,
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MemoryListScreen(memories: _memories),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              context,
                              'Analytics',
                              Icons.analytics,
                              Colors.blue,
                              _showAnalytics,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              context,
                              'Export',
                              Icons.picture_as_pdf,
                              Colors.green,
                              () => _exportToPdf(),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedCommandChip(BuildContext context, String label, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: () {
        _processCommand(label);
      },
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.grey.shade300),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

class MemoryListScreen extends StatefulWidget {
  final List<Memory> memories;
  final String title;

  const MemoryListScreen({
    super.key,
    required this.memories,
    this.title = 'My Memories',
  });

  @override
  State<MemoryListScreen> createState() => _MemoryListScreenState();
}

class _MemoryListScreenState extends State<MemoryListScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  
  List<String> get _categories {
    final categories = widget.memories.map((m) => m.category).toSet().toList();
    categories.insert(0, 'All');
    return categories;
  }

  List<Memory> get _filteredMemories {
    var filtered = widget.memories;
    
    if (_selectedCategory != 'All') {
      filtered = filtered.where((m) => m.category == _selectedCategory).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((m) => m.matches(_searchQuery)).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade50,
              Colors.blue.shade50,
              Colors.purple.shade50,
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            // Enhanced App Bar
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.deepPurple.shade600,
                        Colors.blue.shade500,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Icon(
                          Icons.auto_stories,
                          size: 60,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${_filteredMemories.length} memories found',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Search and Filter Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: (value) => setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: 'Search memories...',
                          prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Category Filter
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          final isSelected = category == _selectedCategory;
                          
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(category),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() => _selectedCategory = category);
                              },
                              backgroundColor: Colors.white,
                              selectedColor: Colors.deepPurple.shade100,
                              checkmarkColor: Colors.deepPurple.shade700,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Memories List
            _filteredMemories.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No memories found',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your search or filters',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final memory = _filteredMemories[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: _buildEnhancedMemoryCard(memory, theme),
                        );
                      },
                      childCount: _filteredMemories.length,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedMemoryCard(Memory memory, ThemeData theme) {
    final priorityColor = _getPriorityColor(memory.priority);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Handle memory tap
            HapticFeedback.lightImpact();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.deepPurple.shade100,
                            Colors.blue.shade100,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        memory.category,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.deepPurple.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: priorityColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      memory.formattedTimestamp,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Memory Text
                Text(
                  memory.text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                ),
                
                if (memory.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: memory.tags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#$tag',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.grey;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.green;
      case 4:
        return Colors.orange;
      case 5:
        return Colors.red;
      default:
        return Colors.green;
    }
  }
}


class AnalyticsScreen extends StatelessWidget {
  final Map<String, dynamic> insights;

  const AnalyticsScreen({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Analytics'),
        backgroundColor: colorScheme.surfaceContainer,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.surfaceContainerLowest,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total Memories Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.memory, color: colorScheme.primary, size: 32),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${insights['totalMemories']}',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Total Memories',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Category Breakdown
              if ((insights['categoryBreakdown'] as Map).isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category Breakdown',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...(insights['categoryBreakdown'] as Map<String, int>)
                            .entries
                            .map((entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(entry.key),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${entry.value}',
                                          style: TextStyle(
                                            color: colorScheme.onPrimaryContainer,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Top Keywords
              if ((insights['topKeywords'] as List).isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Top Keywords',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (insights['topKeywords'] as List<String>)
                              .map((keyword) => Chip(
                                    label: Text(keyword),
                                    backgroundColor: colorScheme.secondaryContainer,
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Insights
              if ((insights['insights'] as List).isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Insights',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...(insights['insights'] as List<String>)
                            .map((insight) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.lightbulb_outline,
                                        size: 16,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(insight),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

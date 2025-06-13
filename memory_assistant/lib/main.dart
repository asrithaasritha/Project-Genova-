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
  Widget _buildCommandChip(BuildContext context, String text) {
    final theme = Theme.of(context);
    return IntrinsicWidth(
      child: ActionChip(
        label: Text(
          text,
          style: const TextStyle(fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: theme.colorScheme.surfaceContainer,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        onPressed: () {
          _speak("Try saying: $text");
        },
      ),
    );
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
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.surface,
                colorScheme.surfaceContainerLowest,
              ],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Initializing Memory Assistant...'),
              ],
            ),
          ),
        ),
      );
    }

    // Show error message if there's an error
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Memory Assistant'),
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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Initialization Error',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _errorMessage = '';
                        _isLoading = true;
                      });
                      _initializeApp();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Assistant'),
        backgroundColor: colorScheme.surfaceContainer,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _provideHelp,
            tooltip: 'Help',
          ),
        ],
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
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  // Status and Category Display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: _isListening ? colorScheme.primary : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _status,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _isListening ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                  fontWeight: _isListening ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_text.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _text,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.category,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Current Category: $_currentCategory',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  // Main Microphone Area
                  Center(
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _isListening ? _pulseAnimation.value : 1.0,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isListening 
                                      ? colorScheme.primary 
                                      : colorScheme.primaryContainer,
                                  boxShadow: _isListening
                                      ? [
                                          BoxShadow(
                                            color: colorScheme.primary.withOpacity(0.3),
                                            blurRadius: 20,
                                            spreadRadius: 5,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(60),
                                    onTap: _listen,
                                    child: Center(
                                      child: Icon(
                                        _isListening ? Icons.mic : Icons.mic_none,
                                        size: 48,
                                        color: _isListening 
                                            ? colorScheme.onPrimary 
                                            : colorScheme.onPrimaryContainer,
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
                          _isListening ? 'Listening...' : 'Tap to speak',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isListening 
                              ? 'Say your command or memory'
                              : 'I\'ll help you remember anything',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  // Voice Command Guide
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                size: 20,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Voice Commands',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildCommandChip(context, 'Show memories'),
                              _buildCommandChip(context, 'Show my work memories'),
                              _buildCommandChip(context, 'Save this as work'),
                              _buildCommandChip(context, 'What did I do today?'),
                              _buildCommandChip(context, 'Delete last'),
                              _buildCommandChip(context, 'Help'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  // Bottom Action Buttons
                  // Bottom Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MemoryListScreen(memories: _memories),
                            ),
                          ),
                          icon: const Icon(Icons.list),
                          label: Text('Memories (${_memories.length})'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _showAnalytics,
                          icon: const Icon(Icons.analytics),
                          label: const Text('Analytics'),
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.secondaryContainer,
                            foregroundColor: colorScheme.onSecondaryContainer,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _exportToPdf(),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Export'),
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.tertiaryContainer,
                            foregroundColor: colorScheme.onTertiaryContainer,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MemoryListScreen extends StatelessWidget {
  final List<Memory> memories;
  final String title;

  const MemoryListScreen({
    super.key,
    required this.memories,
    this.title = 'My Memories',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
        child: memories.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.memory,
                      size: 64,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No memories yet',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start saving your memories with voice commands',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: memories.length,
                itemBuilder: (context, index) {
                  final memory = memories[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
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
                                  memory.category,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatTimestamp(memory.timestamp),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            memory.text,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
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

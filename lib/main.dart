import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MultiLLMChatApp());
}

class MultiLLMChatApp extends StatelessWidget {
  const MultiLLMChatApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi-LLM Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: const ChatScreen(),
    );
  }
}

enum LLMPlatform {
  groq,
  openai,
  anthropic,
  gemini,
}

class PlatformConfig {
  final String name;
  final String apiUrl;
  final List<String> models;
  final String defaultModel;
  final IconData icon;
  final String apiKeyPattern;
  final String docUrl;

  PlatformConfig({
    required this.name,
    required this.apiUrl,
    required this.models,
    required this.defaultModel,
    required this.icon,
    required this.apiKeyPattern,
    required this.docUrl,
  });

  static Map<LLMPlatform, PlatformConfig> platforms = {
    LLMPlatform.groq: PlatformConfig(
      name: 'Groq',
      apiUrl: 'https://api.groq.com/openai/v1/chat/completions',
      models: [
        'llama-3.3-70b-versatile',
        'llama-3.1-8b-instant',
        'mixtral-8x7b-32768',
        'gemma2-9b-it',
      ],
      defaultModel: 'llama-3.3-70b-versatile',
      icon: Icons.flash_on,
      apiKeyPattern: r'^gsk_',
      docUrl: 'https://console.groq.com/keys',
    ),
    LLMPlatform.openai: PlatformConfig(
      name: 'OpenAI',
      apiUrl: 'https://api.openai.com/v1/chat/completions',
      models: [
        'gpt-4o',
        'gpt-4o-mini',
        'gpt-4-turbo',
        'gpt-3.5-turbo',
      ],
      defaultModel: 'gpt-4o-mini',
      icon: Icons.smart_toy,
      apiKeyPattern: r'^sk-',
      docUrl: 'https://platform.openai.com/api-keys',
    ),
    LLMPlatform.anthropic: PlatformConfig(
      name: 'Anthropic',
      apiUrl: 'https://api.anthropic.com/v1/messages',
      models: [
        'claude-3-5-sonnet-20241022',
        'claude-3-5-haiku-20241022',
        'claude-3-opus-20240229',
      ],
      defaultModel: 'claude-3-5-sonnet-20241022',
      icon: Icons.psychology,
      apiKeyPattern: r'^sk-ant-',
      docUrl: 'https://console.anthropic.com/settings/keys',
    ),
    LLMPlatform.gemini: PlatformConfig(
      name: 'Google Gemini',
      apiUrl: 'https://generativelanguage.googleapis.com/v1beta/models/',
      models: [
        'gemini-1.5-pro',
        'gemini-1.5-flash',
        'gemini-1.0-pro',
      ],
      defaultModel: 'gemini-1.5-flash',
      icon: Icons.stars,
      apiKeyPattern: r'^AIza',
      docUrl: 'https://makersuite.google.com/app/apikey',
    ),
  };
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? details;

  ApiException(this.message, {this.statusCode, this.details});

  @override
  String toString() {
    if (statusCode != null) {
      return 'API Error ($statusCode): $message';
    }
    return 'API Error: $message';
  }

  String get userFriendlyMessage {
    if (statusCode == 401) {
      return 'Invalid API key. Please check your settings and try again.';
    } else if (statusCode == 429) {
      return 'Rate limit exceeded. Please wait a moment and try again.';
    } else if (statusCode == 500 || (statusCode != null && statusCode! >= 500)) {
      return 'Server error. The API service is currently unavailable.';
    } else if (statusCode == 400) {
      return 'Invalid request. Please check your model selection.';
    }
    return message;
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  LLMPlatform _selectedPlatform = LLMPlatform.groq;
  late String _selectedModel;
  String _apiKey = '';
  double _temperature = 0.7;
  int _maxTokens = 1024;

  @override
  void initState() {
    super.initState();
    _selectedModel = PlatformConfig.platforms[_selectedPlatform]!.defaultModel;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_apiKey.isEmpty) {
        _showSettingsDialog();
      }
    });
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      barrierDismissible: _apiKey.isNotEmpty,
      builder: (context) => SettingsDialog(
        currentPlatform: _selectedPlatform,
        currentModel: _selectedModel,
        currentApiKey: _apiKey,
        currentTemperature: _temperature,
        currentMaxTokens: _maxTokens,
        onSave: (platform, model, apiKey, temperature, maxTokens) {
          setState(() {
            _selectedPlatform = platform;
            _selectedModel = model;
            _apiKey = apiKey;
            _temperature = temperature;
            _maxTokens = maxTokens;
          });
          _showSnackBar('Settings saved successfully', isError: false);
        },
      ),
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 2),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    if (_apiKey.isEmpty) {
      _showSnackBar('Please configure your API key in settings', isError: true);
      _showSettingsDialog();
      return;
    }

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _messages.add(ChatMessage(
        text: userMessage,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final response = await _callLLMApi(userMessage);

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: response,
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: e.userFriendlyMessage,
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ));
          _isLoading = false;
        });
        _showSnackBar(e.userFriendlyMessage, isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: 'An unexpected error occurred. Please try again.',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ));
          _isLoading = false;
        });
        _showSnackBar('Network error. Please check your connection.', isError: true);
      }
    }

    _scrollToBottom();
  }

  Future<String> _callLLMApi(String userMessage) async {
    try {
      switch (_selectedPlatform) {
        case LLMPlatform.groq:
        case LLMPlatform.openai:
          return await _callOpenAICompatibleApi(userMessage);
        case LLMPlatform.anthropic:
          return await _callAnthropicApi(userMessage);
        case LLMPlatform.gemini:
          return await _callGeminiApi(userMessage);
      }
    } on http.ClientException {
      throw ApiException('Network error. Please check your internet connection.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to communicate with the API: ${e.toString()}');
    }
  }

  Future<String> _callOpenAICompatibleApi(String userMessage) async {
    final config = PlatformConfig.platforms[_selectedPlatform]!;
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    final body = jsonEncode({
      'model': _selectedModel,
      'messages': [
        {'role': 'user', 'content': userMessage}
      ],
      'temperature': _temperature,
      'max_tokens': _maxTokens,
    });

    try {
      final response = await http
          .post(
        Uri.parse(config.apiUrl),
        headers: headers,
        body: body,
      )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['choices'] == null || data['choices'].isEmpty) {
          throw ApiException('Invalid response format from API');
        }
        return data['choices'][0]['message']['content'] ?? 'No response generated';
      } else {
        final errorData = _parseErrorResponse(response.body);
        throw ApiException(
          errorData['message'] ?? 'Request failed',
          statusCode: response.statusCode,
          details: errorData['details'],
        );
      }
    } on FormatException {
      throw ApiException('Invalid response format from API');
    }
  }

  Future<String> _callAnthropicApi(String userMessage) async {
    final headers = {
      'Content-Type': 'application/json',
      'x-api-key': _apiKey,
      'anthropic-version': '2023-06-01',
    };

    final body = jsonEncode({
      'model': _selectedModel,
      'messages': [
        {'role': 'user', 'content': userMessage}
      ],
      'max_tokens': _maxTokens,
      'temperature': _temperature,
    });

    try {
      final response = await http
          .post(
        Uri.parse(PlatformConfig.platforms[LLMPlatform.anthropic]!.apiUrl),
        headers: headers,
        body: body,
      )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['content'] == null || data['content'].isEmpty) {
          throw ApiException('Invalid response format from API');
        }
        return data['content'][0]['text'] ?? 'No response generated';
      } else {
        final errorData = _parseErrorResponse(response.body);
        throw ApiException(
          errorData['message'] ?? 'Request failed',
          statusCode: response.statusCode,
          details: errorData['details'],
        );
      }
    } on FormatException {
      throw ApiException('Invalid response format from API');
    }
  }

  Future<String> _callGeminiApi(String userMessage) async {
    final url = '${PlatformConfig.platforms[LLMPlatform.gemini]!.apiUrl}$_selectedModel:generateContent?key=$_apiKey';

    final headers = {
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': userMessage}
          ]
        }
      ],
      'generationConfig': {
        'temperature': _temperature,
        'maxOutputTokens': _maxTokens,
      },
    });

    try {
      final response = await http
          .post(
        Uri.parse(url),
        headers: headers,
        body: body,
      )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] == null || data['candidates'].isEmpty) {
          throw ApiException('Invalid response format from API');
        }
        return data['candidates'][0]['content']['parts'][0]['text'] ?? 'No response generated';
      } else {
        final errorData = _parseErrorResponse(response.body);
        throw ApiException(
          errorData['message'] ?? 'Request failed',
          statusCode: response.statusCode,
          details: errorData['details'],
        );
      }
    } on FormatException {
      throw ApiException('Invalid response format from API');
    }
  }

  Map<String, String> _parseErrorResponse(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      String message = 'Unknown error';
      String? details;

      if (data['error'] != null) {
        if (data['error'] is Map) {
          message = data['error']['message'] ?? message;
          details = data['error'].toString();
        } else if (data['error'] is String) {
          message = data['error'];
        }
      }

      return {'message': message, 'details': details ?? ''};
    } catch (e) {
      return {'message': 'Failed to parse error response', 'details': responseBody};
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear all messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _messages.clear();
              });
              Navigator.pop(context);
              _showSnackBar('Chat cleared', isError: false);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = PlatformConfig.platforms[_selectedPlatform];
    if (config == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(config.icon, size: 20),
            const SizedBox(width: 8),
            Text('${config.name} Chat'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: _showSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Chat',
            onPressed: _messages.isEmpty ? null : _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_apiKey.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(config.icon, size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${config.name} • $_selectedModel',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    config.icon,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Start a conversation with ${config.name}',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Type a message below to begin',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return ChatBubble(message: _messages[index]);
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: const [
                  SizedBox(width: 16),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Thinking...'),
                ],
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      enabled: !_isLoading,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: _isLoading ? null : _sendMessage,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class SettingsDialog extends StatefulWidget {
  final LLMPlatform currentPlatform;
  final String currentModel;
  final String currentApiKey;
  final double currentTemperature;
  final int currentMaxTokens;
  final Function(LLMPlatform, String, String, double, int) onSave;

  const SettingsDialog({
    Key? key,
    required this.currentPlatform,
    required this.currentModel,
    required this.currentApiKey,
    required this.currentTemperature,
    required this.currentMaxTokens,
    required this.onSave,
  }) : super(key: key);

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late LLMPlatform _platform;
  late String _model;
  late TextEditingController _apiKeyController;
  late double _temperature;
  late int _maxTokens;
  bool _showApiKey = false;
  String? _apiKeyError;

  @override
  void initState() {
    super.initState();
    _platform = widget.currentPlatform;
    _model = widget.currentModel;
    _apiKeyController = TextEditingController(text: widget.currentApiKey);
    _temperature = widget.currentTemperature;
    _maxTokens = widget.currentMaxTokens;
  }

  bool _validateApiKey(String apiKey) {
    if (apiKey.trim().isEmpty) {
      setState(() => _apiKeyError = 'API key is required');
      return false;
    }

    final config = PlatformConfig.platforms[_platform]!;
    final pattern = RegExp(config.apiKeyPattern);

    if (!pattern.hasMatch(apiKey)) {
      setState(() => _apiKeyError = 'Invalid API key format for ${config.name}');
      return false;
    }

    setState(() => _apiKeyError = null);
    return true;
  }

  void _handleSave() {
    final apiKey = _apiKeyController.text.trim();

    if (!_validateApiKey(apiKey)) {
      return;
    }

    widget.onSave(_platform, _model, apiKey, _temperature, _maxTokens);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final config = PlatformConfig.platforms[_platform]!;

    return AlertDialog(
      title: const Text('LLM Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Platform',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<LLMPlatform>(
              value: _platform,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: PlatformConfig.platforms.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Row(
                    children: [
                      Icon(entry.value.icon, size: 20),
                      const SizedBox(width: 8),
                      Text(entry.value.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _platform = value;
                    _model = PlatformConfig.platforms[value]!.defaultModel;
                    _apiKeyError = null;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Model',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _model,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: config.models.map((model) {
                return DropdownMenuItem(
                  value: model,
                  child: Text(model, style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _model = value);
                }
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'API Key',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Get your key from: ${config.docUrl}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Enter your API key',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                errorText: _apiKeyError,
                suffixIcon: IconButton(
                  icon: Icon(_showApiKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showApiKey = !_showApiKey),
                ),
              ),
              obscureText: !_showApiKey,
              onChanged: (value) {
                if (_apiKeyError != null) {
                  setState(() => _apiKeyError = null);
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Temperature: ${_temperature.toStringAsFixed(1)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'Controls randomness. Lower = focused, Higher = creative',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            Slider(
              value: _temperature,
              min: 0.0,
              max: 2.0,
              divisions: 20,
              label: _temperature.toStringAsFixed(1),
              onChanged: (value) => setState(() => _temperature = value),
            ),
            const SizedBox(height: 8),
            Text(
              'Max Tokens: $_maxTokens',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'Maximum length of the response',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            Slider(
              value: _maxTokens.toDouble(),
              min: 256,
              max: 4096,
              divisions: 15,
              label: _maxTokens.toString(),
              onChanged: (value) => setState(() => _maxTokens = value.toInt()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _handleSave,
          child: const Text('Save'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
        message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              backgroundColor: message.isError ? Colors.red : Colors.blue,
              child: Icon(
                message.isError ? Icons.error_outline : Icons.smart_toy,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Theme.of(context).colorScheme.primaryContainer
                    : message.isError
                    ? Colors.red.withOpacity(0.1)
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isError ? Colors.red[900] : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
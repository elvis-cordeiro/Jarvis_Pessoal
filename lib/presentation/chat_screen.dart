import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/app_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];

  @override
  Widget build(BuildContext context) {
    final personalityService = ref.watch(personalityServiceProvider);
    final saveMemoryUseCase = ref.watch(saveImportantMemoryUseCaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jarvis'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          // Área de mensagens
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';
                
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.deepPurple : Colors.grey[800],
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      msg['text']!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),

          // Campo de input
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Fale com Jarvis...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurple),
                  onPressed: () async {
                    if (_controller.text.trim().isEmpty) return;

                    final userMessage = _controller.text.trim();
                    
                    setState(() {
                      _messages.add({'sender': 'user', 'text': userMessage});
                    });

                    _controller.clear();

                    // Mostrar pensando
                    setState(() {
                      _messages.add({'sender': 'jarvis', 'text': 'Pensando...'});
                    });

                    try {
                      final geminiService = ref.read(geminiServiceProvider);
                      print('🔄 Enviando mensagem para Gemini: $userMessage');

                      final response = await geminiService.generateResponse(userMessage);

                      print('✅ Resposta recebida: $response');

                      // Remove "Pensando..." e adiciona resposta
                      setState(() {
                        _messages.removeLast();
                        _messages.add({'sender': 'jarvis', 'text': response});
                      });

                      // Verifica memória
                      final saveMemoryUseCase = ref.read(saveImportantMemoryUseCaseProvider);
                      await saveMemoryUseCase.call(
                        userMessage: userMessage,
                        jarvisResponse: response,
                      );
                    } catch (e) {
                      print('❌ Erro ao chamar Gemini: $e');
                      
                      setState(() {
                        _messages.removeLast();
                        _messages.add({
                          'sender': 'jarvis', 
                          'text': 'Mestre, ocorreu um erro ao processar sua mensagem. Pode tentar novamente?'
                        });
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
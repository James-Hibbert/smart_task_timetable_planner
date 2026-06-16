import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/module.dart';
import '../state/app_state.dart';

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({super.key});

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  String _searchQuery = '';

  Future<void> _addModule(
      BuildContext context,
      String name,
      String code,
      ) async {
    final module = Module(
      name: name,
      code: code,
    );

    await context.read<AppState>().addModule(module.toMap());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Module added successfully.')),
    );
  }

  Future<void> _updateModule(
      BuildContext context,
      int id,
      String name,
      String code,
      ) async {
    final module = Module(
      id: id,
      name: name,
      code: code,
    );

    await context.read<AppState>().updateModule(module.toMap());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Module updated successfully.')),
    );
  }

  Future<void> _deleteModule(BuildContext context, int id) async {
    await context.read<AppState>().deleteModule(id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Module deleted.')),
    );
  }

  bool _matchesSearch(Module module) {
    if (_searchQuery.trim().isEmpty) return true;

    final query = _searchQuery.trim().toLowerCase();
    return module.name.toLowerCase().contains(query) ||
        module.code.toLowerCase().contains(query);
  }

  Future<void> _confirmDeleteModule(
      BuildContext context,
      Module module,
      ) async {
    if (module.id == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Module'),
          content: Text(
            'Are you sure you want to delete "${module.name} (${module.code})"?\n\nThis may also remove related tasks and sessions.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true && context.mounted) {
      await _deleteModule(context, module.id!);
    }
  }

  void _showModuleDialog(
      BuildContext context, {
        Module? existingModule,
      }) {
    final isEditing = existingModule != null;
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(
      text: existingModule?.name ?? '',
    );
    final codeController = TextEditingController(
      text: existingModule?.code ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Module' : 'Add Module'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Module Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a module name.';
                    }
                    if (value.trim().length < 2) {
                      return 'Module name must be at least 2 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Module Code',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a module code.';
                    }
                    if (value.trim().length < 2) {
                      return 'Module code must be at least 2 characters.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final name = nameController.text.trim();
                final code = codeController.text.trim().toUpperCase();

                if (isEditing) {
                  if (existingModule.id == null) return;

                  await _updateModule(
                    context,
                    existingModule.id!,
                    name,
                    code,
                  );
                } else {
                  await _addModule(
                    context,
                    name,
                    code,
                  );
                }

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: Text(isEditing ? 'Save' : 'Add'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (appState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final modules = appState.modules.map((map) => Module.fromMap(map)).toList();
    final visibleModules = modules.where(_matchesSearch).toList();

    return Stack(
      children: [
        modules.isEmpty
            ? const Center(
          child: Text(
            'No modules yet.\nTap + to add your first module.',
            textAlign: TextAlign.center,
          ),
        )
            : Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildSummaryCard(
                        label: 'Total Modules',
                        value: '${modules.length}',
                        icon: Icons.book,
                      ),
                      const SizedBox(width: 8),
                      _buildSummaryCard(
                        label: 'Visible',
                        value: '${visibleModules.length}',
                        icon: Icons.visibility,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search modules by name or code...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        icon: const Icon(Icons.clear),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: visibleModules.isEmpty
                  ? const Center(
                child: Text(
                  'No matching modules found.',
                  textAlign: TextAlign.center,
                ),
              )
                  : ListView.builder(
                itemCount: visibleModules.length,
                itemBuilder: (context, index) {
                  final module = visibleModules[index];

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.book_outlined),
                      ),
                      title: Text(
                        module.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(module.code),
                      ),
                      trailing: module.id != null
                          ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit module',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _showModuleDialog(
                              context,
                              existingModule: module,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete module',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _confirmDeleteModule(
                              context,
                              module,
                            ),
                          ),
                        ],
                      )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => _showModuleDialog(context),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}
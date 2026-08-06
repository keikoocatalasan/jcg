import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/core/network/supabase_client_provider.dart';
import 'package:jcg_fitness/core/utils/formatters.dart';

class PriceHistoryEntry {
  final DateTime date;
  final double price;
  final String source;

  const PriceHistoryEntry({
    required this.date,
    required this.price,
    required this.source,
  });
}

class PriceHistoryScreen extends ConsumerStatefulWidget {
  final String foodId;
  final String foodName;
  final double currentPrice;

  const PriceHistoryScreen({
    super.key,
    required this.foodId,
    required this.foodName,
    required this.currentPrice,
  });

  @override
  ConsumerState<PriceHistoryScreen> createState() => _PriceHistoryScreenState();
}

class _PriceHistoryScreenState extends ConsumerState<PriceHistoryScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  List<PriceHistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      final rows = await supabase
          .from('food_price')
          .select('estimated_price_php, effective_from, source_id')
          .eq('food_id', widget.foodId)
          .order('effective_from', ascending: false);
      final sources =
          await supabase.from('data_source').select('source_id, source_name');
      final sourceNames = {
        for (final row in sources)
          row['source_id']: row['source_name'] as String,
      };
      _history = rows
          .map((row) => PriceHistoryEntry(
                date: DateTime.parse(row['effective_from'] as String),
                price: (row['estimated_price_php'] as num).toDouble(),
                source: sourceNames[row['source_id']] ?? 'Unknown',
              ))
          .toList();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _showAddPriceDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Price'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.foodName,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'New Price (₱)',
                  prefixIcon: Icon(Icons.monetization_on),
                ),
                autofocus: true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Price is required';
                  final parsed = double.tryParse(v);
                  if (parsed == null) return 'Enter a valid number';
                  if (parsed <= 0) return 'Price must be greater than 0';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(double.parse(controller.text.trim()));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        final supabase = ref.read(supabaseClientProvider);
        final source = await supabase
            .from('data_source')
            .select('source_id')
            .eq('source_name', 'Estimated_Common')
            .maybeSingle();
        final sourceId = source?['source_id'];
        if (sourceId == null) {
          throw Exception('Estimated price source is not configured');
        }
        await supabase.rpc('admin_set_food_price', params: {
          'p_food_id': widget.foodId,
          'p_price_php': result,
          'p_source_id': sourceId,
        });
        await _loadHistory();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('New price ${Formatters.formatPhp(result)} added')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add price: $e')),
          );
        }
      }
    }
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.foodName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Per 100 grams',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Current Price: ${Formatters.formatPhp(widget.currentPrice)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Date',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Price (₱)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Source',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(_history.length, (index) {
            final entry = _history[index];
            final isEven = index.isEven;
            final isFirst = index == 0;

            return Container(
              decoration: BoxDecoration(
                color: isEven ? AppColors.surface : AppColors.surfaceAlt,
                borderRadius: index == _history.length - 1
                    ? const BorderRadius.vertical(bottom: Radius.circular(8))
                    : null,
                border: index < _history.length - 1
                    ? const Border(
                        bottom: BorderSide(
                          color: AppColors.divider,
                        ),
                      )
                    : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      _formatDate(entry.date),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight:
                            isFirst ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      Formatters.formatPhp(entry.price),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isFirst ? FontWeight.w600 : FontWeight.normal,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      entry.source,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Price History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Price history for this food item\nwill appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Failed to load price history.\nPlease try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.textPrimary),
            SizedBox(height: 16),
            Text(
              'Loading price history...',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Price History'),
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _hasError
                    ? _buildErrorState()
                    : _history.isEmpty
                        ? _buildEmptyState()
                        : SingleChildScrollView(
                            padding: const EdgeInsets.only(top: 16),
                            child: _buildTable(),
                          ),
          ),
          if (!_isLoading && !_hasError)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _showAddPriceDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Price'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

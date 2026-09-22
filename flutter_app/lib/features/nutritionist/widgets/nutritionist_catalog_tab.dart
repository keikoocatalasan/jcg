import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jcg_fitness/app/theme.dart';
import 'package:jcg_fitness/features/nutritionist/nutritionist_provider.dart';

class NutritionistCatalogTab extends ConsumerStatefulWidget {
  const NutritionistCatalogTab({super.key});

  @override
  ConsumerState<NutritionistCatalogTab> createState() =>
      _NutritionistCatalogTabState();
}

class _NutritionistCatalogTabState
    extends ConsumerState<NutritionistCatalogTab> {
  static const _pageSize = 20;
  static const _filters = <String, String>{
    'all': 'All',
    'unreviewed': 'Unreviewed',
    'in_review': 'In review',
    'verified': 'Verified',
    'needs_revision': 'Needs revision',
    'rejected': 'Rejected',
  };

  final _searchController = TextEditingController();
  Timer? _debounce;
  String _status = 'all';
  String _search = '';
  int _page = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  List<NutritionistCatalogEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 0;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final items =
          await ref.read(nutritionistServiceProvider).fetchCatalog(
                search: _search,
                status: _status,
                page: reset ? 0 : _page + 1,
                pageSize: _pageSize,
              );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _entries = items;
          _page = 0;
        } else {
          _entries = [..._entries, ...items];
          _page += 1;
        }
        _hasMore = items.length == _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _search = value.trim());
      _load(reset: true);
    });
  }

  void _onStatusChanged(String status) {
    setState(() => _status = status);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Search food by name',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: _filters.entries
                .map(
                  (filter) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(filter.value),
                      selected: _status == filter.key,
                      onSelected: (_) => _onStatusChanged(filter.key),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40),
              const SizedBox(height: 12),
              Text(
                'Food catalog could not be loaded.\n$_error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _load(reset: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (_entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No foods match this search or filter.'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: _entries.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _entries.length) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton(
                onPressed: _loadingMore ? null : () => _load(reset: false),
                child: Text(_loadingMore ? 'Loading…' : 'Load more'),
              ),
            );
          }
          return _CatalogCard(entry: _entries[index]);
        },
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  final NutritionistCatalogEntry entry;

  const _CatalogCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (entry.verificationStatus) {
      'verified' => AppColors.success,
      'needs_revision' => AppColors.warning,
      'rejected' => AppColors.error,
      'in_review' => AppColors.primary,
      _ => AppColors.textSecondary,
    };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/nutritionist/review', extra: entry),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      entry.foodName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${entry.categoryName} · per 100 g: '
                '${entry.caloriesPer100g.toStringAsFixed(0)} kcal · '
                'P ${entry.proteinPer100g.toStringAsFixed(1)} g · '
                'C ${entry.carbsPer100g.toStringAsFixed(1)} g · '
                'F ${entry.fatPer100g.toStringAsFixed(1)} g',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  entry.verificationLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum SortOption {
  newestFirst('Newest First'),
  highestSalary('Highest Salary'),
  mostApplications('Most Applications');

  final String label;
  const SortOption(this.label);
}

Future<List<String>?> showFilterSheet(
  BuildContext context, {
  required List<String> currentFilters,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FilterSheet(currentFilters: currentFilters),
  );
}

Future<SortOption?> showSortSheet(
  BuildContext context, {
  required SortOption current,
}) {
  return showModalBottomSheet<SortOption>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => SortSheet(current: current),
  );
}

class _FilterOption {
  final String label;
  final int count;
  const _FilterOption(this.label, this.count);
}

class FilterSheet extends StatefulWidget {
  final List<String> currentFilters;

  const FilterSheet({super.key, required this.currentFilters});

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late Set<String> _selected;
  late String _activeCategory;

  static const Map<String, List<_FilterOption>> _options = {
    'Work mode': [
      _FilterOption('Work from office', 11013),
      _FilterOption('Remote', 359),
      _FilterOption('Hybrid', 82),
    ],
    'Department': [
      _FilterOption('Engineering', 5234),
      _FilterOption('Product', 1432),
      _FilterOption('Design', 1890),
      _FilterOption('Marketing', 1245),
      _FilterOption('Sales', 987),
      _FilterOption('Operations', 654),
      _FilterOption('Human Resources', 321),
      _FilterOption('Finance', 432),
    ],
    'Location': [
      _FilterOption('Bangalore', 4567),
      _FilterOption('Mumbai', 3210),
      _FilterOption('Hyderabad', 2890),
      _FilterOption('Pune', 2456),
      _FilterOption('Delhi NCR', 2100),
      _FilterOption('Chennai', 1876),
      _FilterOption('Kolkata', 654),
    ],
    'Experience': [
      _FilterOption('Fresher', 1234),
      _FilterOption('1 Year', 2345),
      _FilterOption('2 Years', 3456),
      _FilterOption('3 Years', 2987),
      _FilterOption('5+ Years', 1876),
      _FilterOption('10+ Years', 543),
    ],
    'Salary': [
      _FilterOption('0-3 LPA', 1234),
      _FilterOption('3-6 LPA', 2890),
      _FilterOption('6-10 LPA', 3456),
      _FilterOption('10-15 LPA', 2345),
      _FilterOption('15-25 LPA', 1234),
      _FilterOption('25+ LPA', 567),
    ],
    'Top Companies': [
      _FilterOption('Google', 234),
      _FilterOption('Microsoft', 198),
      _FilterOption('Amazon', 287),
      _FilterOption('Meta', 145),
      _FilterOption('Apple', 123),
      _FilterOption('Netflix', 76),
      _FilterOption('Flipkart', 156),
    ],
    'Industry': [
      _FilterOption('IT Services', 5432),
      _FilterOption('Banking', 2345),
      _FilterOption('E-commerce', 1876),
      _FilterOption('Healthcare', 1234),
      _FilterOption('EdTech', 987),
      _FilterOption('Retail', 765),
    ],
    'Role': [
      _FilterOption('Software Engineer', 4567),
      _FilterOption('Data Scientist', 1234),
      _FilterOption('Product Manager', 987),
      _FilterOption('UX Designer', 765),
      _FilterOption('DevOps Engineer', 654),
      _FilterOption('QA Engineer', 543),
    ],
    'Stipend': [
      _FilterOption('0-10K', 234),
      _FilterOption('10-20K', 456),
      _FilterOption('20-30K', 234),
      _FilterOption('30K+', 123),
    ],
    'Duration': [
      _FilterOption('1-3 months', 345),
      _FilterOption('3-6 months', 567),
      _FilterOption('6+ months', 234),
    ],
    'Education': [
      _FilterOption('B.Tech / B.E.', 5678),
      _FilterOption('M.Tech / M.E.', 1234),
      _FilterOption('B.Sc.', 987),
      _FilterOption('M.Sc.', 765),
      _FilterOption('MBA', 1234),
      _FilterOption('PhD', 234),
    ],
  };

  @override
  void initState() {
    super.initState();
    _selected = widget.currentFilters.toSet();
    _activeCategory = _options.keys.first;
  }

  int _selectedCountFor(String category) {
    return _options[category]!
        .where((o) => _selected.contains(o.label))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final activeOptions = _options[_activeCategory] ?? const [];

    return Container(
      height: size.height * 0.9,
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.divider,
              borderRadius: BorderRadius.circular(50),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text('Filter jobs', style: AppTextStyles.h3),
                ),
                TextButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => setState(() => _selected.clear()),
                  child: Text(
                    'Clear all',
                    style: AppTextStyles.label.copyWith(
                      color: _selected.isEmpty
                          ? context.textTertiary
                          : AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 16, 12),
              child: SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selected.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final label = _selected.elementAt(i);
                    return _SelectedChip(
                      label: label,
                      onRemove: () =>
                          setState(() => _selected.remove(label)),
                    );
                  },
                ),
              ),
            ),
          Divider(height: 1, color: context.divider),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 132,
                  child: ColoredBox(
                    color: context.scaffoldBg,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _options.length,
                      itemBuilder: (_, i) {
                        final key = _options.keys.elementAt(i);
                        final isActive = key == _activeCategory;
                        final count = _selectedCountFor(key);
                        final label = count > 0 ? '$key ($count)' : key;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _activeCategory = key),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            color: isActive ? Colors.white : null,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 22,
                                  color: isActive
                                      ? AppColors.primary
                                      : Colors.transparent,
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Text(
                                    label,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: isActive
                                          ? context.textPrimary
                                          : context.textSecondary,
                                      fontWeight: isActive
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: activeOptions.length,
                    itemBuilder: (_, i) {
                      final opt = activeOptions[i];
                      final isSelected = _selected.contains(opt.label);
                      return InkWell(
                        onTap: () => setState(() {
                          if (isSelected) {
                            _selected.remove(opt.label);
                          } else {
                            _selected.add(opt.label);
                          }
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 12),
                          child: Row(
                            children: [
                              _CheckBox(checked: isSelected),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  opt.label,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: context.textSecondary,
                                  ),
                                ),
                              ),
                              Text(
                                '${opt.count}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: context.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: context.surface,
              border: Border(top: BorderSide(color: context.divider)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          foregroundColor: AppColors.primary,
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.button.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, _selected.toList()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                        child: Text(
                          'Apply',
                          style: AppTextStyles.button.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _SelectedChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      decoration: BoxDecoration(
        color: context.scaffoldBg,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: context.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: context.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  final bool checked;
  const _CheckBox({required this.checked});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: checked ? AppColors.primary : context.textTertiary,
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}

class SortSheet extends StatelessWidget {
  final SortOption current;
  const SortSheet({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.divider,
              borderRadius: BorderRadius.circular(50),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Sort by', style: AppTextStyles.h3),
            ),
          ),
          for (final opt in SortOption.values)
            ListTile(
              title: Text(opt.label, style: AppTextStyles.bodyMedium),
              onTap: () => Navigator.pop(context, opt),
              trailing: opt == current
                  ? const Icon(Icons.check_rounded, color: AppColors.primary)
                  : null,
            ),
          const SafeArea(top: false, child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}
